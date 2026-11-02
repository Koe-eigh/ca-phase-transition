# Grid-size check (2026-11-02)

This repeats the 21 by 21 parameter sweep for 200 steps and 100 trials per
point, increasing the periodic grid from 200 to 800 sites. The purpose is to
check whether the late-time moments on the 200-site ring are affected by the
boundary. A site can propagate at most one lattice spacing per time step, so
activity seeded at `j=0` cannot reach the 800-site boundary by `k=200`.

Run from this directory using the release executable:

```sh
/absolute/path/to/ca-phase-transition 21 21 200 800 100
gnuplot /absolute/path/to/time_evolution_comparison.gp
```

At `q=0.5`, `k=200`:

| p | Surviving trials | mean_N | mean_mu2 | mean_sigma2 |
|---:|---:|---:|---:|---:|
| 0.75 | 54 | 7.61 | 428.4 | 563.8 |
| 0.85 | 91 | 54.21 | 284.3 | 3705.4 |

The corresponding 200-site values are `470.3, 529.7` for `p=0.75` and
`47.5, 3095.7` for `p=0.85` (mean_mu2, mean_sigma2). Random seeds are not
fixed, so exact differences combine grid-size effects and sampling variation.
The large change in `mean_mu2` at `p=0.85` and the continuing rise in the
800-site time series support a substantial finite-size effect at late times
on the 200-site ring.

The generated `.dat` and comparison `.png` are committed with this experiment.
