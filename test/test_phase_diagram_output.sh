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

"$simulator" 5 3 1 5 1 --cut-p-below-half
awk '
    !/^#/ && NF {
        rows++
        if ($1 < 0.5) exit 1
        if ($1 == 1 && $3 != 2) exit 1
    }
    END { if (rows != 9) exit 1 }
' phase_diagram.dat

OMP_NUM_THREADS=1 "$simulator" 5 3 12 31 4 --seed 42
grep -qx '# seed: 42' phase_diagram.dat
grep -qx '# seed: 42' time_evolution.dat
cp phase_diagram.dat phase_diagram.seeded.dat
cp time_evolution.dat time_evolution.seeded.dat
OMP_NUM_THREADS=4 "$simulator" 5 3 12 31 4 --seed 42
cmp phase_diagram.seeded.dat phase_diagram.dat
cmp time_evolution.seeded.dat time_evolution.dat

"$simulator" 5 3 1 5 1
awk '
    !/^#/ && NF {
        rows++
        if ($1 == 0) {
            extinct++
            if ($3 != 0) exit 1
        }
    }
    END { if (rows != 15 || extinct != 3) exit 1 }
' phase_diagram.dat
