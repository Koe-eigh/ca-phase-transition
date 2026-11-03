# Cellular Automaton Simulation And Phase Transition

A study to observe a phase transition in the simple **Domany-Kinzel cellular automaton(DKCA)**[\[1\]](https://github.com/Koe-eigh/ca-phase-transition#reference) model.

## The Idea

Considering one-dimensional space with discrete grid points and the grid point at position $j$ and time step $k$ has the value $\eta(j;k)$ which is 0 or 1. The $\eta(j;k)$ follows the time evolution equation given below.

```math

P\left(
\eta(j;k)=1
\mid
\eta(j-1;k-1),\eta(j+1;k-1)
\right)
=
\begin{cases}
0,   & (\eta(j-1;k-1),\eta(j+1;k-1))=(0,0),\\
p, & (\eta(j-1;k-1),\eta(j+1;k-1))=(1,0),\\
p, & (\eta(j-1;k-1),\eta(j+1;k-1))=(0,1),\\
q, & (\eta(j-1;k-1),\eta(j+1;k-1))=(1,1).
\end{cases}

```
Here, $p$ and $q$ are the probabilities that the site becomes active for the
mixed-neighbor and two-active-neighbor cases, respectively. The probability
that $\eta(j;k)=0$ is given by the complementary probability.

Depending on $p$ and $q$, the total number of active sites,

$$
N(k) = \sum_j \eta(j;k),
$$

is expected to exhibit three qualitatively different behaviors: explosion, stagnation, or extinction. In this study, I will run simulations for different values of $p$ and $q$ and investigate the resulting phase diagram in the $p$ - $q$ parameter space.

## Usage

The one-command experiment workflow requires `fpm` and `gnuplot` on `PATH`.
Run it from the repository root to build the release executable, simulate,
and generate all seven figures:

```sh
make experiment
```

Results are written to `experiments/latest/` by default. Set the simulation
parameters, optional cut, and destination with Make variables:

```sh
make experiment p_steps=21 q_steps=21 max_steps=200 grid_size=200 \
  simulation_count=10 cut_p_below_half=true output_dir=experiments/my-run
```

`cut_p_below_half` accepts `true` or `false` (the default). The output directory
contains `phase_diagram.dat`, `time_evolution.dat`, `summary.txt`, all seven
`.png` figures, and `fitted_boundary.dat`. The plotting scripts use fixed
parameter pairs and require enough sampled points for the boundary fit. The
Make defaults use a 21-by-21 sweep with 10 trials per pair; smaller or noisier
sweeps may fail during plotting.

The source supports Fortran 2018. For example, use
`fpm test --flag '-std=f2018 -fopenmp'` to check the language standard with
GNU Fortran.

Build and run the simulation with the default settings:

```sh
fpm run
```

The simulation uses OpenMP to run independent `(p, q)` parameter combinations
in parallel. The number of workers is selected dynamically from the number of
combinations actually calculated and `OMP_NUM_THREADS` (or the system OpenMP
default when `OMP_NUM_THREADS` is not set), so small parameter sweeps do not
create unused threads. Progress is printed to standard output from 0% to 100%
as combinations finish, at approximately 1% intervals. For example:

```sh
OMP_NUM_THREADS=8 fpm run --profile release
```

The simulation parameters can be supplied as positional command-line arguments in
the order `p_steps q_steps max_steps grid_size simulation_count`:

```sh
fpm run --profile release -- 21 21 200 200 10
```

Pass `--seed` with a signed 64-bit integer to reproduce a run:

```sh
OMP_NUM_THREADS=4 fpm run --profile release -- 21 21 200 200 10 --seed 42
```

Without `--seed`, a seed is taken from the system clock. The effective seed is
printed at startup and recorded in a `# seed: N` comment at the top of both
output files. Reuse it with the same executable and simulation parameters to
reproduce the results. Each parameter-index pair and trial has its own random
draws, so changing `OMP_NUM_THREADS` preserves the results, including the order
of data rows. Matching parameter indices, trial, time, and site coordinates
also receive the same random draw on different grid sizes before periodic
boundary effects occur. The random generator is implemented in this project;
results may change if it or the simulation algorithm changes in a later version.

`simulation_count` controls how many independent simulations are averaged for
each `(p, q)` combination. If it is omitted, one simulation is run.
If no arguments are supplied, the default values above are used.

Each successful run writes `phase_diagram.dat`, `time_evolution.dat`, and
`summary.txt` in the current directory. The summary is written after the data
files are complete. It records the run settings, effective seed, number of
calculated `(p, q)` combinations, elapsed time in seconds, output filenames,
and the minimum and maximum final-step mean active counts over calculated
combinations. When the cut excludes every combination, the range is marked
`n/a`. A new run removes any previous summary before starting, so a failed
run does not leave an older success summary in place.

`phase_diagram.dat` has columns `p q active_count active_fraction`.
It retains the final-time mean active count over all trials and records
`grid_size`, `final_step`, and `reachable_sites` in comment headers. With one
initial active site on a periodic ring of size `L`, the number of sites
reachable at step `k` is `min(k+1, L/2)` for even `L` and `min(k+1, L)` for odd
`L`. The dimensionless `active_fraction = active_count / reachable_sites` lies
between 0 and 1. It compares activity within the step's reachable set: for
example, at `k=200`, `p=q=1` gives count 201 and fraction 1 on both 500 and
800 site rings. Once the reachable set wraps around a ring, physical finite
size effects can still change the dynamics; normalization does not remove
those effects. The phase plots use the fraction and a fixed 0–1 color scale.

`time_evolution.dat` has one row per `(p, q, k)`, including `k=0`,
with columns:

```text
p q k mean_N survivor_count mean_mu mean_mu2 variance_mu mean_sigma2
```

For each trial with active sites, `mu` is the mean site coordinate and `sigma2`
is the mean squared distance from `mu`. The coordinates are centered on the
initial active site (`j=0`). `mean_mu`, `mean_mu2`, and `mean_sigma2` average
over surviving trials at that time step; `variance_mu = mean_mu2 - mean_mu^2`.
`mean_N` averages over all trials, including extinct ones. When no trial
survives, the four moment columns are `NaN` and `survivor_count` is zero.
Spatial moments use coordinates centered on the initial seed only while its
possible activity cone has not wrapped around the periodic grid. From time
step `ceil(grid_size / 2)` onward, the four moment columns are `NaN`, even
when trials survive; `mean_N` and `survivor_count` remain available. This
conservative cutoff avoids interpreting fixed array coordinates as distances
on an unbounded lattice after periodic wraparound.

To plot `mean_mu2` and `mean_sigma2` against time for one parameter pair, run:

```sh
gnuplot -e "p_target=0.8; q_target=0.5" time_evolution.gp
```

This writes `time_evolution.png`. Choose values present in `time_evolution.dat`.

To compare several parameter pairs in one two-panel figure, run
`gnuplot time_evolution_comparison.gp`. It writes
`time_evolution_comparison.png`; edit the `p_targets` and `q_targets` arrays in
the script to choose other pairs.

To fit the observed level-0.1 active-fraction contour in `phase_diagram.dat`, run
`gnuplot phase_boundary_fit.gp`. The script writes `phase_boundary_fit.png` and
`fitted_boundary.dat`. It anchors the quadratic curve at the contour's
interpolated intersection with `q=1` and fits its curvature to the longest
contour branch. The endpoint depends on the chosen level and finite simulation
time; it is not an estimate of the theoretical critical point `(0.5, 1)`.

To skip calculations for parameter combinations with `p < 0.5`, add the optional
flag. Skipped combinations are omitted from both data files; a zero in
`phase_diagram.dat` always represents a calculated result:

```sh
fpm run --profile release -- 21 21 200 200 10 --cut-p-below-half
```

## Reference
- [1] E. Domany and W. Kinzel, Phys. Rev. Lett. 53, 447 (1984).
