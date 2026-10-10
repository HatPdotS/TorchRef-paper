#!/usr/bin/env python3
"""The ten structures Figure 3 is benchmarked on, and how to fetch them.

They are TorchRef's own test structures (``tests/files/{pdb,mtz}``), which the PyPI wheel
does not ship. ``python figure3_performance/structures.py`` downloads them from the
TorchRef **v0.6.4** tag on GitHub into ``figure3_performance/data/structures/`` and checks
each file against the SHA-256 recorded below, so the benchmark runs on byte-identical
inputs. Point ``PAPER_FIG3_STRUCTURES`` at another directory with the same
``pdb/`` + ``mtz/`` layout to use a local copy instead.

The benchmark scripts import :func:`discover_structures` and :func:`resolve_files`.
"""

from __future__ import annotations

import hashlib
import os
import sys
import urllib.request
from pathlib import Path

TAG = "v0.6.4"
URL = "https://raw.githubusercontent.com/HatPdotS/TorchRef/{tag}/tests/files/{ext}/{id}.{ext}"
DEFAULT_DIR = Path(__file__).resolve().parent / "data" / "structures"
STRUCTURES_DIR = Path(os.environ.get("PAPER_FIG3_STRUCTURES") or DEFAULT_DIR)

SHA256 = {
    ("1DAW", "pdb"): "71ea7cd141f493a1ac36479e2850f0c26276e64dcdc41136fc78a6e9522488c8",
    ("1DAW", "mtz"): "05e33f09722813ce14260e0309a5c723fd8060939b17fb8068102e0d05800f5d",
    ("2DQ6", "pdb"): "a036eb333a60dd4622caead180d7625ef9f38768c4c261a93ff8f57ab07c7d37",
    ("2DQ6", "mtz"): "4ec0c140468cd9cbb823c5db6c06869a871980e9cbac9c3511afef4571e89e05",
    ("3A5V", "pdb"): "51e80d29d13045c52881a400dbd9a380e949f22478afcf8e1c117f2240281cc8",
    ("3A5V", "mtz"): "ecff1e357ad7cd02d7c1d56ac2825acf90d505c9f206172aa0bc35361dad6cf1",
    ("3E98", "pdb"): "96466502f8ec262626338ecf79b5c2f43d13f57805b3bcc452957d020a786f73",
    ("3E98", "mtz"): "2f14ca08c58526bb176de028bee79c732eff94d9de1a6b1f168a5440be4e50dc",
    ("3GR5", "pdb"): "cc157b893bfe20276601519e077f6d3c2a4c4980a0c8c52949949dbbe1dbc1eb",
    ("3GR5", "mtz"): "21bceae3197bfb92ab135231e06027db14ab1e6a1fd6f3890c361f943b9fe7bd",
    ("3K7M", "pdb"): "e92f79256b075f8b3399327655a7a627f6eff9fb3b4a6d9515a1794df7ad5752",
    ("3K7M", "mtz"): "4ab18f1e3fb1eef4aac4604642cc640e9dfedb3bdb3c08ac12e81a48ea768312",
    ("3VRJ", "pdb"): "7178efc06d09a9f69008af64482060065301f8b620c7de6c4e0d16524ff6cb92",
    ("3VRJ", "mtz"): "058c1376a0349f7af1447b754afaa69e15c0be17e277dd39ec70e6eb71183131",
    ("4BX9", "pdb"): "c184dd2e6d264b174defeb8c8215112064c727d21a753e23a62aa1cf0b5448d4",
    ("4BX9", "mtz"): "8feeaaf719a08c568ff44c67db09aee98b8e04ad4361c5597302d9529b8389db",
    ("5BOV", "pdb"): "1cc7034d088953aaca6fd49dc12567e9858477bb48d2b2d5f8150dc8aa74fc3c",
    ("5BOV", "mtz"): "1043d9b4d67069f3df6c4fbf22352a0a23c3ce6055c7e18cb148156043ba8c75",
    ("6G9X", "pdb"): "d1aead2d81ace5b746edd0487234829ae1068be880a9bcbd389e6f8755e88deb",
    ("6G9X", "mtz"): "b8e0bdaa8817ae0adec9e86e1fb9df53de7f2768304945952c9e4e41f46570b8",
}
STRUCTURES = sorted({sid for sid, _ in SHA256})


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def discover_structures() -> list[str]:
    """Structure IDs with both a PDB and an MTZ present in :data:`STRUCTURES_DIR`."""
    pdb = {p.stem for p in (STRUCTURES_DIR / "pdb").glob("*.pdb")}
    mtz = {p.stem for p in (STRUCTURES_DIR / "mtz").glob("*.mtz")}
    found = sorted(pdb & mtz)
    if not found:
        raise SystemExit(f"no benchmark structures in {STRUCTURES_DIR}; "
                         f"run: python {Path(__file__).resolve()}")
    return found


def resolve_files(structure: str) -> tuple[str, str]:
    """``(pdb, mtz)`` paths for one structure."""
    pdb = STRUCTURES_DIR / "pdb" / f"{structure}.pdb"
    mtz = STRUCTURES_DIR / "mtz" / f"{structure}.mtz"
    for path in (pdb, mtz):
        if not path.exists():
            raise FileNotFoundError(f"{path} (run: python {Path(__file__).resolve()})")
    return str(pdb), str(mtz)


def fetch(dest: Path = STRUCTURES_DIR) -> int:
    """Download any missing or mismatched file; return the number of failures."""
    failures = 0
    for (sid, ext), want in sorted(SHA256.items()):
        path = dest / ext / f"{sid}.{ext}"
        if path.exists() and _sha256(path) == want:
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        url = URL.format(tag=TAG, id=sid, ext=ext)
        print(f"  {sid}.{ext}  <- {url}")
        tmp = path.with_suffix(path.suffix + ".part")
        try:
            urllib.request.urlretrieve(url, tmp)
        except OSError as e:
            print(f"    FAILED: {e}")
            failures += 1
            continue
        if _sha256(tmp) != want:
            print("    FAILED: checksum mismatch")
            tmp.unlink()
            failures += 1
            continue
        tmp.replace(path)
    return failures


if __name__ == "__main__":
    print(f"Figure 3 structures (TorchRef {TAG}) -> {STRUCTURES_DIR}")
    n = fetch()
    if n:
        sys.exit(f"{n} file(s) failed")
    print(f"OK: {len(STRUCTURES)} structures verified")
