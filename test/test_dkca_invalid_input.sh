#!/bin/sh
set -eu
ulimit -c 0

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -r "$work_dir"' 0

cat > "$work_dir/invalid_input.f90" <<'EOF'
program invalid_input
    use, intrinsic :: iso_fortran_env, only: int8, real64
    use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, &
                                            ieee_positive_inf, ieee_negative_inf
    use dkca, only: DKCA_t, new_DKCA
    implicit none
    type(DKCA_t) :: automaton
    character(len=32) :: input_case
    real(real64) :: p, q, observed

    call get_command_argument(1, input_case)
    select case (trim(input_case))
    case ('empty')
        automaton = new_DKCA(initial_state=[integer(int8) :: ])
    case ('negative_state')
        automaton = new_DKCA(initial_state=[-1_int8, 0_int8])
    case ('state_above_one')
        automaton = new_DKCA(initial_state=[1_int8, 2_int8])
    case ('max_int8_state')
        automaton = new_DKCA(initial_state=[127_int8])
    case ('min_int8_state')
        automaton = new_DKCA(initial_state=[int(-128, int8)])
    case ('empty_center')
        automaton = new_DKCA(initial_state=[0_int8])
        observed = automaton%current_center_of_mass()
    case ('empty_variance')
        automaton = new_DKCA(initial_state=[0_int8])
        observed = automaton%current_variance()
    case ('extinct_center')
        automaton = new_DKCA(initial_state=[1_int8])
        observed = automaton%current_center_of_mass()
        call automaton%step(0.0_real64, 0.0_real64)
        observed = automaton%current_center_of_mass()
    case ('extinct_variance')
        automaton = new_DKCA(initial_state=[1_int8])
        observed = automaton%current_variance()
        call automaton%step(0.0_real64, 0.0_real64)
        observed = automaton%current_variance()
    case default
        automaton = new_DKCA(initial_state=[1_int8])
        p = 0.5_real64
        q = 0.5_real64
        select case (trim(input_case))
        case ('negative_p')
            p = -0.1_real64
        case ('large_p')
            p = 1.1_real64
        case ('nan_p')
            p = ieee_value(0.0_real64, ieee_quiet_nan)
        case ('positive_inf_p')
            p = ieee_value(0.0_real64, ieee_positive_inf)
        case ('negative_inf_p')
            p = ieee_value(0.0_real64, ieee_negative_inf)
        case ('negative_q')
            q = -0.1_real64
        case ('large_q')
            q = 1.1_real64
        case ('nan_q')
            q = ieee_value(0.0_real64, ieee_quiet_nan)
        case ('positive_inf_q')
            q = ieee_value(0.0_real64, ieee_positive_inf)
        case ('negative_inf_q')
            q = ieee_value(0.0_real64, ieee_negative_inf)
        case default
            error stop 'Unknown test case'
        end select
        call automaton%step(p, q)
    end select
end program invalid_input
EOF

(cd "$work_dir" && gfortran -std=f2018 -J "$work_dir" -I "$work_dir" \
    "$project_dir/src/random_hash.f90" "$project_dir/src/dkca.f90" \
    invalid_input.f90 -o invalid_input)

check_rejected() {
    if "$work_dir/invalid_input" "$1" > "$work_dir/output" 2>&1; then
        echo "Accepted invalid input: $1" >&2
        exit 1
    fi
    if ! grep -Fq "$2" "$work_dir/output"; then
        echo "Unexpected failure for $1:" >&2
        cat "$work_dir/output" >&2
        exit 1
    fi
}

check_rejected empty 'Initial state must be nonempty'
check_rejected negative_state 'Initial state must contain only 0 and 1'
check_rejected state_above_one 'Initial state must contain only 0 and 1'
check_rejected max_int8_state 'Initial state must contain only 0 and 1'
check_rejected min_int8_state 'Initial state must contain only 0 and 1'
check_rejected empty_center 'Center of mass requires active sites'
check_rejected empty_variance 'Variance requires active sites'
check_rejected extinct_center 'Center of mass requires active sites'
check_rejected extinct_variance 'Variance requires active sites'
for input_case in negative_p large_p negative_q large_q; do
    check_rejected "$input_case" 'Probabilities p and q must be in [0, 1]'
done
for input_case in nan_p positive_inf_p negative_inf_p nan_q positive_inf_q negative_inf_q; do
    check_rejected "$input_case" 'Probabilities p and q must be finite'
done
