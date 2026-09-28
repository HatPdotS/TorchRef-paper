# TorchRef paper — scripts, data and accepted manuscript

Companion repository for

> Seidel, H.-P., Standfuss, J. & Weinert, T. (2026). *TorchRef: An open-source PyTorch
> Framework for Crystallographic Refinement.* Journal of Applied Crystallography,
> accepted. <!-- TODO: volume, pages and DOI once published -->

The software itself lives at <https://github.com/HatPdotS/TorchRef>; the paper describes
**TorchRef v0.6.4**. This repository holds what turns data into the published figures:
the benchmark and plotting scripts, the data that fit in git, per-panel source data, and
the author accepted manuscript.

| Path | Contents |
|------|----------|
| `manuscript/` | Author accepted manuscript: LaTeX source, figures, and PDFs of the main text and Supplementary Methods |
| `source_data/` | The values each figure panel draws, one CSV per panel (see [`source_data/README.md`](source_data/README.md)) |
| `figure2_alphafold_start/` | Figure 2: AlphaFold-start benchmark against REFMAC5 and phenix.refine |
| `figure3_performance/` | Figure 3: structure-factor and refinement-cycle performance |
| `figure4_difference_refinement/` | Figure 4: difference refinement of IBL isomerisation in tubulin, all inputs and outputs |
| `extended_figures/` | Extended figures (ExtFig 1–5, described below) |

## Versions

The tag **`jac-accepted`** is the state the published figures were made from, and runs
against TorchRef v0.6.4. Commits after it on `main` follow later TorchRef API changes
and need a newer TorchRef.

## Setting up

The scripts were written to run as the `paper/` folder inside a TorchRef checkout, with
the TorchRef environment at `.dev/`; the commands below and in the per-figure READMEs
assume that layout.

```bash
git clone --branch v0.6.4 https://github.com/HatPdotS/TorchRef.git
cd TorchRef
rm -rf paper    # TorchRef tags from before this split still carry an older copy
git clone --branch jac-accepted https://github.com/HatPdotS/TorchRef-paper.git paper
python -m venv .dev && .dev/bin/pip install -e ".[dev]"

module load ccp4                    # REFMAC5 for validation
module load phenix/phenix-1.20-4459 # PHENIX for comparison refinement
```

## What is and is not in this repository

Re-plotting every figure needs only this repository: `source_data/` holds the plotted values.
Figure 3 (`figure3_performance/data/1DAW.*`) and Figure 4 carry their full inputs in-tree.

Re-running the Figure 2 benchmark from scratch additionally needs data that is too large for
git:

- the ~1000 benchmark structures (`data/`), which are PDB entries; the structure set is
  listed in `figure2_alphafold_start/manifest.json` and `mr_status.csv`;
- the PHENIX comparison refinements (`phenix_refinements/`);
- the placed AlphaFold starting models and run outputs (`figure2_alphafold_start/placed/`,
  `runs/`). <!-- TODO: Zenodo DOI for these -->

`data` and `phenix_refinements` are symlinks to where these live on the PSI cluster.

## Licences

- Code: MIT (`LICENSE`), as TorchRef.
- Manuscript, figures and data: CC BY 4.0 (`LICENSE-CC-BY-4.0.md`). The manuscript is the
  author accepted version, deposited under the IUCr green open-access policy; please cite the
  published article.
- Structures taken from the PDB (e.g. 1DAW, 7YYZ, 8QL2) remain under the PDB's own terms (CC0).

---

# Reproducing the figures

## Data Layout

The `paper/` directory expects two data sources linked as:

```
paper/
├── data -> ../scientific_testing/data            # ~1000 benchmark structures
│   └── {CODE}/{CODE}.mtz, {CODE}.pdb, ...        # reflections + deposited model
├── phenix_refinements -> .../refinements         # PHENIX comparison results
│   └── {CODE}/{CODE}_refined_001.pdb, .log, ...
```

Figure 2 refines **Phaser-placed AlphaFold models**, not the deposited or perturbed
coordinates: its starting models are `figure2_alphafold_start/placed/{CODE}_af.pdb`, and the
structure set is the MR-solved subset recorded in `figure2_alphafold_start/mr_status.csv`
(`solved == 1`, n = 767). Those placed models plus `manifest.json` / `mr_status.csv` are
*inputs* — produced once by the molecular-replacement pipeline in
`figure2_alphafold_start/` (`fetch_alphafold.py` → `prepare_search_model.py` →
`run_mr_one.sh` → `collect_mr_status.py`) and reused by every arm thereafter.

## Figures

Every `plot_*.py` also writes per-panel **source data** to `source_data/` as it renders — one
CSV holding the values that panel draws, after all filtering and derivation. See
[`source_data/README.md`](source_data/README.md) for the file list, units and caveats. There is
no separate export step: re-render a figure and its CSVs update with it.

