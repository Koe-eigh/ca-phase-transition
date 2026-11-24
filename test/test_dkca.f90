program test_dkca
    use, intrinsic :: iso_fortran_env, only: int32, int64, real64
    use test_utils, only: check, check_close
    use model, only: DKCA_t, DKCA
    implicit none
    real(real64), parameter :: impossible = 0.0_real64, certain = 1.0_real64
    integer(int32), parameter :: inactive = 0_int32, active = 1_int32

    call test_initial_state_and_spatial_moments()
    call test_deterministic_transitions()
    call test_one_site_ring()
    call test_current_state_moments_after_periodic_wrap()
    call test_cached_moments_follow_state_changes()
    call test_random_stream_across_ring_sizes()
    call test_adjacent_random_draws()

contains
    subroutine test_initial_state_and_spatial_moments()
        type(DKCA_t) :: automaton
        real(real64) :: mu, sigma2
        integer(int32), parameter :: first_coordinate = -2_int32
        integer(int32), parameter :: initial_state(*) = [active, inactive, inactive, active, inactive]

        automaton = DKCA(initial_state, first_index=first_coordinate)
        mu = automaton%current_center_of_mass()
        sigma2 = automaton%current_variance()
        call check_close(mu, -0.5_real64, 'initial state: mean coordinate')
        call check_close(sigma2, 2.25_real64, 'initial state: spatial variance')
        call check(lbound(automaton%state, 1) == first_coordinate, 'initial state: coordinate origin was lost')
    end subroutine test_initial_state_and_spatial_moments

    subroutine test_deterministic_transitions()
        type(DKCA_t) :: automaton
        integer(int32), parameter :: single_seed(*) = [inactive, active, inactive, inactive, inactive]
        integer(int32), parameter :: expected_neighbors(*) = [active, inactive, active, inactive, inactive]

        automaton = DKCA(single_seed)
        call check(automaton%current_active_count() == count(single_seed == active), &
                   'deterministic transitions: initial active count')
        call automaton%step(certain, certain)
        call check(all(automaton%state == expected_neighbors), &
                   'deterministic transitions: certain transition state')
        call check(automaton%current_active_count() == count(expected_neighbors == active), &
                   'deterministic transitions: certain transition count')

        call automaton%reset()
        call check(automaton%current_active_count() == count(single_seed == active), &
                   'deterministic transitions: reset active count')
        call automaton%step(impossible, impossible)
        call check(all(automaton%state == inactive), 'deterministic transitions: impossible transition state')
        call check(automaton%current_active_count() == inactive, &
                   'deterministic transitions: impossible transition count')
    end subroutine test_deterministic_transitions

    subroutine test_one_site_ring()
        type(DKCA_t) :: automaton

        automaton = DKCA([active])
        call automaton%step(impossible, certain)
        call check(automaton%current_active_count() == active, 'one-site ring: certain transition')
        call automaton%step(certain, impossible)
        call check(automaton%current_active_count() == inactive, 'one-site ring: impossible transition')
    end subroutine test_one_site_ring

    subroutine test_current_state_moments_after_periodic_wrap()
        type(DKCA_t) :: automaton
        real(real64) :: mu, sigma2
        integer(int32), parameter :: first_coordinate = -2_int32
        integer(int32), parameter :: centered_seed(*) = [inactive, inactive, active, inactive, inactive]

        automaton = DKCA(centered_seed, first_index=first_coordinate)
        call automaton%step(certain, certain)
        call automaton%step(certain, certain)
        sigma2 = automaton%current_variance()
        call check_close(sigma2, 8.0_real64 / 3.0_real64, 'periodic wrap: variance before wrap')
        call automaton%step(certain, certain)
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
        integer(int32), parameter :: first_coordinate = -2_int32

        automaton = DKCA([active, inactive, inactive, inactive, inactive], &
                         first_index=first_coordinate)
        ! Read variance first, then both cached properties.
        call check_close(automaton%current_variance(), 0.0_real64, 'cache: initial variance')
        call check_close(automaton%current_center_of_mass(), -2.0_real64, 'cache: initial center')
        call check_close(automaton%current_variance(), 0.0_real64, 'cache: repeated variance')

        call automaton%step(certain, certain)
        call check_close(automaton%current_center_of_mass(), 0.5_real64, 'cache: center after step')
        call check_close(automaton%current_variance(), 2.25_real64, 'cache: variance after step')

        call automaton%reset()
        call check_close(automaton%current_center_of_mass(), -2.0_real64, 'cache: center after reset')
        call check_close(automaton%current_variance(), 0.0_real64, 'cache: variance after reset')
    end subroutine test_cached_moments_follow_state_changes

    subroutine test_random_stream_across_ring_sizes()
        type(DKCA_t) :: small, large
        integer(int32), parameter :: small_radius = 15_int32, large_radius = 20_int32
        integer(int32), parameter :: steps_before_wrap = 6_int32
        integer(int64), parameter :: shared_seed = 42_int64
        real(real64), parameter :: p_one_neighbor = 0.7_real64, q_two_neighbors = 0.4_real64
        integer(int32) :: small_state(-small_radius:small_radius), large_state(-large_radius:large_radius), step_index

        small_state = inactive
        large_state = inactive
        small_state(0) = active
        large_state(0) = active
        small = DKCA(small_state, first_index=-small_radius)
        large = DKCA(large_state, first_index=-large_radius)
        call small%seed_stream(shared_seed)
        call large%seed_stream(shared_seed)
        do step_index = 1, steps_before_wrap
            call small%step(p_one_neighbor, q_two_neighbors)
            call large%step(p_one_neighbor, q_two_neighbors)
            call check(all(small%state == large%state(-small_radius:small_radius)), &
                       'random stream: matching sites diverged before periodic wrap')
        end do
    end subroutine test_random_stream_across_ring_sizes

    subroutine test_adjacent_random_draws()
        type(DKCA_t) :: automaton
        integer(int32), parameter :: ring_size = 400_int32, trial_count = 100_int32
        integer(int32), parameter :: pattern_length = 4_int32, active_prefix_length = 2_int32
        integer(int64), parameter :: base_seed = 42_int64
        real(real64), parameter :: half_probability = 0.5_real64, max_abs_correlation = 0.1_real64
        integer(int32) :: mixed_state(ring_size), trial, site
        real(real64) :: adjacent_correlation

        ! Each site in the 1100 pattern has one active neighbor.
        do site = 1, size(mixed_state)
            mixed_state(site) = merge(active, inactive, mod(site - 1, pattern_length) < active_prefix_length)
        end do
        automaton = DKCA(mixed_state)
        adjacent_correlation = 0.0_real64
        do trial = 1, trial_count
            call automaton%reset()
            call automaton%seed_stream(base_seed + int(trial, int64))
            call automaton%step(half_probability, half_probability)
            do site = 1, size(mixed_state)
                adjacent_correlation = adjacent_correlation + &
                    real((2 * automaton%state(site) - 1) * &
                         (2 * automaton%state(mod(site, size(mixed_state)) + 1) - 1), real64)
            end do
        end do
        adjacent_correlation = adjacent_correlation / real(trial_count * size(mixed_state), real64)
        call check(abs(adjacent_correlation) <= max_abs_correlation, 'random stream: adjacent draws are correlated')
    end subroutine test_adjacent_random_draws
end program test_dkca
