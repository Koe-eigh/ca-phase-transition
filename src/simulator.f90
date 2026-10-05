module simulator_module
    use, intrinsic :: iso_fortran_env, only: int32
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
        real, allocatable :: p_values(:)
        real, allocatable :: q_values(:)
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
        integer(kind=int32), allocatable :: active_count(:, :, :)
    end type SimulationResult_t

    interface Simulator
        module procedure init
    end interface Simulator

contains
    function init_context(p_steps, q_steps, max_steps, grid_size) result(context)
        integer(kind=int32), intent(in) :: p_steps, q_steps, max_steps, grid_size
        type(SimulationContext_t) :: context
        integer(kind=int32) :: i

        context%p_steps = p_steps
        context%q_steps = q_steps
        context%max_steps = max_steps
        context%grid_size = grid_size

        if (p_steps <= 0 .or. q_steps <= 0 .or. max_steps < 0 .or. grid_size <= 0) then
            error stop 'Invalid simulation context'
        end if

        allocate(context%p_values(p_steps), context%q_values(q_steps))
        if (p_steps == 1) then
            context%p_values = 0.0
        else
            context%p_values = [(real(i - 1) / real(p_steps - 1), i = 1, p_steps)]
        end if
        if (q_steps == 1) then
            context%q_values = 0.0
        else
            context%q_values = [(real(i - 1) / real(q_steps - 1), i = 1, q_steps)]
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
        sim%model = DKCA(initial_state)
    end function init

    function simulate(sim) result(simulation_result)
        class(Simulator_t), intent(inout) :: sim
        type(SimulationResult_t) :: simulation_result
        type(DKCA_t) :: local_model
        integer(kind=int32) :: it, ip, iq
        integer :: total_patterns, worker_count

        allocate(simulation_result%active_count(0:sim%context%max_steps, &
                                                sim%context%p_steps, &
                                                sim%context%q_steps))

        ! Every (p, q) run is independent.  Use one worker per pattern when
        ! possible, while respecting the configured OpenMP thread limit.
        total_patterns = int(sim%context%p_steps) * int(sim%context%q_steps)
        worker_count = min(total_patterns, omp_get_max_threads())

        ! Keep a private model per thread so that the state update and
        ! random-number generation do not race.  Each iteration writes to a
        ! distinct (time, p, q) region of the shared result array.
        !$omp parallel do collapse(2) schedule(static) &
        !$omp& num_threads(worker_count) &
        !$omp& private(local_model, it, ip, iq) shared(sim, simulation_result)
        do iq = 1, sim%context%q_steps
            do ip = 1, sim%context%p_steps
                local_model = sim%model
                call local_model%reset()
                simulation_result%active_count(0, ip, iq) = &
                    local_model%current_active_count()
                do it = 1, sim%context%max_steps
                    call local_model%step(sim%context%p_values(ip), sim%context%q_values(iq))
                    simulation_result%active_count(it, ip, iq) = &
                        local_model%current_active_count()
                end do
            end do
        end do
        !$omp end parallel do
    end function simulate
end module simulator_module
