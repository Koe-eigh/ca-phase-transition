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

# Short closed contours can precede the boundary branch. Component IDs above 1
# must remain visible to stats even though the plot axes span only [0:1].
python3 - <<'PY'
import math

with open('phase_diagram.dat', 'w') as data:
    for q_index in range(101):
        q = q_index / 100
        boundary_p = 0.55 + 0.2 * math.sqrt(1 - q)
        for p_index in range(101):
            p = p_index / 100
            fraction = 0.1 + 2 * (p - boundary_p)
            for center in (0.82, 0.86, 0.90):
                fraction -= 0.4 * math.exp(
                    -((p - center) / 0.012) ** 2 - ((q - 0.05) / 0.025) ** 2
                )
            data.write(f'{p} {q} 0 {fraction}\n')
        data.write('\n')
PY
gnuplot "$project_dir/phase_boundary_fit.gp" > fit-output.txt 2>&1
grep -q '^Fitting contour component 3 (111 points)$' fit-output.txt
grep -q '^Observed level 0.1 endpoint at q=1: p=0.55$' fit-output.txt
