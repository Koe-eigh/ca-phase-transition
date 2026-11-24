# Run from an experiment directory after: python3 ../../scripts/prepare-mean-mu.py
# The fixed color scale makes zero and departures from it comparable across runs.
reset
set terminal pngcairo size 900,800
set output 'mean_mu_k50.png'
if (exists('TRIALS')) {
    set title sprintf('DKCA <mu> at k=50 (%d trials)', TRIALS)
} else {
    set title 'DKCA <mu> at k=50'
}
set xlabel 'p'
set ylabel 'q'
set xrange [0:1]
set yrange [0:1]
set cbrange [-5:5]
set cblabel '<mu> (site coordinates)'
set palette defined (-5 '#2166ac', 0 '#f7f7f7', 5 '#b2182b')
set view map
set size ratio -1
set pm3d map
set grid
set object 1 rect from graph 0,0 to graph 1,1 behind fc rgb '#d9d9d9' fillstyle solid noborder
splot 'mean_mu_k50.dat' using 1:2:3 with pm3d notitle
