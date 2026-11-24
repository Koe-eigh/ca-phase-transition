module random_hash
    use, intrinsic :: iso_fortran_env, only: int64
    implicit none
    private
    public :: mix_hash

contains
    pure function mix_hash(state, value) result(mixed)
        integer(int64), intent(in) :: state, value
        integer(int64) :: mixed
        integer :: round

        ! All products fit in int64; signed overflow is not required.
        mixed = modulo(state + modulo(value, 2147483647_int64), 2147483647_int64)
        do round = 1, 4
            mixed = ieor(mixed, shiftr(mixed, 16 - round))
            mixed = modulo(48271_int64 * mixed, 2147483647_int64)
        end do
        if (mixed == 0_int64) mixed = 1_int64
    end function mix_hash
end module random_hash
