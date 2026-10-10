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

The scripts target **TorchRef v0.6.4**, the version the paper describes, installed from
PyPI (`requirements.txt`). The tag **`jac-accepted`** is the exact state the published
figures were made from; `main` adds only fixes that keep the scripts running on v0.6.4
outside the cluster they were written on. The scripts are not updated for later TorchRef
releases.

Until TorchRef v0.7.0 these files lived in the `paper/` folder of the TorchRef repository;
from v0.7.0 on, this repository is their only home.

## Setting up

```bash
git clone https://github.com/HatPdotS/TorchRef-paper.git
cd TorchRef-paper
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt          # TorchRef 0.6.4 from PyPI
python -m pytest tests                    # smoke tests, a few seconds
```

Run every script from this environment. The tests refuse to run against any TorchRef other
than 0.6.4, so a mismatched environment fails loudly rather than producing different numbers.

Re-plotting needs nothing else. Re-running the benchmarks also needs:

- **CCP4** (REFMAC5) for Figure 2's validation and REFMAC arm. The published runs used
  CCP4 8.0 (REFMAC library 8.0.003).
- **PHENIX** for Figure 2's phenix.refine arm, the cross-scoring and molecular replacement.
  The published runs used PHENIX 1.21.1-5286.
- **cctbx** for Figure 3a's reference timings, importable from the same Python as TorchRef:
  `pip install cctbx-base`. PHENIX's bundled copy lives in PHENIX's own Python and does
  not count.

Put `refmac5` and `phenix.*` on `PATH`, or point `CCP4_SETUP` / `PHENIX_ENV` at the setup
script to source (e.g. `ccp4.setup-sh`, `phenix_env.sh`).

## Running the benchmarks

Every submitter writes one self-contained bash script per job and runs it through
[`jobs.py`](jobs.py), configured by environment variables:

| Variable | Default | Meaning |
|----------|---------|---------|
| `PAPER_SCHEDULER` | `local` | `local` runs the jobs one after another on this machine; `slurm` submits them with `sbatch` |
| `PAPER_SLURM_PARTITION` | unset | `#SBATCH --partition`; unset uses the cluster default |
| `PAPER_SLURM_CONSTRAINT` | unset | `#SBATCH --constraint`, e.g. a CPU-model feature |
| `PAPER_SLURM_GPU_PARTITION` | unset | Partition for the Figure 3 GPU job (`submit_fig3*_nodes.sh`) |
| `PAPER_SLURM_EXTRA` | unset | More `#SBATCH` options, `;`-separated (e.g. `--account=x;--qos=y`) |
| `PAPER_PYTHON` | current interpreter | Python the jobs run TorchRef with |
| `CCP4_SETUP`, `PHENIX_ENV` | unset | Scripts to `source` before REFMAC5 / PHENIX |

Every submitter takes `--dry-run`, which prints an example job script without running
anything. Start there, then `--limit 1`.

TorchRef jobs pass `--device cpu`. The published runs were CPU-only, and without it
TorchRef would pick up a local CUDA or Apple GPU and change what the runtime panels measure.

The full Figure 2 sweep is thousands of refinements and is only practical on a cluster.
Its wall-clock panel (2c) and ExtFig 4 compare engines against each other, so the published
runs pinned every job to one CPU model and interleaved the engines structure by structure.
With SLURM, set `PAPER_SLURM_CONSTRAINT` to a CPU feature your cluster offers to get the
same control. Locally, jobs run one at a time on one machine, which gives the same
property by construction.

## Data for Figure 2

Re-plotting every figure needs only this repository: `source_data/` holds the plotted values.
Figure 3 fetches its ten structures with `python figure3_performance/structures.py`
(byte-identical to TorchRef v0.6.4's test files, checksum-verified). Figure 4 carries its
full inputs in-tree.

Re-running the Figure 2 benchmark from scratch additionally needs data that is too large
for git. Provide it yourself:

- `data/{CODE}/{CODE}.mtz` and `{CODE}.pdb` at the repository root, one folder per
  benchmark structure (PDB entries; a directory or a symlink). The structure set is listed
  in `figure2_alphafold_start/manifest.json` and `mr_status.csv`.
- The placed AlphaFold starting models in `figure2_alphafold_start/placed/{CODE}_af.pdb`,
  or regenerate them with the molecular-replacement pipeline described below.
  <!-- TODO: Zenodo DOI for the placed models and run outputs -->

## Licences

- Code: MIT (`LICENSE`), as TorchRef.
- Manuscript, figures and data: CC BY 4.0 (`LICENSE-CC-BY-4.0.md`). The manuscript is the
  author accepted version, deposited under the IUCr green open-access policy; please cite the
  published article.
- Structures taken from the PDB (e.g. 1DAW, 7YYZ, 8QL2) remain under the PDB's own terms (CC0).

---

# Reproducing the figures

## Figure 2 inputs

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

Benchmark scripts in `fcalc_benchmark/` and `refinement_cycle_benchmark/`. Fetch the ten
benchmark structures once with `python figure3_performance/structures.py`, then run
`run_fig3a.sh` / `run_fig3b.sh` on one machine, or `submit_fig3a_nodes.sh` /
`submit_fig3b_nodes.sh` to give every structure its own exclusive SLURM node as the
published timings did. `data/1DAW.pdb` and `data/1DAW.mtz` (in-tree) serve the
single-structure scripts. Panel A's SFcalculator comparison points come from
`source_data/`; the scripts that produced them are not part of this repository.

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
cd figure2_alphafold_start
for m in ml_noalpha nll_beta; do
    python analysis/submit_local_arm.py --arm mode_$m --xray-mode $m
done
# ml_full costs ~4x per gradient (32-node quadrature)
python analysis/submit_local_arm.py --arm mode_ml_full --xray-mode ml_full \
    --time 04:00:00 --mem 16G

# PHENIX-score the new arms (resume-safe; only the missing tasks are emitted)
python analysis/build_crossscore_worklist.py \
    --arm ml_noalpha=mode_ml_noalpha --arm ml_full=mode_ml_full --arm nll_beta=mode_nll_beta
# build_crossscore_worklist.py prints the command that runs the worklist, locally or on SLURM

python analysis/aggregate_figure_metrics.py --prefix mode \
    --arm ml=torchref:torchref --arm ml_noalpha=mode_ml_noalpha:torchref \
    --arm ml_full=mode_ml_full:torchref --arm nll_beta=mode_nll_beta:torchref

python plot_figure_af.py --prefix mode \
    -o ../extended_figures/exF5/output/extended_figure5.png \
    --engines ml_noalpha=ml_noalpha:#2166ac ml=ml:#b2182b \
              ml_full=ml_full:#762a83 nll_beta=nll_beta:#e08214
```

Before submitting anything, `python check_submitter_flags.py` asserts every
submitter still emits flags `refine.py` accepts — a removed or renamed flag otherwise kills
several thousand jobs at argparse, one at a time.
