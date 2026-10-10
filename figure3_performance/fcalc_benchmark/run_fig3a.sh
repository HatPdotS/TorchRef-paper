#!/bin/bash
# Fig3a fcalc thread scaling: every structure, every thread count, plus the GPU point
# when a CUDA device is present, in one process on this machine.
#
#   python figure3_performance/structures.py                 # once: fetch the structures
#   bash figure3_performance/fcalc_benchmark/run_fig3a.sh
#
# On a SLURM cluster, wrap it, e.g.
#   sbatch -c 16 --gres=gpu:1 --mem=64G --wrap "bash $PWD/figure3_performance/fcalc_benchmark/run_fig3a.sh"
# submit_fig3a_nodes.sh instead gives every structure its own exclusive node, which is how
# the published timings were taken.
set -euo pipefail

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="${BENCH_DIR}/../data/fcalc/results_${TS}"
PYTHON="${PAPER_PYTHON:-python}"

cd "${BENCH_DIR}"
echo "=== Fig3a fcalc thread scaling ==="
echo "Host: $(hostname)"
nvidia-smi 2>/dev/null | head -20 || true
echo "Output dir: ${OUT_DIR}"
echo

"${PYTHON}" benchmark_thread_scaling.py --output_dir "${OUT_DIR}" --timeout 1200
