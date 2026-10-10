#!/bin/bash
# SLURM only. For a single machine use run_fig3a.sh instead.
# Fetch the structures first: python figure3_performance/structures.py
# Fig3a (fcalc) benchmark — one EXCLUSIVE node per structure.
#
# Why: this is a PERFORMANCE benchmark, so co-locating CPU-heavy jobs on a node
# corrupts the timing (shared memory bandwidth / L3). Each structure's CPU
# thread-scaling therefore runs as its own job on its OWN exclusive node (clean
# timing + full parallelism). The single GPU point per structure is CUDA-event
# timed (contention-insensitive), so all structures' GPU points run in one GPU
# job. A dependent job aggregates every per-structure JSON into summary.csv and
# renders the figure.
#
# PAPER_SLURM_CONSTRAINT pins every array task to one CPU model. Exclusivity alone
# is not enough on a heterogeneous cluster: without a constraint each structure is
# timed on whatever CPU generation SLURM had free. That
# makes the cross-structure trend part hardware and part code, and it makes two
# runs of this script incomparable -- an unchanged cctbx reference moved by 2x
# between the 2026-07-01 and 2026-08-04 runs for exactly this reason. Check
# availability first (>= one node per structure must be free):
#   sinfo -h -o "%n %f %t" | grep <model>
set -euo pipefail

# Scheduler options come from the same variables as jobs.py. Unset means "cluster default".
#   PAPER_SLURM_PARTITION      CPU partition (needs >= one free node per structure)
#   PAPER_SLURM_GPU_PARTITION  partition for the single GPU job
#   PAPER_SLURM_CONSTRAINT     CPU model feature; pin it so every structure is timed on
#                              the same CPU generation, as the published run was
CPU_OPTS=(); GPU_OPTS=(); AGG_OPTS=()
[ -n "${PAPER_SLURM_PARTITION:-}" ] && CPU_OPTS+=(--partition="$PAPER_SLURM_PARTITION") && AGG_OPTS+=(--partition="$PAPER_SLURM_PARTITION")
[ -n "${PAPER_SLURM_CONSTRAINT:-}" ] && CPU_OPTS+=(--constraint="$PAPER_SLURM_CONSTRAINT")
[ -n "${PAPER_SLURM_GPU_PARTITION:-}" ] && GPU_OPTS+=(--partition="$PAPER_SLURM_GPU_PARTITION")

BENCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${PAPER_PYTHON:-python}"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="${BENCH}/../data/fcalc/results_${TS}"
THREADS="1 2 4 8 16 32"
mkdir -p "${OUT}"
cd "${BENCH}"

"${PY}" -c "import benchmark_thread_scaling as b; print('\n'.join(b.discover_structures()))" \
    > "${OUT}/structures.txt"
N=$(wc -l < "${OUT}/structures.txt"); ARR="0-$((N - 1))"
echo "Structures (${N}): $(tr '\n' ' ' < "${OUT}/structures.txt")"
echo "Output: ${OUT}"
echo "CPU model: ${PAPER_SLURM_CONSTRAINT:-unconstrained}"
echo "${PAPER_SLURM_CONSTRAINT:-unconstrained}" > "${OUT}/cpu_model.txt"

# --- CPU thread-scaling: one exclusive node per structure, all the same model ---
CPU=$(sbatch --parsable --array="${ARR}" --job-name=fig3a_cpu \
    ${CPU_OPTS[@]+"${CPU_OPTS[@]}"} --exclusive --time=04:00:00 \
    --output="${BENCH}/fig3a_cpu_%A_%a.out" \
    --wrap "set -e; STRUCT=\$(sed -n \"\$((SLURM_ARRAY_TASK_ID+1))p\" ${OUT}/structures.txt); \
echo \"node \$(hostname)  structure \${STRUCT}\"; \
cd ${BENCH} && ${PY} benchmark_thread_scaling.py --structures \${STRUCT} --no_gpu \
--threads ${THREADS} --n_iterations 10 --n_warmup 3 --no_summary \
--output_dir ${OUT} --timeout 1800")
echo "CPU array: ${CPU} [${ARR}] (exclusive nodes)"

# --- GPU point: all structures, one GPU job ---
GPU=$(sbatch --parsable --job-name=fig3a_gpu \
    ${GPU_OPTS[@]+"${GPU_OPTS[@]}"} --gres=gpu:1 --cpus-per-task=8 --mem=32G \
    --time=02:00:00 --output="${BENCH}/fig3a_gpu_%j.out" \
    --wrap "cd ${BENCH} && ${PY} benchmark_thread_scaling.py --gpu_only \
--n_iterations 10 --n_warmup 3 --no_summary --output_dir ${OUT} --timeout 1800")
echo "GPU job: ${GPU}"

# --- Aggregate once everything finishes (build summary.csv only) ---
# NOTE: the Figure 3a speed panel needs BOTH this fcalc summary AND the
# SFcalculator-GPU data from SF_calc_comparison, so the figure is NOT rendered
# here. After this run and the SF run both finish, render it with:
#   plot_figure3a.py --fcalc-dir ${OUT} --sf-dir <SF results dir>
PLOT=$(sbatch --parsable --job-name=fig3a_agg ${AGG_OPTS[@]+"${AGG_OPTS[@]}"} --time=00:20:00 \
    --mem=8G --dependency="afterany:${CPU}:${GPU}" \
    --output="${BENCH}/fig3a_agg_%j.out" \
    --wrap "cd ${BENCH} && ${PY} benchmark_thread_scaling.py --aggregate --output_dir ${OUT}")
echo "Aggregate job: ${PLOT} (after ${CPU}, ${GPU})"
echo
echo "Watch: squeue -u \$USER   |   summary: ${OUT}/summary.csv"
echo "Then render Fig3a: ${PY} plot_figure3a.py --fcalc-dir ${OUT} --sf-dir <SF results dir>"
