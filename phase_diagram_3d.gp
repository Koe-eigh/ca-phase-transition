set terminal pngcairo size 1200,900
set output 'phase_diagram_3d.png'

set title 'DKCA reachable-site activity fraction at final time'
set xlabel 'p'
set ylabel 'q'
set zlabel 'active fraction of reachable sites' rotate by 90
set cblabel 'active fraction of reachable sites'
set xrange [0:1]
set yrange [0:1]
set zrange [0:1]
set cbrange [0:1]
set view 45, 315
set xyplane at 0
set pm3d at s
set palette defined (0 "#16324f", 0.5 "#f2c14e", 1 "#d1495b")
set grid

splot 'phase_diagram.dat' using 1:2:4 with pm3d notitle
