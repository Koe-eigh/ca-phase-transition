module model
    use, intrinsic :: iso_fortran_env, only: int32
    implicit none
    private

    public :: DKCA_t, DKCA

    type :: DKCA_t
        integer(kind=int32), allocatable :: state(:)
        integer(kind=int32), allocatable :: initial_state(:)
        integer(kind=int32), allocatable :: next_state(:)
    contains
        procedure :: reset
        procedure :: step
    end type DKCA_t

    interface DKCA
        module procedure init
    end interface DKCA
contains
    function init(initial_state) result(dkca)
        integer(kind=int32), intent(in) :: initial_state(:)
        type(DKCA_t) :: dkca

        dkca%state = initial_state
        dkca%initial_state = initial_state
        allocate(dkca%next_state(lbound(initial_state, 1):ubound(initial_state, 1)))
    end function init

    subroutine reset(dkca)
        class(DKCA_t), intent(inout) :: dkca

        dkca%state = dkca%initial_state
    end subroutine reset

    function step(dkca, p, q) result(active_count)
        class(DKCA_t), intent(inout) :: dkca
        real, intent(in) :: p, q
        integer(kind=int32) :: active_count

        integer(kind=int32) :: j, left, right
        real :: probability, random_value

        do j = lbound(dkca%state, 1), ubound(dkca%state, 1)
            left = dkca%state(periodic_index(j - 1, dkca%state))
            right = dkca%state(periodic_index(j + 1, dkca%state))

            if (left == 0 .and. right == 0) then
                probability = 0.0
            else if (left == 1 .and. right == 1) then
                probability = 1.0 - q
            else
                probability = 1.0 - p
            end if

            call random_number(random_value)
            dkca%next_state(j) = merge(1_int32, 0_int32, random_value < probability)
        end do

        dkca%state = dkca%next_state
        active_count = sum(dkca%state)
    end function step

    pure function periodic_index(index, state) result(wrapped_index)
        integer(kind=int32), intent(in) :: index
        integer(kind=int32), intent(in) :: state(:)
        integer(kind=int32) :: wrapped_index
        integer(kind=int32) :: first, n

        first = lbound(state, 1)
        n = int(size(state), kind=int32)
        wrapped_index = first + modulo(index - first, n)
    end function periodic_index

end module model
