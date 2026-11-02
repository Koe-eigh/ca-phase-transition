# Compare several (p, q) pairs from time_evolution.dat in one figure.
# Edit these arrays together to change the selected parameter pairs.
reset
array p_targets[4] = [0.75, 0.80, 0.75, 0.85]
array q_targets[4] = [0.50, 0.50, 0.75, 0.50]
array colors[4] = ['#d1495b', '#16324f', '#198c72', '#b08325']
pair_count = 4
datafile = 'time_evolution.dat'
tolerance = 1e-9
selected(p, q, i) = abs(p - p_targets[i]) < tolerance && abs(q - q_targets[i]) < tolerance

set terminal pngcairo size 1200,1000
set output 'time_evolution_comparison.png'
set multiplot layout 2,1 title 'DKCA spatial moments by (p, q)'
set grid
set xrange [0:*]
set yrange [0:*]
set lmargin 11
set rmargin 22
set key outside right top

# Column 7: <mu^2(k)>; column 9: <sigma^2(k)>.
# NaN values after extinction are skipped automatically.
set title 'Mean squared center position'
set ylabel '<mu^2(k)>'
plot for [i=1:pair_count] datafile \
    using (selected($1,$2,i) ? $3 : 1/0):(selected($1,$2,i) ? $7 : 1/0) \
    with lines lw 2 lc rgb colors[i] title sprintf('p = %.2f, q = %.2f', p_targets[i], q_targets[i])

unset key
set title 'Mean spatial variance'
set xlabel 'time step k'
set ylabel '<sigma^2(k)>'
plot for [i=1:pair_count] datafile \
    using (selected($1,$2,i) ? $3 : 1/0):(selected($1,$2,i) ? $9 : 1/0) \
    with lines lw 2 lc rgb colors[i] notitle

unset multiplot
