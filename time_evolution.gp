# Plot the time evolution of the two spatial second moments for one (p, q).
# Override the defaults, for example:
# gnuplot -e "p_target=0.8; q_target=0.5" time_evolution.gp
# The selected values must occur in time_evolution.dat.

reset
if (!exists('p_target')) p_target = 0.8
if (!exists('q_target')) q_target = 0.5
datafile = 'time_evolution.dat'
tolerance = 1e-9
selected(p, q) = abs(p - p_target) < tolerance && abs(q - q_target) < tolerance

set terminal pngcairo size 1100,800
set output 'time_evolution.png'
set title sprintf('DKCA spatial moments (p = %.3g, q = %.3g)', p_target, q_target)
set xlabel 'time step k'
set ylabel 'squared site coordinate'
set xrange [0:*]
set yrange [0:*]
set grid
set key top left

# Columns: p q k mean_N survivor_count mean_mu mean_mu2 variance_mu mean_sigma2
# NaN values (no surviving trials) are omitted by gnuplot.
plot datafile using (selected($1,$2) ? $3 : 1/0):(selected($1,$2) ? $7 : 1/0) \
        with lines lw 2 lc rgb '#d1495b' title '<mu^2(k)>', \
     datafile using (selected($1,$2) ? $3 : 1/0):(selected($1,$2) ? $9 : 1/0) \
        with lines lw 2 lc rgb '#16324f' title '<sigma^2(k)>'
