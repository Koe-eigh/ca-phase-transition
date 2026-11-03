module simulator_module
    use, intrinsic :: iso_fortran_env, only: int32, int64, real64, output_unit
    use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
    use omp_lib, only: omp_get_max_threads
    use model, only: DKCA_t, DKCA
    implicit none
    private

    public :: SimulationContext_t, SimulationContext
    public :: Simulator_t, Simulator
    public :: SimulationResult_t

    ! Conditions and dimensions shared by one simulation experiment.
    type :: SimulationContext_t
        integer(kind=int32) :: p_steps
        integer(kind=int32) :: q_steps
        integer(kind=int32) :: max_steps
        integer(kind=int32) :: grid_size
        integer(kind=int32) :: simulation_count
        integer(kind=int64) :: seed
        logical :: cut_p_below_half
        real(real64), allocatable :: p_values(:)
        real(real64), allocatable :: q_values(:)
    end type SimulationContext_t

    interface SimulationContext
        module procedure init_context
    end interface SimulationContext

    type :: Simulator_t
        type(SimulationContext_t) :: context
        type(DKCA_t) :: model
    contains
        procedure :: simulate
    end type Simulator_t

    ! Direct observations produced by the simulation.
    ! The first dimension is the time step. p and q are represented by
    ! their indices in the parameter sweep.
    type :: SimulationResult_t
        integer(kind=int64) :: seed
        real(real64), allocatable :: active_count(:, :, :)
        integer(kind=int32), allocatable :: survivor_count(:, :, :)
        real(real64), allocatable :: mean_mu(:, :, :)
        real(real64), allocatable :: mean_mu2(:, :, :)
        real(real64), allocatable :: variance_mu(:, :, :)
        real(real64), allocatable :: mean_sigma2(:, :, :)
    end type SimulationResult_t

    interface Simulator
        module procedure init
    end interface Simulator

