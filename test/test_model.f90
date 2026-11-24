program test_model
    use, intrinsic :: iso_fortran_env, only: int32, int64, real64
    use test_utils, only: check, check_close
    use model, only: DKCA_t, DKCA
    implicit none

    call test_initial_state_and_spatial_moments()
    call test_deterministic_transitions()
    call test_one_site_ring()
    call test_current_state_moments_after_periodic_wrap()
    call test_random_stream_across_ring_sizes()
    call test_adjacent_random_draws()

contains
    subroutine test_initial_state_and_spatial_moments()
        type(DKCA_t) :: automaton
        real(real64) :: mu, sigma2

        automaton = DKCA([1_int32, 0_int32, 0_int32, 1_int32, 0_int32], -2_int32)
        call automaton%current_spatial_moments(mu, sigma2)
        call check_close(mu, -0.5_real64, 'initial state: mean coordinate')
        call check_close(sigma2, 2.25_real64, 'initial state: spatial variance')
        call check(lbound(automaton%state, 1) == -2, 'initial state: coordinate origin was lost')
    end subroutine test_initial_state_and_spatial_moments

    subroutine test_deterministic_transitions()
        type(DKCA_t) :: automaton
        integer(int32) :: transition_count

        automaton = DKCA([0_int32, 1_int32, 0_int32, 0_int32, 0_int32])
        call automaton%step(1.0_real64, 1.0_real64, active_count=transition_count)
        call check(all(automaton%state == [1_int32, 0_int32, 1_int32, 0_int32, 0_int32]), &
                   'deterministic transitions: certain transition state')
        call check(transition_count == 2_int32, 'deterministic transitions: certain transition count')

        call automaton%reset()
        call automaton%step(0.0_real64, 0.0_real64, active_count=transition_count)
        call check(all(automaton%state == 0_int32), 'deterministic transitions: impossible transition state')
        call check(transition_count == 0_int32, 'deterministic transitions: impossible transition count')
    end subroutine test_deterministic_transitions

    subroutine test_one_site_ring()
        type(DKCA_t) :: automaton

        automaton = DKCA([1_int32])
        call automaton%step(0.0_real64, 1.0_real64)
        call check(automaton%current_active_count() == 1_int32, 'one-site ring: certain transition')
        call automaton%step(1.0_real64, 0.0_real64)
        call check(automaton%current_active_count() == 0_int32, 'one-site ring: impossible transition')
    end subroutine test_one_site_ring

    subroutine test_current_state_moments_after_periodic_wrap()
        type(DKCA_t) :: automaton
        real(real64) :: mu, sigma2

        automaton = DKCA([0_int32, 0_int32, 1_int32, 0_int32, 0_int32], -2_int32)
        call automaton%step(1.0_real64, 1.0_real64)
        call automaton%step(1.0_real64, 1.0_real64)
        call automaton%current_spatial_moments(mu, sigma2)
        call check_close(sigma2, 8.0_real64 / 3.0_real64, 'periodic wrap: variance before wrap')
        call automaton%step(1.0_real64, 1.0_real64)
        call automaton%current_spatial_moments(mu, sigma2)
        call check_close(mu, 0.0_real64, 'periodic wrap: current state mean')
        call check_close(sigma2, 2.5_real64, 'periodic wrap: current state variance')
        call automaton%reset()
        call automaton%current_spatial_moments(mu, sigma2)
        call check_close(mu, 0.0_real64, 'periodic wrap: reset mean')
    end subroutine test_current_state_moments_after_periodic_wrap

    subroutine test_random_stream_across_ring_sizes()
        type(DKCA_t) :: small, large
        integer(int32) :: small_state(-15:15), large_state(-20:20), step_index

        small_state = 0_int32
        large_state = 0_int32
        small_state(0) = 1_int32
        large_state(0) = 1_int32
        small = DKCA(small_state, -15_int32)
        large = DKCA(large_state, -20_int32)
        call small%seed_stream(42_int64)
        call large%seed_stream(42_int64)
        do step_index = 1, 6
            call small%step(0.7_real64, 0.4_real64)
            call large%step(0.7_real64, 0.4_real64)
            call check(all(small%state == large%state(-15:15)), &
                       'random stream: matching sites diverged before periodic wrap')
        end do
    end subroutine test_random_stream_across_ring_sizes

    subroutine test_adjacent_random_draws()
        type(DKCA_t) :: automaton
        integer(int32) :: mixed_state(400), trial, site
        real(real64) :: adjacent_correlation

        ! Each site in the 1100 pattern has one active neighbor.
        do site = 1, size(mixed_state)
            mixed_state(site) = merge(1_int32, 0_int32, mod(site - 1, 4) < 2)
        end do
        automaton = DKCA(mixed_state)
        adjacent_correlation = 0.0_real64
        do trial = 1, 100
            call automaton%reset()
            call automaton%seed_stream(42_int64 + int(trial, int64))
            call automaton%step(0.5_real64, 0.5_real64)
            do site = 1, size(mixed_state)
                adjacent_correlation = adjacent_correlation + &
                    real((2 * automaton%state(site) - 1) * &
                         (2 * automaton%state(mod(site, size(mixed_state)) + 1) - 1), real64)
            end do
        end do
        adjacent_correlation = adjacent_correlation / real(100 * size(mixed_state), real64)
        call check(abs(adjacent_correlation) <= 0.1_real64, 'random stream: adjacent draws are correlated')
    end subroutine test_adjacent_random_draws
end program test_model
