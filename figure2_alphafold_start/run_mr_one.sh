#!/bin/bash
# Place one structure's AlphaFold model by Phaser MR. Self-contained: prepares
# the search model(s) (gemmi, torchref env), converts pLDDT->B
# (process_predicted_model), runs phaser, and copies the top solution to
# placed/{code}_af.pdb. Idempotent: exits early if already placed.
#
# Usage: run_mr_one.sh CODE
# PHENIX must be on PATH, or set PHENIX_ENV to a phenix_env.sh to source. The published
# placements used PHENIX 1.21.1-5286. Python is PAPER_PYTHON (default: python on PATH).
# NB: no `set -u` — phenix's env scripts reference unbound vars.
set -o pipefail

AFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${PAPER_PYTHON:-python}"

code="${1:?usage: run_mr_one.sh CODE}"
placed="$AFDIR/placed/$code"_af.pdb
wd="$AFDIR/search_models/$code"

if [ -f "$placed" ]; then
    echo "[$code] already placed -> $placed"
    exit 0
fi

echo "[$code] preparing search model(s)..."
"$PY" "$AFDIR/prepare_search_model.py" "$code" || {
    echo "[$code] PREP FAILED"; exit 1; }

if [ -n "${PHENIX_ENV:-}" ]; then source "$PHENIX_ENV"; fi

cd "$wd"
echo "[$code] process_predicted_model (pLDDT->B)..."
# maximum_rmsd=100 disables confidence-based residue removal: we already trimmed
# to the construct, so we only want the pLDDT->B conversion, never an emptied
# model (low-confidence small components were being deleted entirely).
for f in *_search.pdb; do
    proc="${f%.pdb}_processed.pdb"
    if ! phenix.process_predicted_model "$f" maximum_rmsd=100 \
            >> "process_${code}.log" 2>&1; then
        echo "[$code] process_predicted_model failed on $f; using trimmed model as-is"
        cp "$f" "$proc"
    fi
done

echo "[$code] phaser MR..."
phenix.phaser < phaser.keywords > "phaser_${code}.log" 2>&1
echo "[$code] phaser exit=$?"

# Top solution from MR_AUTO is ROOT.1.pdb
sol=$(ls -1 "${code}_phaser.1.pdb" 2>/dev/null | head -1)
if [ -n "$sol" ] && [ -f "$sol" ]; then
    mkdir -p "$AFDIR/placed"
    cp "$sol" "$placed"
    echo "[$code] SOLVED -> $placed"
else
    echo "[$code] NO SOLUTION (see $wd/phaser_${code}.log)"
fi
