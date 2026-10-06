program main
    use, intrinsic :: iso_fortran_env, only: int32
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
    logical :: cut_p_below_half
    
    type(SimulationContext_t) :: context
    type(Simulator_t) :: sim
    type(SimulationResult_t) :: sim_result

    call parse_command_line(p_steps, q_steps, max_steps, grid_size, simulation_count, cut_p_below_half)

    context = SimulationContext(p_steps, q_steps, max_steps, grid_size, simulation_count, cut_p_below_half)
    sim = Simulator(context)
    sim_result = sim%simulate()

    call write_phase_diagram_data(context, sim_result, 'phase_diagram.dat')
    print *, 'wrote phase_diagram.dat'

contains
    subroutine parse_command_line(p_steps, q_steps, max_steps, grid_size, simulation_count, cut_p_below_half)
        integer(kind=int32), intent(out) :: p_steps, q_steps, max_steps, grid_size, simulation_count
        logical, intent(out) :: cut_p_below_half
        integer :: argument_count
        character(len=64) :: option

        p_steps = DEFAULT_P_STEPS
        q_steps = DEFAULT_Q_STEPS
        max_steps = DEFAULT_MAX_STEPS
        grid_size = DEFAULT_GRID_SIZE
        simulation_count = DEFAULT_SIMULATION_COUNT
        cut_p_below_half = .false.

        argument_count = command_argument_count()
        if (argument_count == 0) return
        if (argument_count < 4 .or. argument_count > 6) then
            error stop 'Usage: ca-phase-transition [p_steps q_steps max_steps grid_size [simulation_count]] [--cut-p-below-half]'
        end if

        call read_integer_argument(1, p_steps)
        call read_integer_argument(2, q_steps)
        call read_integer_argument(3, max_steps)
        call read_integer_argument(4, grid_size)
        if (argument_count >= 5) then
            call get_command_argument(5, option)
            if (trim(option) == '--cut-p-below-half') then
                cut_p_below_half = .true.
            else
                call read_integer_argument(5, simulation_count)
            end if
        end if
        if (argument_count == 6) then
            call get_command_argument(6, option)
            if (trim(option) /= '--cut-p-below-half') then
                error stop 'Unknown option; expected --cut-p-below-half'
            end if
            cut_p_below_half = .true.
        end if
    end subroutine parse_command_line

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

        write(data_unit, '(a)') '# p q active_count'
        do iq = 1, context%q_steps
            do ip = 1, context%p_steps
                write(data_unit, '(es24.16,1x,es24.16,1x,es24.16)') &
                    context%p_values(ip), context%q_values(iq), &
                    simulation_result%active_count(final_step, ip, iq)
            end do
            write(data_unit, *)
        end do
        close(data_unit)
    end subroutine write_phase_diagram_data
end program main
