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
