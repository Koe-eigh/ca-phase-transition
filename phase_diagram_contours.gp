set terminal pngcairo size 1000,800
set output 'phase_diagram_contours.png'

set title 'DKCA reachable-site activity fraction with contours'
set xlabel 'p'
set ylabel 'q'
set cblabel 'active fraction of reachable sites'
set cbrange [0:1]
set xrange [0:1]
set yrange [0:1]
set view map

set pm3d map
set palette defined (0 "#16324f", 0.5 "#f2c14e", 1 "#d1495b")
set grid

# Draw contours of active_fraction, including the fitted-boundary level 0.1.
set contour base
set cntrparam levels incremental 0,0.05,1
set cntrparam firstlinetype 1
set cntrlabel onecolor format '%g' font ',8' start 12 interval -1
set linetype 1 lc rgb 'white' lw 1

# Draw the heat map and contours as two overlaid map plots.
set lmargin at screen 0.105
set rmargin at screen 0.800
set bmargin at screen 0.135
set tmargin at screen 0.865
set multiplot
set pm3d map
unset contour
splot 'phase_diagram.dat' using 1:2:4 with pm3d notitle

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
splot 'phase_diagram.dat' using 1:2:4 with lines lt 1 notitle
# Label the major levels separately so neighboring values stay legible.
set cntrparam levels incremental 0.1,0.1,1
splot 'phase_diagram.dat' using 1:2:4 with labels tc rgb 'white' notitle
unset multiplot
