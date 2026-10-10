#!/bin/bash
# Run difference refinement for Figure 4 with the installed TorchRef.
# A GPU is used when one is available; the run also works on CPU, just slower.
#
#   bash figure4_difference_refinement/run_difference_refine.sh

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DM=$BASEDIR/data/8QL2_no_altloc.pdb
LM=$BASEDIR/work_no_altloc.pdb
LSF=$BASEDIR/data/7YYZ-light.mtz
DSF=$BASEDIR/data/8QL2-sf.cif
RES=$BASEDIR/data/IBL_grade.cif
OUTPATH=$BASEDIR/refinement_output

mkdir -p "$OUTPATH"

torchref.difference-refine \
    -dm "$DM" -lm "$LM" \
    -dsf "$DSF" -lsf "$LSF" \
    --fraction 0.22 --cif "$RES" \
    -o "$OUTPATH" --dmin 2.2 \
    --weight-schedule 1 --n-cycles 10 2>&1 | tee "$OUTPATH/out.log"
