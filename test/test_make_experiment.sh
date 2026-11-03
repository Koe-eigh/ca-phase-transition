#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

cd "$project_dir"
make experiment output_dir="$work_dir/success" > "$work_dir/success.log" 2>&1
for file in phase_diagram.dat time_evolution.dat summary.txt \
    phase_diagram.png phase_diagram_3d.png phase_diagram_contours.png \
    phase_diagram_loglog.png phase_boundary_fit.png time_evolution.png \
    time_evolution_comparison.png fitted_boundary.dat; do
    test -s "$work_dir/success/$file"
done
grep -qx 'simulation_count: 10' "$work_dir/success/summary.txt"
grep -Fq "Experiment complete: $work_dir/success" "$work_dir/success.log"

if make experiment FPM=false output_dir="$work_dir/build-failure" > "$work_dir/build.log" 2>&1; then
    echo 'Expected fpm failure' >&2
    exit 1
fi
if make experiment p_steps=0 output_dir="$work_dir/run-failure" > "$work_dir/run.log" 2>&1; then
    echo 'Expected simulation failure' >&2
    exit 1
fi
if make experiment GNUPLOT=false output_dir="$work_dir/plot-failure" > "$work_dir/plot.log" 2>&1; then
    echo 'Expected plotting failure' >&2
    exit 1
fi
for log in build run plot; do
    if grep -q 'Experiment complete:' "$work_dir/$log.log"; then
        echo "False success message in $log.log" >&2
        exit 1
    fi
done
test ! -e "$work_dir/run-failure/summary.txt"