contains
    function init_context(p_steps, q_steps, max_steps, grid_size, simulation_count, &
                          cut_p_below_half, seed) result(context)
        integer(kind=int32), intent(in) :: p_steps, q_steps, max_steps, grid_size
        integer(kind=int32), intent(in), optional :: simulation_count
        logical, intent(in), optional :: cut_p_below_half
        integer(kind=int64), intent(in), optional :: seed
        type(SimulationContext_t) :: context
        integer(kind=int32) :: i

        context%p_steps = p_steps
        context%q_steps = q_steps
        context%max_steps = max_steps
        context%grid_size = grid_size
        context%simulation_count = 1_int32
        if (present(simulation_count)) context%simulation_count = simulation_count
        context%cut_p_below_half = .false.
        if (present(cut_p_below_half)) context%cut_p_below_half = cut_p_below_half
        call system_clock(count=context%seed)
        if (present(seed)) context%seed = seed

        if (p_steps <= 0 .or. q_steps <= 0 .or. max_steps < 0 .or. grid_size <= 0 .or. &
            context%simulation_count <= 0) then
            error stop 'Invalid simulation context'
        end if

        allocate(context%p_values(p_steps), context%q_values(q_steps))
        if (p_steps == 1) then
            context%p_values = 0.0_real64
        else
            context%p_values = [(real(i - 1, real64) / real(p_steps - 1, real64), i = 1, p_steps)]
        end if
        if (q_steps == 1) then
            context%q_values = 0.0_real64
        else
            context%q_values = [(real(i - 1, real64) / real(q_steps - 1, real64), i = 1, q_steps)]
        end if
    end function init_context

    function init(context) result(sim)
        type(SimulationContext_t), intent(in) :: context
        type(Simulator_t) :: sim

        integer(kind=int32), allocatable :: initial_state(:)
        integer(kind=int32) :: lb, rb
        if (mod(context%grid_size, 2) .eq. 0) then
            lb = -(context%grid_size / 2)
            rb = context%grid_size / 2 - 1
        else
            lb = -(context%grid_size / 2)
            rb = context%grid_size / 2
        end if
        allocate(initial_state(lb:rb))
        initial_state = 0_int32
        initial_state(0) = 1_int32

        sim%context = context
        sim%model = DKCA(initial_state, lb)
    end function init

    function simulate(sim) result(simulation_result)
        class(Simulator_t), intent(inout) :: sim
        type(SimulationResult_t) :: simulation_result
        type(DKCA_t) :: local_model
        integer(kind=int32) :: it, ip, iq, isim, active_count
        real(real64) :: survivor_total
        integer :: worker_count, progress_percent, last_percent
        integer(kind=int64) :: total_patterns, completed_patterns

        simulation_result%seed = sim%context%seed
        allocate(simulation_result%active_count(0:sim%context%max_steps, &
                                                sim%context%p_steps, &
                                                sim%context%q_steps))
        simulation_result%active_count = 0.0_real64
        allocate(simulation_result%survivor_count(0:sim%context%max_steps, &
                                                   sim%context%p_steps, sim%context%q_steps))
        allocate(simulation_result%mean_mu(0:sim%context%max_steps, &
                                            sim%context%p_steps, sim%context%q_steps))
        allocate(simulation_result%mean_mu2(0:sim%context%max_steps, &
                                             sim%context%p_steps, sim%context%q_steps))
        allocate(simulation_result%variance_mu(0:sim%context%max_steps, &
                                                sim%context%p_steps, sim%context%q_steps))
        allocate(simulation_result%mean_sigma2(0:sim%context%max_steps, &
                                                sim%context%p_steps, sim%context%q_steps))
        simulation_result%survivor_count = 0_int32
        simulation_result%mean_mu = 0.0_real64
        simulation_result%mean_mu2 = 0.0_real64
        simulation_result%variance_mu = 0.0_real64
        simulation_result%mean_sigma2 = 0.0_real64

        ! Every (p, q) run is independent.  Use one worker per pattern when
        ! possible, while respecting the configured OpenMP thread limit.
        total_patterns = int(sim%context%p_steps, int64) * int(sim%context%q_steps, int64)
        if (sim%context%cut_p_below_half) then
            total_patterns = int(count(sim%context%p_values >= 0.5_real64), int64) * &
                             int(sim%context%q_steps, int64)
        end if
        worker_count = int(min(max(total_patterns, 1_int64), int(omp_get_max_threads(), int64)))
        completed_patterns = 0_int64
        last_percent = 0
        write(output_unit, '(a)') 'progress: 0%'
        flush(output_unit)

        ! Keep a private model per thread so that the state update and
        ! random-number generation do not race.  Each iteration writes to a
        ! distinct (time, p, q) region of the shared result array.
        !$omp parallel do collapse(2) schedule(static) &
        !$omp& num_threads(worker_count) &
        !$omp& private(local_model, it, ip, iq, isim, active_count, survivor_total, progress_percent) &
        !$omp& shared(sim, simulation_result, completed_patterns, total_patterns, last_percent)
        do iq = 1, sim%context%q_steps
            do ip = 1, sim%context%p_steps
                if (sim%context%cut_p_below_half .and. &
                    sim%context%p_values(ip) < 0.5_real64) cycle
                ! The model arrays are allocated/copied once per parameter
                ! combination and then reused for all Monte Carlo trials.
                local_model = sim%model
                do isim = 1, sim%context%simulation_count
                    call local_model%reset()
                    call local_model%seed_stream(sim%context%seed, ip, iq, isim)
                    active_count = local_model%current_active_count()
                    simulation_result%active_count(0, ip, iq) = &
                        simulation_result%active_count(0, ip, iq) + &
                        real(active_count, real64)
                    call accumulate_moments(local_model, simulation_result, 0_int32, ip, iq, active_count)
                    do it = 1, sim%context%max_steps
                        call local_model%step(sim%context%p_values(ip), sim%context%q_values(iq), &
                                              active_count)
                        simulation_result%active_count(it, ip, iq) = &
                            simulation_result%active_count(it, ip, iq) + &
                            real(active_count, real64)
                        ! The all-zero state is absorbing, so later time
                        ! steps remain zero and do not need to be simulated.
                        if (active_count == 0_int32) exit
                        call accumulate_moments(local_model, simulation_result, it, ip, iq, active_count)
                    end do
                end do
                simulation_result%active_count(:, ip, iq) = &
                    simulation_result%active_count(:, ip, iq) / &
                    real(sim%context%simulation_count, real64)
                do it = 0, sim%context%max_steps
                    if (simulation_result%survivor_count(it, ip, iq) == 0_int32 .or. &
                        it >= (sim%context%grid_size + 1_int32) / 2_int32) then
                        simulation_result%mean_mu(it, ip, iq) = ieee_value(0.0_real64, ieee_quiet_nan)
                        simulation_result%mean_mu2(it, ip, iq) = ieee_value(0.0_real64, ieee_quiet_nan)
                        simulation_result%variance_mu(it, ip, iq) = ieee_value(0.0_real64, ieee_quiet_nan)
                        simulation_result%mean_sigma2(it, ip, iq) = ieee_value(0.0_real64, ieee_quiet_nan)
                    else
                        survivor_total = real(simulation_result%survivor_count(it, ip, iq), real64)
                        simulation_result%mean_mu(it, ip, iq) = simulation_result%mean_mu(it, ip, iq) / survivor_total
                        simulation_result%mean_mu2(it, ip, iq) = simulation_result%mean_mu2(it, ip, iq) / survivor_total
                        simulation_result%mean_sigma2(it, ip, iq) = &
                            simulation_result%mean_sigma2(it, ip, iq) / survivor_total
                        simulation_result%variance_mu(it, ip, iq) = &
                            simulation_result%mean_mu2(it, ip, iq) - &
                            simulation_result%mean_mu(it, ip, iq)**2
                    end if
                end do
                !$omp critical(simulation_progress)
                completed_patterns = completed_patterns + 1_int64
                progress_percent = int(100_int64 * completed_patterns / total_patterns)
                if (progress_percent > last_percent) then
                    write(output_unit, '(a,i0,a)') 'progress: ', progress_percent, '%'
                    flush(output_unit)
                    last_percent = progress_percent
                end if
                !$omp end critical(simulation_progress)
            end do
        end do
        !$omp end parallel do
        if (total_patterns == 0_int64) then
            write(output_unit, '(a)') 'progress: 100%'
            flush(output_unit)
        end if
    end function simulate

    subroutine accumulate_moments(local_model, simulation_result, time_step, ip, iq, active_count)
        type(DKCA_t), intent(in) :: local_model
        type(SimulationResult_t), intent(inout) :: simulation_result
        integer(kind=int32), intent(in) :: time_step, ip, iq, active_count
        real(real64) :: mu, sigma2

        if (active_count == 0_int32) return
        simulation_result%survivor_count(time_step, ip, iq) = &
            simulation_result%survivor_count(time_step, ip, iq) + 1_int32
        if (.not. local_model%spatial_moments_defined()) return
        call local_model%current_spatial_moments(active_count, mu, sigma2)
        simulation_result%mean_mu(time_step, ip, iq) = simulation_result%mean_mu(time_step, ip, iq) + mu
        simulation_result%mean_mu2(time_step, ip, iq) = simulation_result%mean_mu2(time_step, ip, iq) + mu**2
        simulation_result%mean_sigma2(time_step, ip, iq) = &
            simulation_result%mean_sigma2(time_step, ip, iq) + sigma2
    end subroutine accumulate_moments
end module simulator_module
