# Cellular Automaton Simulation And Phase Transition

A study to observe a phase transition in a particular cellular automaton model.

## The Idea

Considering one-dimensional space with discrete grid points and the grid point at position $j$ and time step $k$ has the value $\eta(j;k)$ which is 0 or 1. The $\eta(j;k)$ follows the time evolution equation given below.

```math

P\left(
\eta(j;k)=1
\mid
\eta(j-1;k-1),\eta(j+1;k-1)
\right)
=
\begin{cases}
0,   & (\eta(j-1;k-1),\eta(j+1;k-1))=(0,0),\\
1-p, & (\eta(j-1;k-1),\eta(j+1;k-1))=(1,0),\\
1-p, & (\eta(j-1;k-1),\eta(j+1;k-1))=(0,1),\\
1-q, & (\eta(j-1;k-1),\eta(j+1;k-1))=(1,1).
\end{cases}

```
The probability that $\eta(j;k)=0$ is given by the complementary probability.

Depending on $p$ and $q$, the total number of active sites,

$$
N(k) = \sum_j \eta(j;k),
$$

is expected to exhibit three qualitatively different behaviors: explosion, stagnation, or extinction. In this study, I will run simulations for different values of $p$ and $q$ and investigate the resulting phase diagram in the $p$ - $q$ parameter space.
