program test_model
    use, intrinsic :: iso_fortran_env, only: int32, int64, real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_is_nan, ieee_value, &
                                            ieee_quiet_nan, ieee_positive_inf, ieee_negative_inf
    use omp_lib, only: omp_set_num_threads
    use model, only: DKCA_t, DKCA
    use simulator_module, only: SimulationContext, Simulator, Simulator_t, SimulationResult_t
    implicit none
    type(DKCA_t) :: automaton
    type(DKCA_t) :: larger_automaton
    type(Simulator_t) :: sim
    type(SimulationResult_t) :: result
    type(SimulationResult_t) :: seeded_result, repeated_result
    real(real64) :: mu, sigma2
    logical :: close_result
    integer(kind=int32) :: transition_count
    integer(kind=int32) :: small_state(-15:15), large_state(-20:20), step_index

    ! Exercise the assertion itself, including values for which subtraction
    ! and comparison alone cannot establish a finite match.
    call check_close(1.0_real64, 1.0_real64, close_result)
    if (.not. close_result) error stop 'check_close rejected equal finite values'
    call check_close(1.0_real64 + 2.0e-12_real64, 1.0_real64, close_result)
    if (close_result) error stop 'check_close accepted a finite mismatch'
    call check_close(ieee_value(0.0_real64, ieee_quiet_nan), 1.0_real64, close_result)
    if (close_result) error stop 'check_close accepted NaN'
    call check_close(ieee_value(0.0_real64, ieee_positive_inf), 1.0_real64, close_result)
    if (close_result) error stop 'check_close accepted positive infinity'
    call check_close(ieee_value(0.0_real64, ieee_negative_inf), 1.0_real64, close_result)
    if (close_result) error stop 'check_close accepted negative infinity'
    call check_close(ieee_value(0.0_real64, ieee_positive_inf), &
                     ieee_value(0.0_real64, ieee_positive_inf), close_result)
    if (close_result) error stop 'check_close accepted matching infinities'

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

    ! Streams belong to parameter points and trials, independent of scheduling.
    sim = Simulator(SimulationContext(3_int32, 3_int32, 20_int32, 31_int32, 7_int32, &
                                      seed=123456789_int64))
    call omp_set_num_threads(1)
    seeded_result = sim%simulate()
    if (seeded_result%seed /= 123456789_int64) error stop 'Effective seed was not recorded'
    repeated_result = sim%simulate()
    call check_same_results(seeded_result, repeated_result)
    call omp_set_num_threads(4)
    repeated_result = sim%simulate()
    call check_same_results(seeded_result, repeated_result)
    sim = Simulator(SimulationContext(3_int32, 3_int32, 20_int32, 31_int32, 7_int32, &
                                      seed=987654321_int64))
    repeated_result = sim%simulate()
    if (all(seeded_result%active_count == repeated_result%active_count)) &
        error stop 'Different seeds produced the same observations'

    ! Matching coordinates receive matching random draws on different rings.
    small_state = 0_int32
    large_state = 0_int32
    small_state(0) = 1_int32
    large_state(0) = 1_int32
    automaton = DKCA(small_state, -15_int32)
    larger_automaton = DKCA(large_state, -20_int32)
    call automaton%seed_stream(42_int64, 1_int32, 1_int32, 1_int32)
    call larger_automaton%seed_stream(42_int64, 1_int32, 1_int32, 1_int32)
    do step_index = 1, 6
        call automaton%step(0.7_real64, 0.4_real64)
        call larger_automaton%step(0.7_real64, 0.4_real64)
        if (any(automaton%state /= larger_automaton%state(-15:15))) &
            error stop 'Matching sites diverged before periodic wrap'
    end do

contains
    subroutine check_same_results(first, second)
        type(SimulationResult_t), intent(in) :: first, second

        if (any(first%active_count /= second%active_count)) error stop 'Seeded mean_N changed'
        if (any(first%survivor_count /= second%survivor_count)) error stop 'Seeded survivors changed'
        call check_same_reals(first%mean_mu, second%mean_mu)
        call check_same_reals(first%mean_mu2, second%mean_mu2)
        call check_same_reals(first%variance_mu, second%variance_mu)
        call check_same_reals(first%mean_sigma2, second%mean_sigma2)
    end subroutine check_same_results

    subroutine check_same_reals(first, second)
        real(real64), intent(in) :: first(:, :, :), second(:, :, :)

        if (any(ieee_is_nan(first) .neqv. ieee_is_nan(second))) error stop 'Seeded NaN mask changed'
        if (any(first /= second .and. .not. ieee_is_nan(first))) error stop 'Seeded moments changed'
    end subroutine check_same_reals

    subroutine check_close(actual, expected, matches)
        real(real64), intent(in) :: actual, expected
        logical, intent(out), optional :: matches
        logical :: is_close

        is_close = .false.
        if (ieee_is_finite(actual) .and. ieee_is_finite(expected)) then
            is_close = abs(actual - expected) <= 1.0e-12_real64
        end if
        if (present(matches)) then
            matches = is_close
        else
            if (.not. is_close) error stop 'Moment mismatch or non-finite value'
        end if
    end subroutine check_close
end program test_model

