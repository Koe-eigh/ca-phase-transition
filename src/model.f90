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
        procedure :: current_active_count
        procedure, private :: periodic_index
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

    subroutine step(dkca, p, q, active_count)
        class(DKCA_t), intent(inout) :: dkca
        real, intent(in) :: p, q
        integer(kind=int32), intent(out), optional :: active_count

        integer(kind=int32) :: j, left, right, next_active_count
        real :: probability, random_value

        next_active_count = 0_int32
        do j = lbound(dkca%state, 1), ubound(dkca%state, 1)
            left = dkca%state(dkca%periodic_index(j - 1))
            right = dkca%state(dkca%periodic_index(j + 1))

            if (left == 0 .and. right == 0) then
                probability = 0.0
            else if (left == 1 .and. right == 1) then
                probability = q
            else
                probability = p
            end if

            call random_number(random_value)
            dkca%next_state(j) = (random_value < probability ? 1_int32 : 0_int32)
            next_active_count = next_active_count + dkca%next_state(j)
        end do

        dkca%state = dkca%next_state
        if (present(active_count)) active_count = next_active_count
    end subroutine step

    function current_active_count(dkca) result(active_count)
        class(DKCA_t), intent(in) :: dkca
        integer(kind=int32) :: active_count

        active_count = sum(dkca%state)
    end function current_active_count

    function periodic_index(dkca, index) result(wrapped_index)
        class(DKCA_t), intent(in) :: dkca
        integer(kind=int32), intent(in) :: index
        integer(kind=int32) :: wrapped_index
        integer(kind=int32) :: first, n

        first = lbound(dkca%state, 1)
        n = int(size(dkca%state), kind=int32)
        wrapped_index = first + modulo(index - first, n)
    end function periodic_index

end module model
