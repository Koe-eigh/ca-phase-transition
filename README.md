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

Build and run the simulation with the default settings:

```sh
fpm run
```

The simulation uses OpenMP to run independent `(p, q)` parameter combinations
in parallel. The number of workers is selected dynamically as
`min(p_steps * q_steps, OMP_NUM_THREADS)` (or the system OpenMP default when
`OMP_NUM_THREADS` is not set), so small parameter sweeps do not create unused
threads. For example:

```sh
OMP_NUM_THREADS=8 fpm run --profile release
```

The simulation parameters can be supplied as positional command-line arguments in
the order `p_steps q_steps max_steps grid_size simulation_count`:

```sh
fpm run --profile release -- 21 21 200 200 10
```

`simulation_count` controls how many independent simulations are averaged for
each `(p, q)` combination. If it is omitted, one simulation is run.
If no arguments are supplied, the default values above are used.

Each run writes `phase_diagram.dat` and `time_evolution.dat` in the current
directory. `time_evolution.dat` has one row per `(p, q, k)`, including `k=0`,
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

To plot `mean_mu2` and `mean_sigma2` against time for one parameter pair, run:

```sh
gnuplot -e "p_target=0.8; q_target=0.5" time_evolution.gp
```

This writes `time_evolution.png`. Choose values present in `time_evolution.dat`.

To compare several parameter pairs in one two-panel figure, run
`gnuplot time_evolution_comparison.gp`. It writes
`time_evolution_comparison.png`; edit the `p_targets` and `q_targets` arrays in
the script to choose other pairs.

To skip calculations for parameter combinations with `p < 0.5`, add the optional
flag. The skipped cells remain zero in the output:

```sh
fpm run --profile release -- 21 21 200 200 10 --cut-p-below-half
```

## Reference
- [1] E. Domany and W. Kinzel, Phys. Rev. Lett. 53, 447 (1984).
