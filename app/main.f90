program main
    use, intrinsic :: iso_fortran_env, only: int32
    use simulator, only: Simulator_t, Simulator, SimulationResult_t
    implicit none

    integer(kind=int32), parameter :: P_STEPS = 101_int32
    integer(kind=int32), parameter :: Q_STEPS = 101_int32
    integer(kind=int32), parameter :: MAX_STEPS = 10000_int32
    integer(kind=int32), parameter :: GRID_SIZE = 20000_int32
    
    type(Model_t) :: model
    type(Simulator_t) :: sim
    type(SimulatorContext_t) :: sim_ctx
    type(SimulationResult_t) :: sim_result

    sim_ctx = SimulatorContext(P_STEPS, Q_STEPS, MAX_STEPS, GRID_SIZE)
    sim = Simulator(sim_ctx)
    sim_result = sim%simulate()

    call write_results(sim_result)
contains
end program main

