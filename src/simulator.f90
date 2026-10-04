module simulator

    implicit none
    private

    public :: Simulator_t, Simulator, SimulationResult

    type :: Simulator_t
        private
        type(Model_t)
    end type Simulator_t

end module simulator

