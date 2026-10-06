set terminal pngcairo size 1000,800
set output 'phase_diagram_contours.png'

set title 'DKCA active sites with contour lines'
set xlabel 'p'
set ylabel 'q'
set cblabel 'active sites'
set xrange [0:1]
set yrange [0:1]
set view map

set pm3d map
set palette defined (0 "#16324f", 0.5 "#f2c14e", 1 "#d1495b")
set grid

# Draw contours of active_count, including the fitted-boundary level 10.
set contour base
set cntrparam levels incremental 0,5,50
set cntrlabel format '%g' font ',8'

# Draw the heat map and contours as two overlaid map plots.
set lmargin at screen 0.105
set rmargin at screen 0.800
set bmargin at screen 0.135
set tmargin at screen 0.865
set multiplot
set pm3d map
unset contour
splot 'phase_diagram.dat' using 1:2:3 with pm3d notitle

unset pm3d
set contour base
unset surface
unset title
unset xlabel
unset ylabel
unset cblabel
unset colorbox
unset xtics
unset ytics
unset border
set xrange [0:1]
set yrange [0:1]
set clip two
splot 'phase_diagram.dat' using 1:2:3 with lines lc rgb 'white' lw 1 notitle
unset multiplot
