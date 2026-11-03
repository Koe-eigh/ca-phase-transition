program test_model
    use, intrinsic :: iso_fortran_env, only: int32, real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
    use model, only: DKCA_t, DKCA
    use simulator_module, only: SimulationContext, Simulator, Simulator_t, SimulationResult_t
    implicit none
    type(DKCA_t) :: automaton
    type(Simulator_t) :: sim
    type(SimulationResult_t) :: result
    real(real64) :: mu, sigma2
    integer(kind=int32) :: transition_count

    automaton = DKCA([1_int32, 0_int32, 0_int32, 1_int32, 0_int32], -2_int32)
    call automaton%current_spatial_moments(2_int32, mu, sigma2)
    call check_close(mu, -0.5_real64)
    call check_close(sigma2, 2.25_real64)
    if (lbound(automaton%state, 1) /= -2) error stop 'Coordinate origin was lost'

    ! Boundary probabilities exercise both deterministic transition outcomes.
    automaton = DKCA([0_int32, 1_int32, 0_int32, 0_int32, 0_int32])
    call automaton%step(1.0_real64, 1.0_real64, active_count=transition_count)
    if (any(automaton%state /= [1_int32, 0_int32, 1_int32, 0_int32, 0_int32])) &
        error stop 'Certain transitions produced the wrong state'
    if (transition_count /= 2_int32) error stop 'Certain transition count mismatch'
    call automaton%reset()
    call automaton%step(0.0_real64, 0.0_real64, active_count=transition_count)
    if (any(automaton%state /= 0_int32)) error stop 'Impossible transitions stayed active'
    if (transition_count /= 0_int32) error stop 'Impossible transition count mismatch'

    ! At p=q=1, a single seed produces sites -1,+1 at k=1 and -2,0,+2 at k=2.
    sim = Simulator(SimulationContext(2_int32, 2_int32, 3_int32, 5_int32, 3_int32))
    result = sim%simulate()
    if (any(result%survivor_count(:, 2, 2) /= 3_int32)) error stop 'Survivor count mismatch'
    call check_close(result%active_count(2, 2, 2), 3.0_real64)
    call check_close(result%mean_mu(2, 2, 2), 0.0_real64)
    call check_close(result%mean_mu2(2, 2, 2), 0.0_real64)
    call check_close(result%variance_mu(2, 2, 2), 0.0_real64)
    call check_close(result%mean_sigma2(1, 2, 2), 1.0_real64)
    call check_close(result%mean_sigma2(2, 2, 2), 8.0_real64 / 3.0_real64)
    if (result%survivor_count(3, 2, 2) /= 3_int32) error stop 'Wrapped survivors were lost'
    call check_close(result%active_count(3, 2, 2), 4.0_real64)
    if (.not. ieee_is_nan(result%mean_mu(3, 2, 2))) error stop 'Wrapped mean_mu must be NaN'
    if (.not. ieee_is_nan(result%mean_mu2(3, 2, 2))) error stop 'Wrapped mean_mu2 must be NaN'
    if (.not. ieee_is_nan(result%variance_mu(3, 2, 2))) error stop 'Wrapped variance_mu must be NaN'
    if (.not. ieee_is_nan(result%mean_sigma2(3, 2, 2))) error stop 'Wrapped mean_sigma2 must be NaN'

    automaton = DKCA([0_int32, 0_int32, 1_int32, 0_int32, 0_int32], -2_int32)
    call automaton%step(1.0_real64, 1.0_real64)
    call automaton%step(1.0_real64, 1.0_real64)
    call automaton%current_spatial_moments(3_int32, mu, sigma2)
    call check_close(sigma2, 8.0_real64 / 3.0_real64)
    call automaton%step(1.0_real64, 1.0_real64)
    call automaton%current_spatial_moments(4_int32, mu, sigma2)
    if (.not. ieee_is_nan(mu) .or. .not. ieee_is_nan(sigma2)) &
        error stop 'Wrapped model moments must be NaN'
    call automaton%reset()
    call automaton%current_spatial_moments(1_int32, mu, sigma2)
    call check_close(mu, 0.0_real64)

    ! On an even ring, the opposite site is first reached at n/2 steps.
    sim = Simulator(SimulationContext(2_int32, 2_int32, 3_int32, 6_int32))
    result = sim%simulate()
    call check_close(result%mean_sigma2(2, 2, 2), 8.0_real64 / 3.0_real64)
    if (result%survivor_count(3, 2, 2) /= 1_int32) error stop 'Even-ring survivor was lost'
    if (.not. ieee_is_nan(result%mean_sigma2(3, 2, 2))) &
        error stop 'Even-ring wrapped moment must be NaN'

    ! At p=q=0 all trials are extinct from k=1 onward.
    if (result%survivor_count(1, 1, 1) /= 0_int32) error stop 'Extinct trials counted as survivors'
    call check_close(result%active_count(1, 1, 1), 0.0_real64)
    if (.not. ieee_is_nan(result%mean_mu(1, 1, 1))) error stop 'Undefined mean_mu must be NaN'
    if (.not. ieee_is_nan(result%mean_mu2(1, 1, 1))) error stop 'Undefined mean_mu2 must be NaN'
    if (.not. ieee_is_nan(result%variance_mu(1, 1, 1))) error stop 'Undefined variance_mu must be NaN'
    if (.not. ieee_is_nan(result%mean_sigma2(1, 1, 1))) error stop 'Undefined mean_sigma2 must be NaN'

contains
    subroutine check_close(actual, expected)
        real(real64), intent(in) :: actual, expected
        if (ieee_is_nan(actual)) error stop 'Unexpected NaN moment'
        if (abs(actual - expected) > 1.0e-12_real64) error stop 'Moment mismatch'
    end subroutine check_close
end program test_model

