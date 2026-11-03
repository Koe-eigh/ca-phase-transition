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
grep -qx '# grid_size: 31' phase_diagram.dat
grep -qx '# final_step: 12' phase_diagram.dat
grep -qx '# reachable_sites: 13' phase_diagram.dat
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

# At k=200, a deterministic p=q=1 cone occupies 201 sites on both rings.
# Dividing by L would give different values; reachable-site normalization is 1.
for grid_size in 500 800; do
    "$simulator" 2 2 200 "$grid_size" 1 --seed 42
    grep -qx '# reachable_sites: 201' phase_diagram.dat
    awk '
        !/^#/ && NF && $1 == 1 && $2 == 1 {
            if (NF != 4 || $3 != 201 || $4 != 1) exit 1
            found = 1
        }
        END { if (!found) exit 1 }
    ' phase_diagram.dat
done

# On an even four-site ring, only two same-parity sites are reachable at k=4.
"$simulator" 2 2 4 4 1 --seed 42
grep -qx '# reachable_sites: 2' phase_diagram.dat
awk '!/^#/ && NF && $1 == 1 && $2 == 1 { if ($3 != 2 || $4 != 1) exit 1; found = 1 }
     END { if (!found) exit 1 }' phase_diagram.dat

# On an odd five-site ring, the step-two sequence eventually visits all sites.
"$simulator" 2 2 4 5 1 --seed 42
grep -qx '# reachable_sites: 5' phase_diagram.dat
awk '!/^#/ && NF && $1 == 1 && $2 == 1 { if ($3 != 5 || $4 != 1) exit 1; found = 1 }
     END { if (!found) exit 1 }' phase_diagram.dat
