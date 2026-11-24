module dkca
    use, intrinsic :: iso_fortran_env, only: int32, int64, real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_is_nan, ieee_value, ieee_quiet_nan
    use random_hash, only: mix_hash, HASH_MODULUS
    implicit none
    private

    public :: DKCA_t, new_DKCA

    type :: DKCA_t
        integer(kind=int32), allocatable :: state(:)
        integer(kind=int32), allocatable :: initial_state(:)
        integer(kind=int32), allocatable :: next_state(:)
        integer(kind=int32) :: time_step = 0_int32
        integer(kind=int64) :: seed = 1_int64
        integer(kind=int32), private :: active_count
        real(real64), private :: cached_center_of_mass, cached_variance
    contains
        procedure :: reset
        procedure :: set_seed
        procedure :: step
        procedure :: current_active_count
        procedure :: current_center_of_mass
        procedure :: current_variance
        procedure, private :: clear_cache
        procedure, private :: periodic_index
    end type DKCA_t

    interface new_DKCA
        module procedure init
    end interface new_DKCA
contains
    function init(initial_state, first_index) result(dkca)
        integer(kind=int32), intent(in) :: initial_state(:)
        integer(kind=int32), intent(in), optional :: first_index
        type(DKCA_t) :: dkca
        integer(kind=int32) :: first

        if (size(initial_state) == 0) error stop 'Initial state must be nonempty'
        if (any(initial_state /= 0_int32 .and. initial_state /= 1_int32)) &
            error stop 'Initial state must contain only 0 and 1'

        first = 1_int32
        if (present(first_index)) first = first_index
        allocate(dkca%state(first:first + size(initial_state) - 1))
        allocate(dkca%initial_state(first:first + size(initial_state) - 1))
        allocate(dkca%next_state(first:first + size(initial_state) - 1))
        dkca%state = initial_state
        dkca%initial_state = initial_state
        dkca%time_step = 0_int32
        dkca%active_count = sum(initial_state)
        call dkca%clear_cache()
    end function init

    subroutine reset(dkca)
        class(DKCA_t), intent(inout) :: dkca

        dkca%state = dkca%initial_state
        dkca%time_step = 0_int32
        dkca%active_count = sum(dkca%initial_state)
        call dkca%clear_cache()
    end subroutine reset

    subroutine set_seed(dkca, seed)
        class(DKCA_t), intent(inout) :: dkca
        integer(kind=int64), intent(in) :: seed

        dkca%seed = seed
    end subroutine set_seed

    function random_value(step_seed, site) result(value)
        integer(kind=int64), intent(in) :: step_seed
        integer(kind=int32), intent(in) :: site
        real(real64) :: value
        integer(kind=int64) :: hash_value

        ! The same site and step give the same value on different
        ! grid sizes until their physical evolution diverges at a boundary.
        hash_value = mix_hash(step_seed, int(site, int64))
        value = real(hash_value, real64) / real(HASH_MODULUS, real64)
    end function random_value

    subroutine step(dkca, p, q)
        class(DKCA_t), intent(inout) :: dkca
        real(real64), intent(in) :: p, q

        integer(kind=int32) :: site, left, right, next_active_count
        integer(kind=int64) :: step_seed
        real(real64) :: probability, sample

        if (.not. ieee_is_finite(p) .or. .not. ieee_is_finite(q)) &
            error stop 'Probabilities p and q must be finite'
        if (p < 0.0_real64 .or. p > 1.0_real64 .or. &
            q < 0.0_real64 .or. q > 1.0_real64) &
            error stop 'Probabilities p and q must be in [0, 1]'

        next_active_count = 0_int32
        step_seed = mix_hash(dkca%seed, int(dkca%time_step, int64) + 1_int64)
        do site = lbound(dkca%state, 1), ubound(dkca%state, 1)
            left = dkca%state(dkca%periodic_index(site - 1))
            right = dkca%state(dkca%periodic_index(site + 1))

            if (left == 0 .and. right == 0) then
                probability = 0.0_real64
            else if (left == 1 .and. right == 1) then
                probability = q
            else
                probability = p
            end if

            sample = random_value(step_seed, site)
            if (sample < probability) then
                dkca%next_state(site) = 1_int32
            else
                dkca%next_state(site) = 0_int32
            end if
            next_active_count = next_active_count + dkca%next_state(site)
        end do

        dkca%state = dkca%next_state
        dkca%time_step = dkca%time_step + 1_int32
        dkca%active_count = next_active_count
        call dkca%clear_cache()
    end subroutine step

    function current_active_count(dkca) result(active_count)
        class(DKCA_t), intent(in) :: dkca
        integer(kind=int32) :: active_count

        active_count = dkca%active_count
    end function current_active_count

    function current_center_of_mass(dkca) result(center_of_mass)
        class(DKCA_t), intent(inout) :: dkca
        real(real64) :: center_of_mass
        integer(kind=int32) :: j

        if (.not. ieee_is_nan(dkca%cached_center_of_mass)) then
            center_of_mass = dkca%cached_center_of_mass
            return
        end if
        if (dkca%active_count == 0_int32) error stop 'Center of mass requires active sites'
        center_of_mass = 0.0_real64
        do j = lbound(dkca%state, 1), ubound(dkca%state, 1)
            if (dkca%state(j) == 0_int32) cycle
            center_of_mass = center_of_mass + real(j, real64)
        end do
        center_of_mass = center_of_mass / real(dkca%active_count, real64)
        dkca%cached_center_of_mass = center_of_mass
    end function current_center_of_mass

    function current_variance(dkca) result(variance)
        class(DKCA_t), intent(inout) :: dkca
        real(real64) :: variance, mu
        integer(kind=int32) :: j

        if (.not. ieee_is_nan(dkca%cached_variance)) then
            variance = dkca%cached_variance
            return
        end if
        mu = dkca%current_center_of_mass()
        variance = 0.0_real64
        do j = lbound(dkca%state, 1), ubound(dkca%state, 1)
            if (dkca%state(j) == 0_int32) cycle
            variance = variance + (real(j, real64) - mu)**2
        end do
        variance = variance / real(dkca%active_count, real64)
        dkca%cached_variance = variance
    end function current_variance

    subroutine clear_cache(dkca)
        class(DKCA_t), intent(inout) :: dkca

        ! Coordinates are integers, so these computed values are always finite.
        dkca%cached_center_of_mass = ieee_value(0.0_real64, ieee_quiet_nan)
        dkca%cached_variance = ieee_value(0.0_real64, ieee_quiet_nan)
    end subroutine clear_cache

    function periodic_index(dkca, index) result(wrapped_index)
        class(DKCA_t), intent(in) :: dkca
        integer(kind=int32), intent(in) :: index
        integer(kind=int32) :: wrapped_index
        integer(kind=int32) :: first, n

        first = lbound(dkca%state, 1)
        n = int(size(dkca%state), kind=int32)
        wrapped_index = first + modulo(index - first, n)
    end function periodic_index

end module dkca
