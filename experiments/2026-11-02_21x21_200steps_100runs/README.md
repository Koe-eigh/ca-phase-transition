# DKCA time evolution experiment (2026-11-02)

Parameters: 21 values each for `p` and `q` from 0 to 1, 200 time steps,
200 sites, and 100 independent trials per parameter pair.

From the repository root, build with `fpm build --profile release`, then run
the resulting executable from this directory:

```sh
/absolute/path/to/ca-phase-transition 21 21 200 200 100
gnuplot -e 'p_target=0.8; q_target=0.5' /absolute/path/to/time_evolution.gp
gnuplot /absolute/path/to/phase_diagram.gp
gnuplot /absolute/path/to/time_evolution_comparison.gp
```

The run produced `time_evolution.dat` (the source data for the moments),
`phase_diagram.dat`, `time_evolution.png`, `phase_diagram.png`, and
`time_evolution_comparison.png` here. These outputs are committed with this
experiment so the plots can be reproduced from the `.dat` files. The
comparison figure overlays
`(p,q)=(0.75,0.50), (0.80,0.50), (0.75,0.75), (0.85,0.50)` in each panel.

For `(p,q)=(0.8,0.5)`:

| k | mean_N | surviving trials | mean_mu2 | mean_sigma2 |
|---:|---:|---:|---:|---:|
| 0 | 1.00 | 100 | 0.00 | 0.00 |
| 50 | 9.41 | 81 | 45.96 | 179.19 |
| 100 | 15.47 | 81 | 161.53 | 526.30 |
| 200 | 27.93 | 81 | 239.80 | 1762.79 |

The two moment averages use surviving trials at each time step. `mean_N`
uses all 100 trials. The program does not set a fixed random seed, so a new
run will give different numerical values.

These committed data were generated before the periodic-wrap cutoff was
introduced. For a 200-site ring, spatial moments from `k=100` onward can be
distorted by wrapped coordinates and should not be interpreted as unbounded
lattice moments. New runs write `NaN` for those columns from `k=100` onward.
