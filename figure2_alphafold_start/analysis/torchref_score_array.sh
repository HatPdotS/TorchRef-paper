#!/bin/bash
# TorchRef 0-cycle scoring: one model per task. A fresh process per model is
# memory-safe (large structures, e.g. 1B37's 8.3M A^3 cell, need ~16 G and the CPU
# allocator does not return that grid between models, so long-lived batching OOMs).
# A task is typically ~20-40 s.
#
#   bash  torchref_score_array.sh WORKLIST TASK         # one task (1-based line number)
#   sbatch --array=1-N%96 -o LOGDIR/%A_%a.out torchref_score_array.sh WORKLIST
#
# build_torchref_score_worklist.py prints both forms with the paths filled in.
# Runs analysis/torchref_score.py with PAPER_PYTHON (default: python on PATH).
#
# The walltime is sized for the tail, not the median: the largest ~60 of 3024 models run
# far longer than the typical task, and a 20-minute cap silently timed every one of them
# out (2026-08-11). A timed-out task leaves no torchref_validate.json, which drops that
# model's row from the TorchRef-scorer column of ExtFig 3 without any error.
#SBATCH --job-name=trscore
#SBATCH --time=02:00:00
#SBATCH --mem=20G
#SBATCH --cpus-per-task=2

set +o nounset
WORKLIST="${1:?usage: torchref_score_array.sh WORKLIST [TASK]}"
TASK="${2:-${SLURM_ARRAY_TASK_ID:?no task index: pass TASK or submit as a SLURM array}}"
PY="${PAPER_PYTHON:-python}"
SCORE="$(cd "$(dirname "$WORKLIST")/../.." && pwd)/analysis/torchref_score.py"
export TORCHREF_NUM_THREADS=2

LINE=$(sed -n "${TASK}p" "$WORKLIST")
if [ -z "$LINE" ]; then echo "no line ${TASK}"; exit 0; fi
IFS=$'\t' read -r ENGINE CODE MODEL MTZ OUTJSON <<< "$LINE"
echo "[$(date)] torchref-scoring $ENGINE/$CODE"
"$PY" "$SCORE" -m "$MODEL" -sf "$MTZ" -o "$OUTJSON" --device cpu --xray-mode ml
RC=$?
# Capture $? into RC on its OWN line, before anything else runs. `rc=$?` inside a
# string containing $(date) reports the *subshell's* status, not python's -- it read
# 0 for all 5308 tasks of a sweep in which every single one crashed, and because the
# script then exited on a successful echo, SLURM recorded COMPLETED throughout. The
# missing JSONs only surfaced as a nan in one cell of aggregate_crossscore.
echo "[$(date)] done rc=$RC -> $OUTJSON"
exit $RC
