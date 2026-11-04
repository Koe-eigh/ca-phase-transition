FPM ?= fpm
GNUPLOT ?= gnuplot

p_steps ?= 21
q_steps ?= 21
max_steps ?= 200
grid_size ?= 200
simulation_count ?= 10
cut_p_below_half ?= false
seed ?=
output_dir ?= experiments/latest

plot_scripts := phase_diagram.gp phase_diagram_3d.gp phase_diagram_contours.gp \
                phase_diagram_loglog.gp phase_boundary_fit.gp \
                time_evolution.gp time_evolution_comparison.gp

.PHONY: experiment
experiment:
	@set -eu; \
	case "$(cut_p_below_half)" in \
	  true|false) ;; \
	  *) echo 'cut_p_below_half must be true or false' >&2; exit 2 ;; \
	esac; \
	set -- "$(p_steps)" "$(q_steps)" "$(max_steps)" "$(grid_size)" "$(simulation_count)"; \
	if [ -n "$(seed)" ]; then set -- "$$@" --seed "$(seed)"; fi; \
	if [ "$(cut_p_below_half)" = true ]; then set -- "$$@" --cut-p-below-half; fi; \
	mkdir -p "$(output_dir)"; \
	OUTPUT_DIR="$(abspath $(output_dir))" $(FPM) run --profile release \
	  --runner ./scripts/run-in-output-dir.sh -- "$$@"; \
	cd "$(abspath $(output_dir))"; \
	for script in $(plot_scripts); do \
	  $(GNUPLOT) "$(CURDIR)/$$script"; \
	done; \
	echo "Experiment complete: $(abspath $(output_dir))"
