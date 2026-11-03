program main
    use, intrinsic :: iso_fortran_env, only: int32, int64, real64
    use, intrinsic :: iso_c_binding, only: c_char, c_int, c_null_char
    use simulator_module, only: SimulationContext_t, SimulationContext, &
                                Simulator_t, Simulator, SimulationResult_t
    implicit none

    ! Increase these values for a higher-resolution/longer experiment.
    integer(kind=int32), parameter :: DEFAULT_P_STEPS = 21_int32
    integer(kind=int32), parameter :: DEFAULT_Q_STEPS = 21_int32
    integer(kind=int32), parameter :: DEFAULT_MAX_STEPS = 200_int32
    integer(kind=int32), parameter :: DEFAULT_GRID_SIZE = 200_int32
    integer(kind=int32), parameter :: DEFAULT_SIMULATION_COUNT = 1_int32

    integer(kind=int32) :: p_steps, q_steps, max_steps, grid_size, simulation_count
    integer(kind=int64) :: seed
    integer(kind=int64) :: start_tick, end_tick, tick_rate
    real(real64) :: elapsed_seconds
    logical :: cut_p_below_half
    
    type(SimulationContext_t) :: context
    type(Simulator_t) :: sim
    type(SimulationResult_t) :: sim_result

    interface
        function c_rename(old_name, new_name) bind(C, name='rename') result(status)
            import :: c_char, c_int
            character(kind=c_char), intent(in) :: old_name(*), new_name(*)
            integer(c_int) :: status
        end function c_rename
    end interface

    call remove_previous_summary()
    call parse_command_line(p_steps, q_steps, max_steps, grid_size, simulation_count, cut_p_below_half, seed)

    call system_clock(count=start_tick, count_rate=tick_rate)
    if (tick_rate <= 0_int64) error stop 'System clock is unavailable'
    context = SimulationContext(p_steps, q_steps, max_steps, grid_size, simulation_count, cut_p_below_half, seed)
    print '(a,i0)', 'seed: ', context%seed
    sim = Simulator(context)
    sim_result = sim%simulate()

    call write_phase_diagram_data(context, sim_result, 'phase_diagram.dat')
    print *, 'wrote phase_diagram.dat'
    call write_time_evolution_data(context, sim_result, 'time_evolution.dat')
    print *, 'wrote time_evolution.dat'
    call system_clock(count=end_tick)
    elapsed_seconds = real(end_tick - start_tick, real64) / real(tick_rate, real64)
    call write_summary(context, sim_result, elapsed_seconds, 'summary.txt')
    print *, 'wrote summary.txt'

