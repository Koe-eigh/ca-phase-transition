program test_test_utils
    use, intrinsic :: iso_fortran_env, only: real64
    use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, &
                                            ieee_positive_inf, ieee_negative_inf
    use test_utils, only: check, is_close
    implicit none

    call check(is_close(1.0_real64, 1.0_real64), 'is_close rejected equal finite values')
    call check(.not. is_close(1.0_real64 + 2.0e-12_real64, 1.0_real64), &
               'is_close accepted a finite mismatch')
    call check(.not. is_close(ieee_value(0.0_real64, ieee_quiet_nan), 1.0_real64), &
               'is_close accepted NaN')
    call check(.not. is_close(ieee_value(0.0_real64, ieee_positive_inf), 1.0_real64), &
               'is_close accepted positive infinity')
    call check(.not. is_close(ieee_value(0.0_real64, ieee_negative_inf), 1.0_real64), &
               'is_close accepted negative infinity')
    call check(.not. is_close(ieee_value(0.0_real64, ieee_positive_inf), &
                              ieee_value(0.0_real64, ieee_positive_inf)), &
               'is_close accepted matching infinities')
end program test_test_utils
