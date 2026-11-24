"""Extract the k=50 mean-mu heatmap data for the current experiment directory."""

from math import isfinite, sqrt
from pathlib import Path


HERE = Path.cwd()
SNAPSHOT_STEP = 50
MIN_SURVIVOR_FRACTION = 0.5

summary = dict(
    line.split(": ", 1)
    for line in (HERE / "summary.txt").read_text().splitlines()
    if ": " in line
)
trial_count = int(summary["simulation_count"])
grid_size = int(summary["grid_size"])
assert SNAPSHOT_STEP <= int(summary["max_steps"])
assert SNAPSHOT_STEP < (grid_size + 1) // 2, "The active region wraps around at this step"

values = []
with (HERE / "time_evolution.dat").open() as source:
    for line in source:
        if line.startswith("#"):
            continue
        columns = line.split()
        if len(columns) < 6 or int(columns[2]) != SNAPSHOT_STEP:
            continue
        p, q = float(columns[0]), float(columns[1])
        survivors, mu = int(columns[4]), float(columns[5])
        if survivors < MIN_SURVIVOR_FRACTION * trial_count or not isfinite(mu):
            mu = float("nan")
        values.append((p, q, mu))

assert values, "No parameter points were found at the requested step"
defined = [mu for _, _, mu in values if isfinite(mu)]
assert defined, "No mean-mu values meet the survival threshold"

with (HERE / "mean_mu_k50.dat").open("w") as output:
    output.write("# p q mean_mu; NaN means <50% survivors or undefined\n")
    last_q = None
    for p, q, mu in values:
        if last_q is not None and q != last_q:
            output.write("\n")
        output.write(f"{p:.16e} {q:.16e} {mu:.16e}\n")
        last_q = q

statistics = [
    f"snapshot_step: {SNAPSHOT_STEP}",
    f"grid_size: {grid_size}",
    f"simulation_count: {trial_count}",
    f"seed: {summary['seed']}",
    f"minimum_survivor_fraction: {MIN_SURVIVOR_FRACTION}",
    f"defined_parameter_points: {len(defined)}",
    f"mean_mu: {sum(defined) / len(defined):.16e}",
    f"rms_mu: {sqrt(sum(mu * mu for mu in defined) / len(defined)):.16e}",
    f"max_abs_mu: {max(abs(mu) for mu in defined):.16e}",
]
(HERE / "mean_mu_k50_stats.txt").write_text("\n".join(statistics) + "\n")
