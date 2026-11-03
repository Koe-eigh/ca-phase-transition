module model
    use, intrinsic :: iso_fortran_env, only: int32, real64
    use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
    implicit none
    private

    public :: DKCA_t, DKCA

    type :: DKCA_t
        integer(kind=int32), allocatable :: state(:)
        integer(kind=int32), allocatable :: initial_state(:)
        integer(kind=int32), allocatable :: next_state(:)
        integer(kind=int32) :: time_step = 0_int32
    contains
        procedure :: reset
        procedure :: step
        procedure :: current_active_count
        procedure :: current_spatial_moments
        procedure :: spatial_moments_defined
        procedure, private :: periodic_index
    end type DKCA_t

    interface DKCA
        module procedure init
    end interface DKCA
contains
    function init(initial_state, first_index) result(dkca)
        integer(kind=int32), intent(in) :: initial_state(:)
        integer(kind=int32), intent(in), optional :: first_index
        type(DKCA_t) :: dkca
        integer(kind=int32) :: first

        first = 1_int32
        if (present(first_index)) first = first_index
        allocate(dkca%state(first:first + size(initial_state) - 1))
        allocate(dkca%initial_state(first:first + size(initial_state) - 1))
        allocate(dkca%next_state(first:first + size(initial_state) - 1))
        dkca%state = initial_state
        dkca%initial_state = initial_state
        dkca%time_step = 0_int32
    end function init

    subroutine reset(dkca)
        class(DKCA_t), intent(inout) :: dkca

        dkca%state = dkca%initial_state
        dkca%time_step = 0_int32
    end subroutine reset

    subroutine step(dkca, p, q, active_count)
        class(DKCA_t), intent(inout) :: dkca
        real(real64), intent(in) :: p, q
        integer(kind=int32), intent(out), optional :: active_count

        integer(kind=int32) :: j, left, right, next_active_count
        real(real64) :: probability, random_value

        next_active_count = 0_int32
        do j = lbound(dkca%state, 1), ubound(dkca%state, 1)
            left = dkca%state(dkca%periodic_index(j - 1))
            right = dkca%state(dkca%periodic_index(j + 1))

            if (left == 0 .and. right == 0) then
                probability = 0.0_real64
            else if (left == 1 .and. right == 1) then
                probability = q
            else
                probability = p
            end if

            call random_number(random_value)
            if (random_value < probability) then
                dkca%next_state(j) = 1_int32
            else
                dkca%next_state(j) = 0_int32
            end if
            next_active_count = next_active_count + dkca%next_state(j)
        end do

        dkca%state = dkca%next_state
        dkca%time_step = dkca%time_step + 1_int32
        if (present(active_count)) active_count = next_active_count
    end subroutine step

    function current_active_count(dkca) result(active_count)
        class(DKCA_t), intent(in) :: dkca
        integer(kind=int32) :: active_count

        active_count = sum(dkca%state)
    end function current_active_count

    subroutine current_spatial_moments(dkca, active_count, mu, sigma2)
        class(DKCA_t), intent(in) :: dkca
        integer(kind=int32), intent(in) :: active_count
        real(real64), intent(out) :: mu, sigma2
        integer(kind=int32) :: j

        if (active_count <= 0_int32) error stop 'Spatial moments require active sites'
        if (.not. dkca%spatial_moments_defined()) then
            mu = ieee_value(0.0_real64, ieee_quiet_nan)
            sigma2 = ieee_value(0.0_real64, ieee_quiet_nan)
            return
        end if
        mu = 0.0_real64
        do j = lbound(dkca%state, 1), ubound(dkca%state, 1)
            if (dkca%state(j) /= 0_int32) mu = mu + real(j, real64)
        end do
        mu = mu / real(active_count, real64)

        sigma2 = 0.0_real64
        do j = lbound(dkca%state, 1), ubound(dkca%state, 1)
            if (dkca%state(j) /= 0_int32) sigma2 = sigma2 + (real(j, real64) - mu)**2
        end do
        sigma2 = sigma2 / real(active_count, real64)
    end subroutine current_spatial_moments

    function spatial_moments_defined(dkca) result(defined)
        class(DKCA_t), intent(in) :: dkca
        logical :: defined

        ! A single seed can first wrap around the ring after ceil(n / 2) steps.
        defined = dkca%time_step < (size(dkca%state) + 1) / 2
    end function spatial_moments_defined

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
