# Fit a quadratic phase boundary to an active-count heat map.
#
# Input format: phase_diagram.dat
#   p q active_count
# The boundary is defined by an active-count contour. Adjust boundary_level to
# choose which part of the transition band should be fitted.

reset
datafile = 'phase_diagram.dat'

set terminal pngcairo size 1100,850
set output 'phase_boundary_fit.png'

set title 'DKCA phase boundary fit'
set xlabel 'p'
set ylabel 'q'
set cblabel 'active sites'

# Display the heat map on ordinary linear p-q axes.
unset logscale
set xrange [0:1]
set yrange [0:1]

boundary_level = 10.0

# Extract the actual level contour, rather than fitting binary labels over
# the whole heat map. Linear contour interpolation retains the data geometry.
unset pm3d
set contour base
set cntrparam linear
set cntrparam levels discrete boundary_level
unset surface
set table $boundary_points
splot datafile using 1:2:3
unset table
unset contour
set surface

# Fix the vertex at (0.5, 1); fit only the curvature a.
b = 0.5
a = -10.0
c = 1.0
boundary(p) = a*(p-b)**2 + c
fit boundary(x) $boundary_points using 1:2 via a

set view map
set pm3d map
set palette defined (0 "#16324f", 0.5 "#f2c14e", 1 "#d1495b")
set grid xtics ytics

# Draw the right branch from the fixed vertex to q=0 (or p=1).
# This extends the fitted model beyond the observed contour's p range.
curve_p_max = (a < 0 && c >= 0 ? b + sqrt(-c/a) : 1.0)
curve_p_max = (curve_p_max < 1.0 ? curve_p_max : 1.0)
set samples 400
set table 'fitted_boundary.dat'
plot [p=b:curve_p_max] boundary(p) notitle
unset table

splot datafile using 1:2:3 with pm3d notitle, \
      $boundary_points using 1:2:3 with lines lw 2 lc rgb 'black' \
      title sprintf('observed level %.4g', boundary_level), \
      'fitted_boundary.dat' using 1:2:(0.5) with lines lw 3 lc rgb 'white' \
      title sprintf('level %.4g: q = %.4g (p - %.4g)^2 + %.4g (b,c fixed)', boundary_level, a, b, c)
