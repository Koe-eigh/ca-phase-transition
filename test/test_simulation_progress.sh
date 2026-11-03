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

# With 100 patterns, every percentage must appear exactly once.
OMP_NUM_THREADS=4 "$simulator" 10 10 0 5 2 --seed 42 > full.log
awk '
    /^progress: / {
        expected = count + 0
        if ($0 != "progress: " expected "%") exit 1
        count++
    }
    END { if (count != 101) exit 1 }
' full.log

# Five p values yield only three eligible values per q row.
OMP_NUM_THREADS=4 "$simulator" 5 2 0 5 2 --seed 42 --cut-p-below-half > cut.log
awk '
    /^progress: / {
        split($2, parts, "%")
        value = parts[1] + 0
        if (count == 0 && value != 0) exit 1
        if (count > 0 && value != int(100 * count / 6)) exit 1
        count++
    }
    END { if (count != 7) exit 1 }
' cut.log

# The cutoff can exclude the only pattern; completion still reaches 100%.
OMP_NUM_THREADS=4 "$simulator" 1 1 0 5 2 --seed 42 --cut-p-below-half > empty.log
grep -qx 'progress: 0%' empty.log
grep -qx 'progress: 100%' empty.log
[ "$(grep -c '^progress: ' empty.log)" -eq 2 ]

# Progress reporting must not change results across worker counts.
OMP_NUM_THREADS=1 "$simulator" 5 3 4 9 3 --seed 42 > single.log
cp phase_diagram.dat phase_diagram.single.dat
cp time_evolution.dat time_evolution.single.dat
OMP_NUM_THREADS=4 "$simulator" 5 3 4 9 3 --seed 42 > parallel.log
cmp phase_diagram.single.dat phase_diagram.dat
cmp time_evolution.single.dat time_evolution.dat
