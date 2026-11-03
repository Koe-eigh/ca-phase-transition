# Fit a quadratic phase boundary to a reachable-site activity fraction heat map.
#
# Input format: phase_diagram.dat
#   p q active_count active_fraction
# The boundary is defined by an active-fraction contour. Adjust boundary_level to
# choose which part of the transition band should be fitted.

reset
datafile = 'phase_diagram.dat'

set terminal pngcairo size 1100,850
set output 'phase_boundary_fit.png'

set title 'DKCA phase boundary fit'
set xlabel 'p'
set ylabel 'q'
set cblabel 'active fraction of reachable sites'
set cbrange [0:1]

# Display the heat map on ordinary linear p-q axes.
unset logscale
set xrange [0:1]
set yrange [0:1]

boundary_level = 0.1

# Extract the actual level contour, rather than fitting binary labels over
# the whole heat map. Linear contour interpolation retains the data geometry.
unset pm3d
set contour base
set cntrparam linear
set cntrparam levels discrete boundary_level
unset surface
set table $boundary_points
splot datafile using 1:2:4
unset table
unset contour
set surface

# A contour table separates disconnected curves with blank lines. Gnuplot's
# pseudocolumn -1 identifies each curve; keep the longest phase-boundary branch.
stats $boundary_points using (column(-1)) nooutput
component_count = int(STATS_max) + 1
selected_component = -1
selected_count = 0
do for [component=0:component_count-1] {
    stats $boundary_points using (column(-1) == component ? $1 : 1/0) nooutput
    if (STATS_records > selected_count) {
        selected_component = component
        selected_count = STATS_records
    }
}
if (selected_count < 3) { print 'No contour branch with at least three points'; exit status 1 }
print sprintf('Fitting contour component %d (%d points)', selected_component, selected_count)

# Anchor the vertex to the selected level contour's intersection with q=1.
# This is a finite-time, level-dependent endpoint, not a theoretical critical point.
stats $boundary_points using (column(-1) == selected_component && abs($2 - 1.0) < 1e-8 ? $1 : 1/0) nooutput
if (STATS_records != 1) { print 'Selected contour must intersect q=1 exactly once'; exit status 1 }
b = STATS_min
a = -10.0
c = 1.0
boundary(p) = a*(p-b)**2 + c
fit boundary(x) $boundary_points using (column(-1) == selected_component ? $1 : 1/0):2 via a
print sprintf('Observed level %.4g endpoint at q=1: p=%.8g', boundary_level, b)

set view map
set pm3d map
set palette defined (0 "#16324f", 0.5 "#f2c14e", 1 "#d1495b")
set grid xtics ytics

# Draw the right branch from the observed endpoint to q=0 (or p=1).
# This extends the fitted model beyond the observed contour's p range.
curve_p_max = (a < 0 && c >= 0 ? b + sqrt(-c/a) : 1.0)
curve_p_max = (curve_p_max < 1.0 ? curve_p_max : 1.0)
set samples 400
set table 'fitted_boundary.dat'
plot [p=b:curve_p_max] boundary(p) notitle
unset table

splot datafile using 1:2:4 with pm3d notitle, \
      $boundary_points using (column(-1) == selected_component ? $1 : 1/0):2:3 with lines lw 2 lc rgb 'black' \
      title sprintf('observed level %.4g', boundary_level), \
      'fitted_boundary.dat' using 1:2:(0.5) with lines lw 3 lc rgb 'white' \
      title sprintf('level %.4g fit: q = %.4g (p - %.4g)^2 + 1 (endpoint from data)', boundary_level, a, b)
