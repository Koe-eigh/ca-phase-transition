program main
    use, intrinsic :: iso_fortran_env, only: int32, int64, real64
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
    logical :: cut_p_below_half
    
    type(SimulationContext_t) :: context
    type(Simulator_t) :: sim
    type(SimulationResult_t) :: sim_result

    call parse_command_line(p_steps, q_steps, max_steps, grid_size, simulation_count, cut_p_below_half, seed)

    context = SimulationContext(p_steps, q_steps, max_steps, grid_size, simulation_count, cut_p_below_half, seed)
    print '(a,i0)', 'seed: ', context%seed
    sim = Simulator(context)
    sim_result = sim%simulate()

    call write_phase_diagram_data(context, sim_result, 'phase_diagram.dat')
    print *, 'wrote phase_diagram.dat'
    call write_time_evolution_data(context, sim_result, 'time_evolution.dat')
    print *, 'wrote time_evolution.dat'

contains
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
        integer(kind=int32) :: ip, iq, final_step

        final_step = context%max_steps

        open(newunit=data_unit, file=data_filename, status='replace', action='write', &
             iostat=io_status)
        if (io_status /= 0) error stop 'Could not open phase diagram data file'

        write(data_unit, '(a,i0)') '# seed: ', simulation_result%seed
        write(data_unit, '(a)') '# p q active_count'
        do iq = 1, context%q_steps
            do ip = 1, context%p_steps
                if (context%cut_p_below_half .and. context%p_values(ip) < 0.5_real64) cycle
                write(data_unit, '(es24.16,1x,es24.16,1x,es24.16)') &
                    context%p_values(ip), context%q_values(iq), &
                    simulation_result%active_count(final_step, ip, iq)
            end do
            if (iq < context%q_steps) write(data_unit, *)
        end do
        close(data_unit)
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
        close(data_unit)
    end subroutine write_time_evolution_data
end program main
