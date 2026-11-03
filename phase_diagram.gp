set terminal pngcairo size 1000,800
set output 'phase_diagram.png'
set title 'DKCA reachable-site activity fraction at final time'
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
splot 'phase_diagram.dat' using 1:2:4 with pm3d notitle
