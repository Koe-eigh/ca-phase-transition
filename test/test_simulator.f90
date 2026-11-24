program test_simulator
    use, intrinsic :: iso_fortran_env, only: int32, int64, real64
    use omp_lib, only: omp_set_num_threads
    use test_utils, only: check, check_close, check_nan, check_same_reals
    use simulator_module, only: SimulationContext, Simulator, Simulator_t, SimulationResult_t
    implicit none

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
        sim = Simulator(SimulationContext(2_int32, 2_int32, 3_int32, 5_int32, 3_int32))
        result = sim%simulate()
        call check(all(result%survivor_count(:, 2, 2) == 3_int32), &
                   'deterministic growth: survivor count')
        call check_close(result%active_count(2, 2, 2), 3.0_real64, 'deterministic growth: active count')
        call check_close(result%mean_mu(2, 2, 2), 0.0_real64, 'deterministic growth: mean mu')
        call check_close(result%mean_mu2(2, 2, 2), 0.0_real64, 'deterministic growth: mean mu squared')
        call check_close(result%variance_mu(2, 2, 2), 0.0_real64, 'deterministic growth: variance mu')
        call check_close(result%mean_sigma2(1, 2, 2), 1.0_real64, 'deterministic growth: variance at step 1')
        call check_close(result%mean_sigma2(2, 2, 2), 8.0_real64 / 3.0_real64, &
                         'deterministic growth: variance at step 2')
    end subroutine test_deterministic_growth

    subroutine test_odd_ring_wrap()
        type(Simulator_t) :: sim
        type(SimulationResult_t) :: result

        sim = Simulator(SimulationContext(2_int32, 2_int32, 3_int32, 5_int32, 3_int32))
        result = sim%simulate()
        call check(result%survivor_count(3, 2, 2) == 3_int32, 'odd ring: wrapped survivors')
        call check_close(result%active_count(3, 2, 2), 4.0_real64, 'odd ring: wrapped active count')
        call check_nan(result%mean_mu(3, 2, 2), 'odd ring: wrapped mean mu')
        call check_nan(result%mean_mu2(3, 2, 2), 'odd ring: wrapped mean mu squared')
        call check_nan(result%variance_mu(3, 2, 2), 'odd ring: wrapped variance mu')
        call check_nan(result%mean_sigma2(3, 2, 2), 'odd ring: wrapped spatial variance')
    end subroutine test_odd_ring_wrap

    subroutine test_even_ring_wrap()
        type(Simulator_t) :: sim
        type(SimulationResult_t) :: result

        sim = Simulator(SimulationContext(2_int32, 2_int32, 3_int32, 6_int32))
        result = sim%simulate()
        call check_close(result%mean_sigma2(2, 2, 2), 8.0_real64 / 3.0_real64, &
                         'even ring: variance before wrap')
        call check(result%survivor_count(3, 2, 2) == 1_int32, 'even ring: wrapped survivor')
        call check_nan(result%mean_sigma2(3, 2, 2), 'even ring: wrapped spatial variance')
    end subroutine test_even_ring_wrap

    subroutine test_extinction()
        type(Simulator_t) :: sim
        type(SimulationResult_t) :: result

        ! At p=q=0, all trials are extinct from k=1 onward.
        sim = Simulator(SimulationContext(2_int32, 2_int32, 3_int32, 5_int32, 3_int32))
        result = sim%simulate()
        call check(result%survivor_count(1, 1, 1) == 0_int32, 'extinction: survivor count')
        call check_close(result%active_count(1, 1, 1), 0.0_real64, 'extinction: active count')
        call check_nan(result%mean_mu(1, 1, 1), 'extinction: mean mu')
        call check_nan(result%mean_mu2(1, 1, 1), 'extinction: mean mu squared')
        call check_nan(result%variance_mu(1, 1, 1), 'extinction: variance mu')
        call check_nan(result%mean_sigma2(1, 1, 1), 'extinction: spatial variance')
    end subroutine test_extinction

    subroutine test_seeded_reproducibility()
        type(Simulator_t) :: sim
        type(SimulationResult_t) :: first, second

        ! Parameter points and trials own their streams, independent of scheduling.
        sim = Simulator(SimulationContext(3_int32, 3_int32, 20_int32, 31_int32, 7_int32, &
                                          seed=123456789_int64))
        call omp_set_num_threads(1)
        first = sim%simulate()
        call check(first%seed == 123456789_int64, 'seeded simulation: effective seed')
        second = sim%simulate()
        call check_same_results(first, second)

        call omp_set_num_threads(4)
        second = sim%simulate()
        call check_same_results(first, second)

        sim = Simulator(SimulationContext(3_int32, 3_int32, 20_int32, 31_int32, 7_int32, &
                                          seed=987654321_int64))
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
