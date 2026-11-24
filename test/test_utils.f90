module test_utils
    use, intrinsic :: iso_fortran_env, only: error_unit, real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_is_nan
    implicit none
    private
    public :: check, check_close, check_nan, check_same_reals, is_close

contains
    subroutine check(condition, message)
        logical, intent(in) :: condition
        character(len=*), intent(in) :: message

        if (condition) return
        write(error_unit, '(a)') message
        error stop 1
    end subroutine check

    pure function is_close(actual, expected) result(matches)
        real(real64), intent(in) :: actual, expected
        logical :: matches

        matches = .false.
        if (ieee_is_finite(actual) .and. ieee_is_finite(expected)) then
            matches = abs(actual - expected) <= 1.0e-12_real64
        end if
    end function is_close

    subroutine check_close(actual, expected, message)
        real(real64), intent(in) :: actual, expected
        character(len=*), intent(in) :: message

        if (is_close(actual, expected)) return
        write(error_unit, '(a, a, es24.16, a, es24.16)') &
            message, ': expected ', expected, ', got ', actual
        error stop 1
    end subroutine check_close

    subroutine check_nan(actual, message)
        real(real64), intent(in) :: actual
        character(len=*), intent(in) :: message

        call check(ieee_is_nan(actual), message)
    end subroutine check_nan

    subroutine check_same_reals(first, second, message)
        real(real64), intent(in) :: first(:, :, :), second(:, :, :)
        character(len=*), intent(in) :: message

        call check(all(ieee_is_nan(first) .eqv. ieee_is_nan(second)), message // ': NaN mask changed')
        call check(all(first == second .or. ieee_is_nan(first)), message // ': values changed')
    end subroutine check_same_reals
end module test_utils
