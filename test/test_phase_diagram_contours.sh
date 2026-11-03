#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT

cp "$project_dir/experiments/2026-11-02_21x21_200steps_100runs/phase_diagram.dat" "$work_dir/"
python3 - "$project_dir/phase_diagram_contours.gp" "$work_dir/render_svg.gp" <<'PY'
from pathlib import Path
import sys

lines = Path(sys.argv[1]).read_text().splitlines()
lines[:2] = ["set terminal svg size 1000,800", "set output 'phase_diagram_contours.svg'"]
Path(sys.argv[2]).write_text("\n".join(lines) + "\n")
PY

(cd "$work_dir" && gnuplot render_svg.gp)

python3 - "$work_dir/phase_diagram_contours.svg" <<'PY'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

root = ET.parse(Path(sys.argv[1])).getroot()
plots = [element for element in root.iter() if element.get("id", "").startswith("gnuplot_plot_")]
contours = [plot for plot in plots if any(
    path.get("stroke") == "rgb(255, 255, 255)"
    for path in plot.iter() if path.tag.endswith("path")
)]
assert len(contours) == 1, "expected one white contour plot"
paths = [path for path in contours[0].iter() if path.tag.endswith("path")]
assert paths and all(path.get("stroke") == "rgb(255, 255, 255)" for path in paths), \
    "contour levels must all use white strokes"

label_plots = [plot for plot in plots if any(
    element.tag.endswith("tspan") and element.text == "0.1" for element in plot.iter()
)]
assert len(label_plots) == 1, "expected one contour label plot"
text_groups = [element for element in label_plots[0].iter() if element.tag.endswith("g")
               and any(child.tag.endswith("text") for child in element)]
assert text_groups and all(group.get("fill") == "rgb(255,255,255)" for group in text_groups), \
    "contour labels must use white text"
labels = {element.text for element in label_plots[0].iter()
          if element.tag.endswith("tspan") and element.text}
assert {"0.1", "0.2", "0.3", "0.4", "0.5"} <= labels, \
    "major contour values must appear on the plot"
PY
