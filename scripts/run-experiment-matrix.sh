#!/bin/sh
# Run a factorial set of DKCA experiments. Override the space-separated lists
# below through the environment to narrow or extend the matrix.
set -eu

SWEEP_SIZES=${SWEEP_SIZES:-'21 41'}
STEP_COUNTS=${STEP_COUNTS:-'100 200'}
GRID_SIZES=${GRID_SIZES:-'201 400 801'}
TRIAL_COUNTS=${TRIAL_COUNTS:-'20 100'}
CUT_MODES=${CUT_MODES:-'false true'}
SEEDS=${SEEDS:-'42 43'}
OUTPUT_ROOT=${OUTPUT_ROOT:-experiments/matrix}
FPM=${FPM:-fpm}
MAKE=${MAKE:-make}
GNUPLOT=${GNUPLOT:-gnuplot}

usage() {
    cat <<'EOF'
Usage: scripts/run-experiment-matrix.sh [--list]

By default, run every combination and resume completed cases. --list prints
the cases without running them. Set OUTPUT_ROOT to select the destination.
Override SWEEP_SIZES, STEP_COUNTS, GRID_SIZES, TRIAL_COUNTS, CUT_MODES, and
SEEDS with space-separated values. A sweep size N samples both p and q at
N points from 0 to 1. Each case runs make experiment and generates seven PNGs.

Example single-case run:
  SWEEP_SIZES=21 STEP_COUNTS=100 GRID_SIZES=201 TRIAL_COUNTS=20 \
    CUT_MODES=false SEEDS=42 OUTPUT_ROOT=experiments/single \
    scripts/run-experiment-matrix.sh
EOF
}

list_only=false
case ${1:-} in
    '') ;;
    --list) list_only=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then usage >&2; exit 2; fi

positive_int() {
    case $2 in
        ''|*[!0-9]*|0) printf '%s must contain positive integers: %s\n' "$1" "$2" >&2; exit 2 ;;
    esac
}
nonnegative_int() {
    case $2 in
        ''|*[!0-9]*) printf '%s must contain nonnegative integers: %s\n' "$1" "$2" >&2; exit 2 ;;
    esac
}

for value in $SWEEP_SIZES; do positive_int SWEEP_SIZES "$value"; done
for value in $STEP_COUNTS; do nonnegative_int STEP_COUNTS "$value"; done
for value in $GRID_SIZES; do positive_int GRID_SIZES "$value"; done
for value in $TRIAL_COUNTS; do positive_int TRIAL_COUNTS "$value"; done
for value in $SEEDS; do nonnegative_int SEEDS "$value"; done
for value in $CUT_MODES; do
    case $value in true|false) ;; *) echo "CUT_MODES must contain true or false: $value" >&2; exit 2 ;; esac
done

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case $OUTPUT_ROOT in
    /*) output_root=$OUTPUT_ROOT ;;
    *) output_root=$project_dir/$OUTPUT_ROOT ;;
esac

case_count=0
for sweep in $SWEEP_SIZES; do
    for steps in $STEP_COUNTS; do
        for grid in $GRID_SIZES; do
            for trials in $TRIAL_COUNTS; do
                for cut in $CUT_MODES; do
                    for seed in $SEEDS; do
                        id="p${sweep}_q${sweep}_t${steps}_l${grid}_n${trials}_cut${cut}_seed${seed}"
                        case_count=$((case_count + 1))
                        if [ "$list_only" = true ]; then printf '%s\n' "$id"; fi
                    done
                done
            done
        done
    done
done
if [ "$list_only" = true ]; then
    printf 'Total: %s cases\n' "$case_count" >&2
    exit 0
fi

command -v "$FPM" >/dev/null 2>&1 || { echo "fpm not found: $FPM" >&2; exit 1; }
command -v "$MAKE" >/dev/null 2>&1 || { echo "make not found: $MAKE" >&2; exit 1; }
command -v "$GNUPLOT" >/dev/null 2>&1 || { echo "gnuplot not found: $GNUPLOT" >&2; exit 1; }
mkdir -p "$output_root"
output_root=$(CDPATH= cd -- "$output_root" && pwd)
cd "$project_dir"

case_complete() {
    case_dir=$1
    [ -f "$case_dir/summary.txt" ] || return 1
    grep -qx 'status: complete' "$case_dir/summary.txt" || return 1
    grep -qx "seed: $seed" "$case_dir/summary.txt" || return 1
    for file in phase_diagram.dat time_evolution.dat \
        phase_diagram.png phase_diagram_3d.png phase_diagram_contours.png \
        phase_diagram_loglog.png phase_boundary_fit.png time_evolution.png \
        time_evolution_comparison.png fitted_boundary.dat; do
        [ -s "$case_dir/$file" ] || return 1
    done
}

# Recreate the index on each invocation. Case directories remain untouched.
index_tmp=$output_root/cases.tsv.tmp
printf 'case_id\tp_steps\tq_steps\tmax_steps\tgrid_size\tsimulation_count\tcut_p_below_half\tseed\tpath\n' > "$index_tmp"
for sweep in $SWEEP_SIZES; do
    for steps in $STEP_COUNTS; do
        for grid in $GRID_SIZES; do
            for trials in $TRIAL_COUNTS; do
                for cut in $CUT_MODES; do
                    for seed in $SEEDS; do
                        id="p${sweep}_q${sweep}_t${steps}_l${grid}_n${trials}_cut${cut}_seed${seed}"
                        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                            "$id" "$sweep" "$sweep" "$steps" "$grid" "$trials" "$cut" "$seed" "$output_root/$id" >> "$index_tmp"
                    done
                done
            done
        done
    done
done
mv "$index_tmp" "$output_root/cases.tsv"

case_number=0
for sweep in $SWEEP_SIZES; do
    for steps in $STEP_COUNTS; do
        for grid in $GRID_SIZES; do
            for trials in $TRIAL_COUNTS; do
                for cut in $CUT_MODES; do
                    for seed in $SEEDS; do
                        case_number=$((case_number + 1))
                        id="p${sweep}_q${sweep}_t${steps}_l${grid}_n${trials}_cut${cut}_seed${seed}"
                        case_dir=$output_root/$id
                        if case_complete "$case_dir"; then
                            printf '[%s/%s] skip %s\n' "$case_number" "$case_count" "$id"
                            continue
                        fi
                        mkdir -p "$case_dir"
                        printf '[%s/%s] run %s\n' "$case_number" "$case_count" "$id"
                        if ! "$MAKE" experiment FPM="$FPM" GNUPLOT="$GNUPLOT" \
                            p_steps="$sweep" q_steps="$sweep" max_steps="$steps" \
                            grid_size="$grid" simulation_count="$trials" \
                            cut_p_below_half="$cut" seed="$seed" \
                            output_dir="$case_dir" > "$case_dir/run.log" 2>&1; then
                            printf 'Failed: %s (see %s/run.log)\n' "$id" "$case_dir" >&2
                            exit 1
                        fi
                        if ! case_complete "$case_dir"; then
                            printf 'Missing outputs: %s (see run.log)\n' "$case_dir" >&2
                            exit 1
                        fi
                    done
                done
            done
        done
    done
done
printf 'Completed %s cases in %s\n' "$case_count" "$output_root"
