"""Where and how the benchmark jobs run: interpreter, external programs, scheduler.

Every submitter builds a self-contained bash script per job and hands it to
:func:`submit`. Nothing here assumes a particular site. Configure it with
environment variables:

``PAPER_SCHEDULER``
    ``local`` (default) runs each job script with ``bash`` on this machine, one after
    another. ``slurm`` submits it with ``sbatch``.
``PAPER_SLURM_PARTITION``, ``PAPER_SLURM_CONSTRAINT``
    Added as ``#SBATCH --partition`` / ``--constraint`` when set; omitted otherwise, so
    the cluster's defaults apply. The timing figures (2c, 3, ExtFig 4) were measured
    with every engine pinned to one CPU model; set the constraint to reproduce that.
``PAPER_SLURM_EXTRA``
    Further ``#SBATCH`` options, separated by ``;`` (e.g. ``--account=abc;--qos=long``).
``PAPER_PYTHON``
    Interpreter the jobs run TorchRef with. Defaults to the one running the submitter,
    which is the environment ``requirements.txt`` was installed into.
``CCP4_SETUP``, ``PHENIX_ENV``
    Optional scripts to ``source`` before calling REFMAC5 or PHENIX. Leave unset when
    ``refmac5`` and ``phenix.*`` are already on ``PATH``.

Resource requests (cores, memory, walltime) are written into every script either way;
the local runner ignores memory and walltime but passes the core count on through
``TORCHREF_NUM_THREADS`` where the job sets it.
"""

from __future__ import annotations

import os
import shlex
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

SCHEDULER = os.environ.get("PAPER_SCHEDULER", "local").strip().lower()
if SCHEDULER not in ("local", "slurm"):
    raise SystemExit(f"PAPER_SCHEDULER must be 'local' or 'slurm', not {SCHEDULER!r}")

PYTHON = os.environ.get("PAPER_PYTHON") or sys.executable
#: Appended to ``PYTHON -u``; runs the refinement CLI of the installed TorchRef.
REFINE_SCRIPT = "-m torchref.cli.refine"

PARTITION = os.environ.get("PAPER_SLURM_PARTITION", "").strip()
CONSTRAINT = os.environ.get("PAPER_SLURM_CONSTRAINT", "").strip()
EXTRA = [o.strip() for o in os.environ.get("PAPER_SLURM_EXTRA", "").split(";") if o.strip()]


def _source(var: str) -> str:
    path = os.environ.get(var, "").strip()
    return f"source {shlex.quote(path)}" if path else f"# {var} unset: expecting the programs on PATH"


#: Lines to paste into a job before calling REFMAC5 / PHENIX.
CCP4_SETUP = _source("CCP4_SETUP")
PHENIX_SETUP = _source("PHENIX_ENV")


def header(name, *, out, err=None, cpus=1, mem="4G", time="01:00:00",
           array=None, exclusive=False, gpus=0):
    """Shebang plus scheduler directives and log redirection for one job script.

    ``out`` / ``err`` may contain SLURM's ``%a`` (array task) and ``%A`` / ``%j`` (job id);
    the local runner substitutes the task index and ``local``. ``array`` is
    ``(first, last)`` inclusive; the task index is then available as ``$TASK_ID``.
    """
    err = err or out
    lines = ["#!/bin/bash"]
    if SCHEDULER == "slurm":
        opts = [f"--job-name={name}", f"--cpus-per-task={cpus}", f"--mem={mem}",
                f"--time={time}", f"--output={out}", f"--error={err}"]
        if PARTITION:
            opts.append(f"--partition={PARTITION}")
        if CONSTRAINT:
            opts.append(f"--constraint={CONSTRAINT}")
        if array:
            opts.append(f"--array={array[0]}-{array[1]}")
        if exclusive:
            opts.append("--exclusive")
        if gpus:
            opts.append(f"--gres=gpu:{gpus}")
        opts += EXTRA
        lines += [f"#SBATCH {o}" for o in opts]
        lines.append("")
        if array:
            lines.append("TASK_ID=${SLURM_ARRAY_TASK_ID}")
    else:
        lines.append(f"# job {name}: {cpus} core(s), {mem}, {time} (run locally)")
        lines.append("")
        if array:
            lines.append('TASK_ID="${1:?task index}"')

        def local(p):
            return str(p).replace("%a", "${TASK_ID}").replace("%A", "local").replace("%j", "local")

        lines.append(f'mkdir -p "$(dirname "{local(out)}")"')
        if err == out:
            lines.append(f'exec > "{local(out)}" 2>&1')
        else:
            lines.append(f'exec > "{local(out)}" 2> "{local(err)}"')
    return "\n".join(lines) + "\n"


def submit(script_text, script_path, dry_run=False, array=None):
    """Write ``script_text`` to ``script_path`` and run or queue it.

    Returns a job id (SLURM) or ``"local"`` on success, ``None`` on failure or dry run.
    With ``array=(first, last)`` the local runner executes every task index in turn.
    """
    if dry_run:
        print(f"  [DRY-RUN] would {'sbatch' if SCHEDULER == 'slurm' else 'run'} -> {script_path}")
        return None
    script_path = Path(script_path)
    script_path.parent.mkdir(parents=True, exist_ok=True)
    script_path.write_text(script_text)

    if SCHEDULER == "slurm":
        try:
            out = subprocess.run(["sbatch", "--parsable", str(script_path)],
                                 capture_output=True, text=True, check=True)
            return out.stdout.strip().split(";")[0]
        except subprocess.CalledProcessError as e:
            print(f"  FAILED sbatch {script_path.name}: {e.stderr.strip()}")
            return None

    tasks = range(array[0], array[1] + 1) if array else [None]
    ok = True
    for t in tasks:
        cmd = ["bash", str(script_path)] + ([str(t)] if t is not None else [])
        rc = subprocess.run(cmd).returncode
        if rc:
            ok = False
            print(f"  FAILED {script_path.name}{'' if t is None else f' task {t}'} (exit {rc})")
    return "local" if ok else None


def queued_jobs(prefixes):
    """Number of this user's queued SLURM jobs whose name starts with ``prefixes``."""
    if SCHEDULER != "slurm":
        return None
    try:
        q = subprocess.run(["squeue", "-u", os.environ.get("USER", ""), "-h", "-o", "%j"],
                           capture_output=True, text=True).stdout
    except OSError:
        return None
    return sum(1 for j in q.split() if j.startswith(tuple(prefixes)))


def describe():
    """One line naming where jobs will go, for submitters to print."""
    if SCHEDULER == "local":
        return f"Scheduler: local (sequential)   Python: {PYTHON}"
    bits = [f"partition={PARTITION or '<default>'}",
            f"constraint={CONSTRAINT or '<none>'}"]
    return f"Scheduler: slurm ({', '.join(bits)})   Python: {PYTHON}"
