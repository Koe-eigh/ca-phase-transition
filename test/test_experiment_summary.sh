#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -r "$work_dir"' 0
(cd "$project_dir" && fpm build --build-dir "$work_dir/build")
set -- "$work_dir"/build/gfortran_*/app/ca-phase-transition
[ -x "$1" ]
simulator=$1
cd "$work_dir"

OMP_NUM_THREADS=2 "$simulator" 5 3 2 7 2 --seed 42 --cut-p-below-half
[ -f phase_diagram.dat ]
[ -f time_evolution.dat ]
grep -qx 'p_steps: 5' summary.txt
grep -qx 'q_steps: 3' summary.txt
grep -qx 'max_steps: 2' summary.txt
grep -qx 'grid_size: 7' summary.txt
grep -qx 'simulation_count: 2' summary.txt
grep -qx 'cut_p_below_half: T' summary.txt
grep -qx 'seed: 42' summary.txt
grep -qx 'completed_patterns: 9' summary.txt
grep -qx 'files: phase_diagram.dat, time_evolution.dat, summary.txt' summary.txt
grep -qx 'status: complete' summary.txt
awk -F': ' '/^elapsed_seconds:/ { if ($2 < 0) exit 1; found = 1 } END { if (!found) exit 1 }' summary.txt
awk '
    NR == FNR {
        if ($1 == "final_mean_active_count_min:") { minimum = $2 + 0; found_min = 1 }
        if ($1 == "final_mean_active_count_max:") { maximum = $2 + 0; found_max = 1 }
        next
    }
    !/^#/ && NF {
        if (!rows++ || $3 < data_min) data_min = $3
        if (rows == 1 || $3 > data_max) data_max = $3
    }
    END { if (rows != 9 || !found_min || !found_max || minimum != data_min || maximum != data_max) exit 1 }
' summary.txt phase_diagram.dat

"$simulator" 1 2 1 5 1 --seed 7 --cut-p-below-half
grep -qx 'completed_patterns: 0' summary.txt
grep -qx 'final_mean_active_count_min: n/a (no patterns calculated)' summary.txt
grep -qx 'final_mean_active_count_max: n/a (no patterns calculated)' summary.txt

if "$simulator" 0 2 1 5 1 --seed 7 >/dev/null 2>&1; then
    exit 1
fi
[ ! -e summary.txt ]
