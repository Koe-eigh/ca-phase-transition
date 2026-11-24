program test_simulator
    use, intrinsic :: iso_fortran_env, only: int32, int64, real64
    use omp_lib, only: omp_set_num_threads
    use test_utils, only: check, check_close, check_nan, check_same_reals
    use simulator_module, only: SimulationContext, Simulator, Simulator_t, SimulationResult_t
    implicit none
    integer(int32), parameter :: probability_endpoints = 2_int32
    ! Two sweep points represent probabilities 0 and 1, in that order.
    integer(int32), parameter :: zero_index = 1_int32, one_index = 2_int32
    integer(int32), parameter :: first_step = 1_int32, second_step = 2_int32, wrap_step = 3_int32
    integer(int32), parameter :: odd_ring_size = 5_int32, even_ring_size = 6_int32
    integer(int32), parameter :: deterministic_trials = 3_int32

    call test_deterministic_growth()
    call test_odd_ring_wrap()
    call test_even_ring_wrap()
    call test_extinction()
    call test_seeded_reproducibility()

contains
    subroutine test_deterministic_growth()
        type(Simulator_t) :: sim
        type(SimulationResult_t) :: result

        ! At p=q=1, a seed produces -1,+1 at k=1 and -2,0,+2 at k=2.
        ! Their spatial variances are 1 and (4+0+4)/3.
        sim = Simulator(SimulationContext(p_steps=probability_endpoints, q_steps=probability_endpoints, &
                                          max_steps=wrap_step, grid_size=odd_ring_size, &
                                          simulation_count=deterministic_trials))
        result = sim%simulate()
        call check(all(result%survivor_count(:, one_index, one_index) &
                       == deterministic_trials), &
                   'deterministic growth: survivor count')
        call check_close(result%active_count(second_step, one_index, one_index), &
                         3.0_real64, 'deterministic growth: active count')
        call check_close(result%mean_mu(second_step, one_index, one_index), &
                         0.0_real64, 'deterministic growth: mean mu')
        call check_close(result%mean_mu2(second_step, one_index, one_index), &
                         0.0_real64, 'deterministic growth: mean mu squared')
        call check_close(result%variance_mu(second_step, one_index, one_index), &
                         0.0_real64, 'deterministic growth: variance mu')
        call check_close(result%mean_sigma2(first_step, one_index, one_index), &
                         1.0_real64, 'deterministic growth: variance at step 1')
        call check_close(result%mean_sigma2(second_step, one_index, one_index), &
                         8.0_real64 / 3.0_real64, &
                         'deterministic growth: variance at step 2')
    end subroutine test_deterministic_growth

    subroutine test_odd_ring_wrap()
        type(Simulator_t) :: sim
        type(SimulationResult_t) :: result

        sim = Simulator(SimulationContext(p_steps=probability_endpoints, q_steps=probability_endpoints, &
                                          max_steps=wrap_step, grid_size=odd_ring_size, &
                                          simulation_count=deterministic_trials))
        result = sim%simulate()
        call check(result%survivor_count(wrap_step, one_index, one_index) &
                   == deterministic_trials, 'odd ring: wrapped survivors')
        call check_close(result%active_count(wrap_step, one_index, one_index), &
                         4.0_real64, 'odd ring: wrapped active count')
        call check_nan(result%mean_mu(wrap_step, one_index, one_index), &
                       'odd ring: wrapped mean mu')
        call check_nan(result%mean_mu2(wrap_step, one_index, one_index), &
                       'odd ring: wrapped mean mu squared')
        call check_nan(result%variance_mu(wrap_step, one_index, one_index), &
                       'odd ring: wrapped variance mu')
        call check_nan(result%mean_sigma2(wrap_step, one_index, one_index), &
                       'odd ring: wrapped spatial variance')
    end subroutine test_odd_ring_wrap

    subroutine test_even_ring_wrap()
        type(Simulator_t) :: sim
        type(SimulationResult_t) :: result

        sim = Simulator(SimulationContext(p_steps=probability_endpoints, q_steps=probability_endpoints, &
                                          max_steps=wrap_step, grid_size=even_ring_size))
        result = sim%simulate()
        call check_close(result%mean_sigma2(second_step, one_index, one_index), &
                         8.0_real64 / 3.0_real64, &
                         'even ring: variance before wrap')
        call check(result%survivor_count(wrap_step, one_index, one_index) &
                   == 1_int32, 'even ring: wrapped survivor')
        call check_nan(result%mean_sigma2(wrap_step, one_index, one_index), &
                       'even ring: wrapped spatial variance')
    end subroutine test_even_ring_wrap

    subroutine test_extinction()
        type(Simulator_t) :: sim
        type(SimulationResult_t) :: result

        ! At p=q=0, all trials are extinct from k=1 onward.
        sim = Simulator(SimulationContext(p_steps=probability_endpoints, q_steps=probability_endpoints, &
                                          max_steps=wrap_step, grid_size=odd_ring_size, &
                                          simulation_count=deterministic_trials))
        result = sim%simulate()
        call check(result%survivor_count(first_step, zero_index, zero_index) &
                   == 0_int32, 'extinction: survivor count')
        call check_close(result%active_count(first_step, zero_index, zero_index), &
                         0.0_real64, 'extinction: active count')
        call check_nan(result%mean_mu(first_step, zero_index, zero_index), &
                       'extinction: mean mu')
        call check_nan(result%mean_mu2(first_step, zero_index, zero_index), &
                       'extinction: mean mu squared')
        call check_nan(result%variance_mu(first_step, zero_index, zero_index), &
                       'extinction: variance mu')
        call check_nan(result%mean_sigma2(first_step, zero_index, zero_index), &
                       'extinction: spatial variance')
    end subroutine test_extinction

    subroutine test_seeded_reproducibility()
        type(Simulator_t) :: sim
        type(SimulationResult_t) :: first, second
        integer(int32), parameter :: parameter_points = 3_int32, time_steps = 20_int32
        integer(int32), parameter :: ring_size = 31_int32, trials = 7_int32
        integer(int64), parameter :: first_seed = 123456789_int64, second_seed = 987654321_int64
        integer, parameter :: single_thread = 1, multiple_threads = 4

        ! Parameter points and trials own their streams, independent of scheduling.
        sim = Simulator(SimulationContext(p_steps=parameter_points, q_steps=parameter_points, &
                                          max_steps=time_steps, grid_size=ring_size, &
                                          simulation_count=trials, seed=first_seed))
        call omp_set_num_threads(single_thread)
        first = sim%simulate()
        call check(first%seed == first_seed, 'seeded simulation: effective seed')
        second = sim%simulate()
        call check_same_results(first, second)

        call omp_set_num_threads(multiple_threads)
        second = sim%simulate()
        call check_same_results(first, second)

        sim = Simulator(SimulationContext(p_steps=parameter_points, q_steps=parameter_points, &
                                          max_steps=time_steps, grid_size=ring_size, &
                                          simulation_count=trials, seed=second_seed))
        second = sim%simulate()
        call check(any(first%active_count /= second%active_count), &
                   'seeded simulation: different seeds produced the same observations')
    end subroutine test_seeded_reproducibility

    subroutine check_same_results(first, second)
        type(SimulationResult_t), intent(in) :: first, second

        call check(all(first%active_count == second%active_count), 'seeded simulation: active count changed')
        call check(all(first%survivor_count == second%survivor_count), 'seeded simulation: survivors changed')
        call check_same_reals(first%mean_mu, second%mean_mu, 'seeded simulation: mean mu')
        call check_same_reals(first%mean_mu2, second%mean_mu2, 'seeded simulation: mean mu squared')
        call check_same_reals(first%variance_mu, second%variance_mu, 'seeded simulation: variance mu')
        call check_same_reals(first%mean_sigma2, second%mean_sigma2, 'seeded simulation: spatial variance')
    end subroutine check_same_results

end program test_simulator
