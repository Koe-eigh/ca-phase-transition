#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -r "$work_dir"' 0
cp "$project_dir/experiments/2026-11-02_21x21_200steps_100runs/phase_diagram.dat" "$work_dir/"
cd "$work_dir"

gnuplot "$project_dir/phase_boundary_fit.gp" > fit-output.txt 2>&1
grep -Eq '^Fitting contour component [0-9]+ \(26 points\)$' fit-output.txt
awk '
    /#datapoints =/ { if ($3 != 26) exit 1; found = 1 }
    END { if (!found) exit 1 }
' fit.log
awk '
    $1 == "a" && $2 == "=" {
        if ($3 < -13.822 || $3 > -13.802) exit 1
        found = 1
    }
    END { if (!found) exit 1 }
' fit.log
test -s phase_boundary_fit.png
test -s fitted_boundary.dat
awk '
    $3 == "i" && !found {
        expected = 0.55 + 0.05 * (10 - 7.45) / (21.8 - 7.45)
        if ($1 < expected - 0.000001 || $1 > expected + 0.000001 || $2 != 1) exit 1
        found = 1
    }
    END { if (!found) exit 1 }
' fitted_boundary.dat
