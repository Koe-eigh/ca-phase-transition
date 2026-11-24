program test_dkca
    use, intrinsic :: iso_fortran_env, only: int32, int64, real64
    use test_utils, only: check, check_close
    use dkca, only: DKCA_t, new_DKCA
    implicit none
    real(real64), parameter :: IMPOSSIBLE = 0.0_real64, CERTAIN = 1.0_real64
    integer(int32), parameter :: INACTIVE = 0_int32, ACTIVE = 1_int32

    call test_initial_state_and_spatial_moments()
    call test_deterministic_transitions()
    call test_large_active_count_with_byte_storage()
    call test_one_site_ring()
    call test_current_state_moments_after_periodic_wrap()
    call test_cached_moments_follow_state_changes()
    call test_random_stream_across_ring_sizes()
    call test_adjacent_random_draws()

contains
    subroutine test_initial_state_and_spatial_moments()
        type(DKCA_t) :: automaton
        real(real64) :: mu, sigma2
        integer(int32), parameter :: FIRST_COORDINATE = -2_int32
        integer(int32), parameter :: INITIAL_STATE(*) = [ACTIVE, INACTIVE, INACTIVE, ACTIVE, INACTIVE]

        automaton = new_DKCA(INITIAL_STATE, first_index=FIRST_COORDINATE)
        mu = automaton%current_center_of_mass()
        sigma2 = automaton%current_variance()
        call check_close(mu, -0.5_real64, 'initial state: mean coordinate')
        call check_close(sigma2, 2.25_real64, 'initial state: spatial variance')
        call check(lbound(automaton%state, dim=1) == FIRST_COORDINATE, 'initial state: coordinate origin was lost')
    end subroutine test_initial_state_and_spatial_moments

    subroutine test_deterministic_transitions()
        type(DKCA_t) :: automaton
        integer(int32), parameter :: SINGLE_SEED(*) = [INACTIVE, ACTIVE, INACTIVE, INACTIVE, INACTIVE]
        integer(int32), parameter :: EXPECTED_NEIGHBORS(*) = [ACTIVE, INACTIVE, ACTIVE, INACTIVE, INACTIVE]

        automaton = new_DKCA(SINGLE_SEED)
        call check(automaton%current_active_count() == count(SINGLE_SEED == ACTIVE), &
                   'deterministic transitions: initial active count')
        call automaton%step(CERTAIN, CERTAIN)
        call check(all(automaton%state == EXPECTED_NEIGHBORS), &
                   'deterministic transitions: certain transition state')
        call check(automaton%current_active_count() == count(EXPECTED_NEIGHBORS == ACTIVE), &
                   'deterministic transitions: certain transition count')

        call automaton%reset()
        call check(automaton%current_active_count() == count(SINGLE_SEED == ACTIVE), &
                   'deterministic transitions: reset active count')
        call automaton%step(IMPOSSIBLE, IMPOSSIBLE)
        call check(all(automaton%state == INACTIVE), 'deterministic transitions: impossible transition state')
        call check(automaton%current_active_count() == INACTIVE, &
                   'deterministic transitions: impossible transition count')
    end subroutine test_deterministic_transitions

    subroutine test_large_active_count_with_byte_storage()
        type(DKCA_t) :: automaton
        integer(int32), parameter :: RING_SIZE = 256_int32
        integer(int32) :: full_state(RING_SIZE)

        full_state = ACTIVE
        automaton = new_DKCA(full_state)
        call check(storage_size(automaton%state(1)) == 8, 'state must use one byte per site')
        call check(automaton%current_active_count() == RING_SIZE, 'byte storage: initial active count')
        call automaton%step(CERTAIN, CERTAIN)
        call check(automaton%current_active_count() == RING_SIZE, 'byte storage: active count after step')
        call automaton%reset()
        call check(automaton%current_active_count() == RING_SIZE, 'byte storage: active count after reset')
    end subroutine test_large_active_count_with_byte_storage

    subroutine test_one_site_ring()
        type(DKCA_t) :: automaton

        automaton = new_DKCA([ACTIVE])
        call automaton%step(IMPOSSIBLE, CERTAIN)
        call check(automaton%current_active_count() == ACTIVE, 'one-site ring: certain transition')
        call automaton%step(CERTAIN, IMPOSSIBLE)
        call check(automaton%current_active_count() == INACTIVE, 'one-site ring: impossible transition')
    end subroutine test_one_site_ring

    subroutine test_current_state_moments_after_periodic_wrap()
        type(DKCA_t) :: automaton
        real(real64) :: mu, sigma2
        integer(int32), parameter :: FIRST_COORDINATE = -2_int32
        integer(int32), parameter :: CENTERED_SEED(*) = [INACTIVE, INACTIVE, ACTIVE, INACTIVE, INACTIVE]

        automaton = new_DKCA(CENTERED_SEED, first_index=FIRST_COORDINATE)
        call automaton%step(CERTAIN, CERTAIN)
        call automaton%step(CERTAIN, CERTAIN)
        sigma2 = automaton%current_variance()
        call check_close(sigma2, 8.0_real64 / 3.0_real64, 'periodic wrap: variance before wrap')
        call automaton%step(CERTAIN, CERTAIN)
        mu = automaton%current_center_of_mass()
        sigma2 = automaton%current_variance()
        call check_close(mu, 0.0_real64, 'periodic wrap: current state mean')
        call check_close(sigma2, 2.5_real64, 'periodic wrap: current state variance')
        call automaton%reset()
        mu = automaton%current_center_of_mass()
        call check_close(mu, 0.0_real64, 'periodic wrap: reset mean')
    end subroutine test_current_state_moments_after_periodic_wrap

    subroutine test_cached_moments_follow_state_changes()
        type(DKCA_t) :: automaton
        integer(int32), parameter :: FIRST_COORDINATE = -2_int32

        automaton = new_DKCA([ACTIVE, INACTIVE, INACTIVE, INACTIVE, INACTIVE], &
                         first_index=FIRST_COORDINATE)
        ! Read variance first, then both cached properties.
        call check_close(automaton%current_variance(), 0.0_real64, 'cache: initial variance')
        call check_close(automaton%current_center_of_mass(), -2.0_real64, 'cache: initial center')
        call check_close(automaton%current_variance(), 0.0_real64, 'cache: repeated variance')

        call automaton%step(CERTAIN, CERTAIN)
        call check_close(automaton%current_center_of_mass(), 0.5_real64, 'cache: center after step')
        call check_close(automaton%current_variance(), 2.25_real64, 'cache: variance after step')

        call automaton%reset()
        call check_close(automaton%current_center_of_mass(), -2.0_real64, 'cache: center after reset')
        call check_close(automaton%current_variance(), 0.0_real64, 'cache: variance after reset')
    end subroutine test_cached_moments_follow_state_changes

    subroutine test_random_stream_across_ring_sizes()
        type(DKCA_t) :: small, large
        integer(int32), parameter :: SMALL_RADIUS = 15_int32, LARGE_RADIUS = 20_int32
        integer(int32), parameter :: STEPS_BEFORE_WRAP = 6_int32
        integer(int64), parameter :: SHARED_SEED = 42_int64
        real(real64), parameter :: P_ONE_NEIGHBOR = 0.7_real64, Q_TWO_NEIGHBORS = 0.4_real64
        integer(int32) :: small_state(-SMALL_RADIUS:SMALL_RADIUS), large_state(-LARGE_RADIUS:LARGE_RADIUS), step_index

        small_state = INACTIVE
        large_state = INACTIVE
        small_state(0) = ACTIVE
        large_state(0) = ACTIVE
        small = new_DKCA(small_state, first_index=-SMALL_RADIUS)
        large = new_DKCA(large_state, first_index=-LARGE_RADIUS)
        call small%set_seed(SHARED_SEED)
        call large%set_seed(SHARED_SEED)
        do step_index = 1, STEPS_BEFORE_WRAP
            call small%step(P_ONE_NEIGHBOR, Q_TWO_NEIGHBORS)
            call large%step(P_ONE_NEIGHBOR, Q_TWO_NEIGHBORS)
            call check(all(small%state == large%state(-SMALL_RADIUS:SMALL_RADIUS)), &
                       'random stream: matching sites diverged before periodic wrap')
        end do
    end subroutine test_random_stream_across_ring_sizes

    subroutine test_adjacent_random_draws()
        type(DKCA_t) :: automaton
        integer(int32), parameter :: RING_SIZE = 400_int32, TRIAL_COUNT = 100_int32
        integer(int32), parameter :: PATTERN_LENGTH = 4_int32, ACTIVE_PREFIX_LENGTH = 2_int32
        integer(int64), parameter :: BASE_SEED = 42_int64
        real(real64), parameter :: HALF_PROBABILITY = 0.5_real64, MAX_ABS_CORRELATION = 0.1_real64
        integer(int32) :: mixed_state(RING_SIZE), trial, site
        real(real64) :: adjacent_correlation

        ! Each site in the 1100 pattern has one active neighbor.
        do site = 1, size(mixed_state)
            mixed_state(site) = merge(ACTIVE, INACTIVE, mod(site - 1, PATTERN_LENGTH) < ACTIVE_PREFIX_LENGTH)
        end do
        automaton = new_DKCA(mixed_state)
        adjacent_correlation = 0.0_real64
        do trial = 1, TRIAL_COUNT
            call automaton%reset()
            call automaton%set_seed(BASE_SEED + int(trial, int64))
            call automaton%step(HALF_PROBABILITY, HALF_PROBABILITY)
            do site = 1, size(mixed_state)
                adjacent_correlation = adjacent_correlation + &
                    real((2 * automaton%state(site) - 1) * &
                         (2 * automaton%state(mod(site, size(mixed_state)) + 1) - 1), real64)
            end do
        end do
        adjacent_correlation = adjacent_correlation / real(TRIAL_COUNT * size(mixed_state), real64)
        call check(abs(adjacent_correlation) <= MAX_ABS_CORRELATION, 'random stream: adjacent draws are correlated')
    end subroutine test_adjacent_random_draws
end program test_dkca
