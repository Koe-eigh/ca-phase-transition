reset
set terminal pngcairo size 1000,800
set output 'phase_diagram_loglog.png'
set title 'DKCA active sites at final time (log-log axes)'
set xlabel 'p - 1/2'
set ylabel '1 - q'
set cblabel 'active sites'

# Only p > 1/2 and q < 1 have positive coordinates on these axes.
unset logscale
set autoscale
stats 'phase_diagram.dat' using ($1 > 0.5 && $2 < 1 ? $1 - 0.5 : 1/0):($1 > 0.5 && $2 < 1 ? 1 - $2 : 1/0) nooutput
x_min = STATS_min_x
x_max = STATS_max_x
y_min = STATS_min_y
y_max = STATS_max_y
set logscale x 10
set logscale y 10
set xrange [x_min:x_max]
set yrange [y_min:y_max]
set xtics (0.01, 0.02, 0.05, 0.1, 0.2, 0.5)
set mxtics 10
set view map
set pm3d map
set palette defined (0 "#16324f", 0.5 "#f2c14e", 1 "#d1495b")
set grid xtics ytics

splot 'phase_diagram.dat' using ($1 > 0.5 ? $1 - 0.5 : 1/0):($2 < 1 ? 1 - $2 : 1/0):3 with pm3d notitle