### Figure 2: AlphaFold-start Benchmark
**Location:** `figure2_alphafold_start/`

TorchRef vs REFMAC5 vs phenix.refine, all four models (including the AlphaFold starting
point) scored by the same independent validator, `phenix.model_vs_data`. Panels: A
R-work/R-free, B geometry RMSZ, C wall-clock, D convergence.

Submit the three arms with `analysis/submit_fig2_arms.py`, which emits each structure's
arms adjacently on one pinned CPU model — Panel C compares wall-clock across engines, so
submitting one engine at a time confounds engine identity with cluster-load window. Then
`run_af_pipeline.py validate` (REFMAC 0-cycle), the two scoring sweeps, and
`analysis/aggregate_figure_metrics.py`; render with `plot_figure_af.py`.

### Figure 3: Performance Benchmarks
**Location:** `figure3_performance/`

- **Panel A**: Structure factor (Fcalc) thread scaling and GPU performance vs cctbx.
- **Panel B**: Full refinement cycle profiling with per-target breakdown.

Benchmark scripts in `fcalc_benchmark/` and `refinement_cycle_benchmark/`.
Test data: `data/1DAW.pdb` and `data/1DAW.mtz` (included in-tree).

### Figure 4: Difference Refinement
**Location:** `figure4_difference_refinement/`

Time-resolved difference refinement of IBL isomerisation in tubulin.
All input data and refinement outputs included in the directory.

### Extended Figures
**Location:** `extended_figures/`

| Figure | Description | Data status |
|--------|-------------|-------------|
| ExtFig 1 | AF-start loss-weight landscape (10×10 geometry×adp grid) | Plotting only — uses `figure2_alphafold_start/runs/metrics/weight_grid.csv` |
| ExtFig 2 | R-factor gap vs resolution (TorchRef − PHENIX & − REFMAC, AF-start, PHENIX-scored) | Plotting only — uses `figure2_alphafold_start/runs/metrics/fig_crossscore.csv` |
| ExtFig 3 | R-factor scorer consistency (REFMAC / PHENIX / TorchRef cross-scoring) | Plotting only — uses `figure2_alphafold_start/runs/metrics/fig_crossscore.csv` |
| ExtFig 4 | Single-core wall-clock runtime, 3 engines (reproduces Fig 2c at 1 CPU core, AF-start, n=715) | Requires re-running all three engines — `exF4/submit_singlecore.py` (2145 cells) then `aggregate_singlecore.py` |
| ExtFig 5 | X-ray target-mode comparison (`ml` / `ml_noalpha` / `ml_full` / `nll_beta`, AF-start, PHENIX-scored) | Plotting only — uses `figure2_alphafold_start/runs/metrics/mode_*.csv` |

See `extended_figures/instructions.md` for the design document.

### ExtFig 5: reproducing the target-mode comparison

Answers the reviewer question "does the choice of maximum-likelihood variant matter?" Reuses
Figure 2's exact 2×2 layout via `plot_figure_af.py --prefix/--engines`, so the two figures are
directly comparable — same scorer (`phenix.model_vs_data`), same conserved-set discipline.

The `ml` cell **is** Figure 2's `torchref` arm; only the other three are extra runs.

```bash
cd paper/figure2_alphafold_start
for m in ml_noalpha nll_beta; do
    ../../.dev/bin/python analysis/submit_local_arm.py --arm mode_$m --xray-mode $m
done
# ml_full costs ~4x per gradient (32-node quadrature)
../../.dev/bin/python analysis/submit_local_arm.py --arm mode_ml_full --xray-mode ml_full \
    --partition day --time 04:00:00 --mem 16G

# PHENIX-score the new arms (resume-safe; only the missing tasks are emitted)
../../.dev/bin/python analysis/build_crossscore_worklist.py \
    --arm ml_noalpha=mode_ml_noalpha --arm ml_full=mode_ml_full --arm nll_beta=mode_nll_beta
sbatch --array=1-N%60 analysis/crossscore_array.sh

../../.dev/bin/python analysis/aggregate_figure_metrics.py --prefix mode \
    --arm ml=torchref:torchref --arm ml_noalpha=mode_ml_noalpha:torchref \
    --arm ml_full=mode_ml_full:torchref --arm nll_beta=mode_nll_beta:torchref

../../.dev/bin/python plot_figure_af.py --prefix mode \
    -o ../extended_figures/exF5/output/extended_figure5.png \
    --engines ml_noalpha=ml_noalpha:#2166ac ml=ml:#b2182b \
              ml_full=ml_full:#762a83 nll_beta=nll_beta:#e08214
```

Before submitting anything, `../../.dev/bin/python check_submitter_flags.py` asserts every
submitter still emits flags `refine.py` accepts — a removed or renamed flag otherwise kills
several thousand jobs at argparse, one at a time.
