program main
    use, intrinsic :: iso_fortran_env, only: int32
    use simulator_module, only: SimulationContext_t, SimulationContext, &
                                Simulator_t, Simulator, SimulationResult_t
    implicit none

    ! Increase these values for a higher-resolution/longer experiment.
    integer(kind=int32), parameter :: P_STEPS = 21_int32
    integer(kind=int32), parameter :: Q_STEPS = 21_int32
    integer(kind=int32), parameter :: MAX_STEPS = 200_int32
    integer(kind=int32), parameter :: GRID_SIZE = 200_int32
    
    type(SimulationContext_t) :: context
    type(Simulator_t) :: sim
    type(SimulationResult_t) :: sim_result

    context = SimulationContext(P_STEPS, Q_STEPS, MAX_STEPS, GRID_SIZE)
    sim = Simulator(context)
    sim_result = sim%simulate()

    call write_phase_diagram_data(context, sim_result, 'phase_diagram.dat')
    print *, 'wrote phase_diagram.dat'

contains
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
                write(data_unit, '(es24.16,1x,es24.16,1x,i0)') &
                    context%p_values(ip), context%q_values(iq), &
                    simulation_result%active_count(final_step, ip, iq)
            end do
            write(data_unit, *)
        end do
        close(data_unit)
    end subroutine write_phase_diagram_data
end program main