contains
    subroutine remove_previous_summary()
        integer :: summary_unit, io_status
        logical :: exists

        inquire(file='summary.txt', exist=exists)
        if (.not. exists) return
        open(newunit=summary_unit, file='summary.txt', status='old', iostat=io_status)
        if (io_status /= 0) error stop 'Could not open previous summary file'
        close(summary_unit, status='delete', iostat=io_status)
        if (io_status /= 0) error stop 'Could not remove previous summary file'
    end subroutine remove_previous_summary

    subroutine write_summary(context, simulation_result, elapsed_seconds, filename)
        type(SimulationContext_t), intent(in) :: context
        type(SimulationResult_t), intent(in) :: simulation_result
        real(real64), intent(in) :: elapsed_seconds
        character(len=*), intent(in) :: filename
        integer :: summary_unit, io_status
        integer(kind=int32) :: ip, iq
        real(real64) :: final_count, minimum_count, maximum_count

        minimum_count = huge(0.0_real64)
        maximum_count = -huge(0.0_real64)
        do iq = 1, context%q_steps
            do ip = 1, context%p_steps
                if (context%cut_p_below_half .and. context%p_values(ip) < 0.5_real64) cycle
                final_count = simulation_result%active_count(context%max_steps, ip, iq)
                minimum_count = min(minimum_count, final_count)
                maximum_count = max(maximum_count, final_count)
            end do
        end do

        open(newunit=summary_unit, file=filename // '.tmp', status='replace', action='write', iostat=io_status)
        if (io_status /= 0) error stop 'Could not create summary file'
        write(summary_unit, '(a)') 'Experiment summary'
        write(summary_unit, '(a,i0)') 'p_steps: ', context%p_steps
        write(summary_unit, '(a,i0)') 'q_steps: ', context%q_steps
        write(summary_unit, '(a,i0)') 'max_steps: ', context%max_steps
        write(summary_unit, '(a,i0)') 'grid_size: ', context%grid_size
        write(summary_unit, '(a,i0)') 'simulation_count: ', context%simulation_count
        write(summary_unit, '(a,l1)') 'cut_p_below_half: ', context%cut_p_below_half
        write(summary_unit, '(a,i0)') 'seed: ', simulation_result%seed
        write(summary_unit, '(a,i0)') 'completed_patterns: ', simulation_result%completed_patterns
        write(summary_unit, '(a,f0.6)') 'elapsed_seconds: ', elapsed_seconds
        write(summary_unit, '(a)') 'files: phase_diagram.dat, time_evolution.dat, summary.txt'
        if (simulation_result%completed_patterns > 0_int64) then
            write(summary_unit, '(a,es24.16)') 'final_mean_active_count_min: ', minimum_count
            write(summary_unit, '(a,es24.16)') 'final_mean_active_count_max: ', maximum_count
        else
            write(summary_unit, '(a)') 'final_mean_active_count_min: n/a (no patterns calculated)'
            write(summary_unit, '(a)') 'final_mean_active_count_max: n/a (no patterns calculated)'
        end if
        write(summary_unit, '(a)') 'status: complete'
        close(summary_unit, iostat=io_status)
        if (io_status /= 0) error stop 'Could not finish summary file'
        io_status = c_rename(filename // '.tmp' // c_null_char, filename // c_null_char)
        if (io_status /= 0) error stop 'Could not publish summary file'
    end subroutine write_summary

    subroutine parse_command_line(p_steps, q_steps, max_steps, grid_size, simulation_count, cut_p_below_half, seed)
        integer(kind=int32), intent(out) :: p_steps, q_steps, max_steps, grid_size, simulation_count
        logical, intent(out) :: cut_p_below_half
        integer(kind=int64), intent(out) :: seed
        integer :: argument_count, argument_index, positional_count
        character(len=64) :: option

        p_steps = DEFAULT_P_STEPS
        q_steps = DEFAULT_Q_STEPS
        max_steps = DEFAULT_MAX_STEPS
        grid_size = DEFAULT_GRID_SIZE
        simulation_count = DEFAULT_SIMULATION_COUNT
        cut_p_below_half = .false.
        call system_clock(count=seed)

        argument_count = command_argument_count()
        argument_index = 1
        positional_count = 0
        do while (argument_index <= argument_count)
            call get_command_argument(argument_index, option)
            select case (trim(option))
            case ('--cut-p-below-half')
                cut_p_below_half = .true.
            case ('--seed')
                argument_index = argument_index + 1
                if (argument_index > argument_count) error stop 'Missing value for --seed'
                call read_seed_argument(argument_index, seed)
            case default
                if (index(option, '--') == 1) error stop 'Unknown option'
                positional_count = positional_count + 1
                select case (positional_count)
                case (1)
                    call read_integer_argument(argument_index, p_steps)
                case (2)
                    call read_integer_argument(argument_index, q_steps)
                case (3)
                    call read_integer_argument(argument_index, max_steps)
                case (4)
                    call read_integer_argument(argument_index, grid_size)
                case (5)
                    call read_integer_argument(argument_index, simulation_count)
                case default
                    error stop 'Too many positional arguments'
                end select
            end select
            argument_index = argument_index + 1
        end do
        if (positional_count /= 0 .and. positional_count < 4) &
            error stop 'Usage: ca-phase-transition [p_steps q_steps max_steps grid_size [count]] [--seed N] [--cut-p-below-half]'
    end subroutine parse_command_line

    subroutine read_seed_argument(argument_number, value)
        integer, intent(in) :: argument_number
        integer(kind=int64), intent(out) :: value
        character(len=64) :: argument
        integer :: io_status

        call get_command_argument(argument_number, argument)
        read(argument, *, iostat=io_status) value
        if (io_status /= 0) error stop 'Seed must be a signed 64-bit integer'
    end subroutine read_seed_argument

    subroutine read_integer_argument(argument_number, value)
        integer, intent(in) :: argument_number
        integer(kind=int32), intent(out) :: value
        character(len=64) :: argument
        integer :: io_status

        call get_command_argument(argument_number, argument)
        read(argument, *, iostat=io_status) value
        if (io_status /= 0) then
            error stop 'All command-line arguments must be integers'
        end if
    end subroutine read_integer_argument

    subroutine write_phase_diagram_data(context, simulation_result, data_filename)
        type(SimulationContext_t), intent(in) :: context
        type(SimulationResult_t), intent(in) :: simulation_result
        character(len=*), intent(in) :: data_filename

        integer :: data_unit, io_status
        integer(kind=int32) :: ip, iq, final_step, reachable_sites

        final_step = context%max_steps
        ! Starting from one active site, each update changes the site parity.
        ! On an even ring only one parity class is reachable at a time; on
        ! an odd ring the step-two progression eventually visits every site.
        if (mod(context%grid_size, 2_int32) == 0_int32) then
            reachable_sites = int(min(int(final_step, int64) + 1_int64, &
                                      int(context%grid_size / 2_int32, int64)), int32)
        else
            reachable_sites = int(min(int(final_step, int64) + 1_int64, &
                                      int(context%grid_size, int64)), int32)
        end if

        open(newunit=data_unit, file=data_filename, status='replace', action='write', &
             iostat=io_status)
        if (io_status /= 0) error stop 'Could not open phase diagram data file'

        write(data_unit, '(a,i0)') '# seed: ', simulation_result%seed
        write(data_unit, '(a,i0)') '# grid_size: ', context%grid_size
        write(data_unit, '(a,i0)') '# final_step: ', final_step
        write(data_unit, '(a,i0)') '# reachable_sites: ', reachable_sites
        write(data_unit, '(a)') '# active_fraction = active_count / reachable_sites'
        write(data_unit, '(a)') '# p q active_count active_fraction'
        do iq = 1, context%q_steps
            do ip = 1, context%p_steps
                if (context%cut_p_below_half .and. context%p_values(ip) < 0.5_real64) cycle
                write(data_unit, '(3(es24.16,1x),es24.16)') &
                    context%p_values(ip), context%q_values(iq), &
                    simulation_result%active_count(final_step, ip, iq), &
                    simulation_result%active_count(final_step, ip, iq) / real(reachable_sites, real64)
            end do
            if (iq < context%q_steps) write(data_unit, *)
        end do
        close(data_unit, iostat=io_status)
        if (io_status /= 0) error stop 'Could not finish phase diagram data file'
    end subroutine write_phase_diagram_data

    subroutine write_time_evolution_data(context, simulation_result, data_filename)
        type(SimulationContext_t), intent(in) :: context
        type(SimulationResult_t), intent(in) :: simulation_result
        character(len=*), intent(in) :: data_filename
        integer :: data_unit, io_status
        integer(kind=int32) :: ip, iq, it

        open(newunit=data_unit, file=data_filename, status='replace', action='write', iostat=io_status)
        if (io_status /= 0) error stop 'Could not open time evolution data file'
        write(data_unit, '(a,i0)') '# seed: ', simulation_result%seed
        write(data_unit, '(a)') '# p q k mean_N survivor_count mean_mu mean_mu2 variance_mu mean_sigma2'
        do iq = 1, context%q_steps
            do ip = 1, context%p_steps
                if (context%cut_p_below_half .and. context%p_values(ip) < 0.5_real64) cycle
                do it = 0, context%max_steps
                    write(data_unit, '(es24.16,1x,es24.16,1x,i0,1x,es24.16,1x,i0,4(1x,es24.16))') &
                        context%p_values(ip), context%q_values(iq), it, &
                        simulation_result%active_count(it, ip, iq), &
                        simulation_result%survivor_count(it, ip, iq), &
                        simulation_result%mean_mu(it, ip, iq), &
                        simulation_result%mean_mu2(it, ip, iq), &
                        simulation_result%variance_mu(it, ip, iq), &
                        simulation_result%mean_sigma2(it, ip, iq)
                end do
                if (iq < context%q_steps .or. ip < context%p_steps) write(data_unit, *)
            end do
        end do
        close(data_unit, iostat=io_status)
        if (io_status /= 0) error stop 'Could not finish time evolution data file'
    end subroutine write_time_evolution_data
end program main
