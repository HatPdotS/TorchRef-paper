#!/bin/bash
# Fig3b refinement-cycle thread scaling: every structure, every thread count, plus the
# GPU point when a CUDA device is present, in one process on this machine.
#
#   python figure3_performance/structures.py                 # once: fetch the structures
#   bash figure3_performance/refinement_cycle_benchmark/run_fig3b.sh
#
# On a SLURM cluster, wrap it, e.g.
#   sbatch -c 16 --gres=gpu:1 --mem=64G --time=24:00:00 \
#       --wrap "bash $PWD/figure3_performance/refinement_cycle_benchmark/run_fig3b.sh"
# submit_fig3b_nodes.sh instead gives every structure its own exclusive node, which is how
# the published timings were taken.
#
# The per-target breakdown on the large structures (5BOV, 2DQ6) is the long pole, so the
# per-worker timeout is generous.
set -euo pipefail

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="${BENCH_DIR}/../data/refinement_cycle/results_${TS}"
PYTHON="${PAPER_PYTHON:-python}"

cd "${BENCH_DIR}"
echo "=== Fig3b refinement-cycle thread scaling ==="
echo "Host: $(hostname)"
nvidia-smi 2>/dev/null | head -20 || true
echo "Output dir: ${OUT_DIR}"
echo

"${PYTHON}" benchmark_thread_scaling.py --output_dir "${OUT_DIR}" --timeout 3600
