#!/bin/bash
# SLURM only. For a single machine use run_fig3b.sh instead.
# Fetch the structures first: python figure3_performance/structures.py
# Fig3b (refinement-cycle) benchmark — one EXCLUSIVE node per structure.
#
# Same rationale as Fig3a: clean per-structure CPU timing requires a dedicated
# node (no co-tenant memory-bandwidth contention). The refinement-cycle worker
# (loss + gradient over all targets, with a per-target breakdown) is the heavy
# one, so the CPU jobs get more walltime. GPU points run in one GPU job; a
# dependent job aggregates + plots.
#
# PAPER_SLURM_CONSTRAINT pins every array task to one CPU model, for the reason
# spelled out in submit_fig3a_nodes.sh: on a heterogeneous cluster exclusivity alone
# leaves each structure timed on a different CPU generation.
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
OUT="${BENCH}/../data/refinement_cycle/results_${TS}"
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

# --- CPU thread-scaling: one exclusive node per structure (heavy: longer walltime) ---
CPU=$(sbatch --parsable --array="${ARR}" --job-name=fig3b_cpu \
    ${CPU_OPTS[@]+"${CPU_OPTS[@]}"} --exclusive --time=12:00:00 \
    --output="${BENCH}/fig3b_cpu_%A_%a.out" \
    --wrap "set -e; STRUCT=\$(sed -n \"\$((SLURM_ARRAY_TASK_ID+1))p\" ${OUT}/structures.txt); \
echo \"node \$(hostname)  structure \${STRUCT}\"; \
cd ${BENCH} && ${PY} benchmark_thread_scaling.py --structures \${STRUCT} --no_gpu \
--threads ${THREADS} --n_iterations 10 --n_warmup 3 --no_summary \
--output_dir ${OUT} --timeout 3600")
echo "CPU array: ${CPU} [${ARR}] (exclusive nodes)"

# --- GPU point: all structures, one GPU job ---
GPU=$(sbatch --parsable --job-name=fig3b_gpu \
    ${GPU_OPTS[@]+"${GPU_OPTS[@]}"} --gres=gpu:1 --cpus-per-task=8 --mem=32G \
    --time=03:00:00 --output="${BENCH}/fig3b_gpu_%j.out" \
    --wrap "cd ${BENCH} && ${PY} benchmark_thread_scaling.py --gpu_only \
--n_iterations 10 --n_warmup 3 --no_summary --output_dir ${OUT} --timeout 3600")
echo "GPU job: ${GPU}"

# --- Aggregate + plot once everything finishes ---
PLOT=$(sbatch --parsable --job-name=fig3b_plot ${AGG_OPTS[@]+"${AGG_OPTS[@]}"} --time=00:20:00 \
    --mem=8G --dependency="afterany:${CPU}:${GPU}" \
    --output="${BENCH}/fig3b_plot_%j.out" \
    --wrap "cd ${BENCH} && ${PY} benchmark_thread_scaling.py --aggregate --output_dir ${OUT} \
&& ${PY} ../plot_figure3b.py --results-dir ${OUT}")
echo "Plot job: ${PLOT} (after ${CPU}, ${GPU})"
echo
echo "Watch: squeue -u \$USER   |   summary: ${OUT}/summary.csv   |   figure: ${BENCH%/*}/output/"
