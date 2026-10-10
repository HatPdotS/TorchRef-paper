#!/bin/bash
# PHENIX-vs-REFMAC cross-scoring: score one final model with phenix.model_vs_data.
# One task per line of the worklist written by build_crossscore_worklist.py.
#
#   bash  crossscore_array.sh WORKLIST TASK            # one task (1-based line number)
#   sbatch --array=1-N%60 -o LOGDIR/%A_%a.out crossscore_array.sh WORKLIST
#
# build_crossscore_worklist.py prints both forms with the paths filled in.
# PHENIX must be on PATH, or set PHENIX_ENV to a phenix_env.sh to source. The published
# scores used PHENIX 1.21.1-5286.
#
#SBATCH --job-name=xscore
#SBATCH --time=00:30:00
#SBATCH --mem=2G
#SBATCH --cpus-per-task=1

set +o nounset
WORKLIST="${1:?usage: crossscore_array.sh WORKLIST [TASK]}"
TASK="${2:-${SLURM_ARRAY_TASK_ID:?no task index: pass TASK or submit as a SLURM array}}"
if [ -n "${PHENIX_ENV:-}" ]; then source "$PHENIX_ENV"; fi

LINE=$(sed -n "${TASK}p" "$WORKLIST")
if [ -z "$LINE" ]; then
    echo "no worklist line for task ${TASK}"; exit 0
fi
IFS=$'\t' read -r ENGINE CODE MODEL MTZ OUTLOG <<< "$LINE"
echo "[$(date)] scoring model_engine=$ENGINE code=$CODE"
echo "  model: $MODEL"
echo "  data : $MTZ"

SCRATCH=$(mktemp -d)
cd "$SCRATCH" || exit 1
export CCP4_SCR="$SCRATCH"

phenix.model_vs_data "$MODEL" "$MTZ" > "$OUTLOG" 2>&1
RC=$?

cd / && rm -rf "$SCRATCH"
echo "[$(date)] done rc=$RC -> $OUTLOG"
exit $RC
