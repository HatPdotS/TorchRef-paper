#!/bin/bash
# Regenerate validation results and CCP4 maps for Figure 4.
#
# Please activate your python environment with torchref installed before running this script.

# Run from anywhere:
#   bash figure4_difference_refinement/validation/run_validation.sh


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/../data"
OUTPUT_DIR="${SCRIPT_DIR}/output"

BASEARGS="-dsf ${DATA_DIR}/8QL2-sf.cif -lsf ${DATA_DIR}/7YYZ-light.mtz -dm ${DATA_DIR}/8QL2_no_altloc.pdb --dmin 2.2 --plot --write-maps"
TORCH_ARGS="-lm ${SCRIPT_DIR}/../refinement_output/fractions_78_22_light.pdb --fraction 0.22"
EXTRAPOL_ARGS="-lm ${DATA_DIR}/7YYZ.pdb --fraction 0.22"

IBL="resname IBL"
FULL="chain A or chain B"

mkdir -p "${OUTPUT_DIR}"

torchref.validate-ded ${BASEARGS} ${TORCH_ARGS} --selection "${IBL}" -o ${OUTPUT_DIR}/torchref_IBL > ${OUTPUT_DIR}/torchref_IBL.log 2>&1
torchref.validate-ded ${BASEARGS} ${TORCH_ARGS} --selection "${FULL}" -o ${OUTPUT_DIR}/torchref_FULL > ${OUTPUT_DIR}/torchref_FULL.log 2>&1
torchref.validate-ded ${BASEARGS} ${EXTRAPOL_ARGS} --selection "${IBL}" -o ${OUTPUT_DIR}/extrapol_IBL > ${OUTPUT_DIR}/extrapol_IBL.log 2>&1
torchref.validate-ded ${BASEARGS} ${EXTRAPOL_ARGS} --selection "${FULL}" -o ${OUTPUT_DIR}/extrapol_FULL > ${OUTPUT_DIR}/extrapol_FULL.log 2>&1

