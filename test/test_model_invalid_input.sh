#!/bin/sh
set -eu
ulimit -c 0

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -r "$work_dir"' 0

cat > "$work_dir/invalid_input.f90" <<'EOF'
program invalid_input
    use, intrinsic :: iso_fortran_env, only: int32, real64
    use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, &
                                            ieee_positive_inf, ieee_negative_inf
    use model, only: DKCA_t, DKCA
    implicit none
    type(DKCA_t) :: automaton
    character(len=32) :: input_case
    real(real64) :: p, q

    call get_command_argument(1, input_case)
    select case (trim(input_case))
    case ('empty')
        automaton = DKCA([integer(int32) :: ])
    case ('negative_state')
        automaton = DKCA([-1_int32, 0_int32])
    case ('state_above_one')
        automaton = DKCA([1_int32, 2_int32])
    case default
        automaton = DKCA([1_int32])
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
    "$project_dir/src/model.f90" invalid_input.f90 -o invalid_input)

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
for input_case in negative_p large_p negative_q large_q; do
    check_rejected "$input_case" 'Probabilities p and q must be in [0, 1]'
done
for input_case in nan_p positive_inf_p negative_inf_p nan_q positive_inf_q negative_inf_q; do
    check_rejected "$input_case" 'Probabilities p and q must be finite'
done
