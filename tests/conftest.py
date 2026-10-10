"""Fixtures for the paper-script tests.

The scripts import TorchRef and are written against the version the paper describes,
pinned in ``requirements.txt``. Run with ``pytest tests`` from the repository root.
"""

import re
from pathlib import Path

import pytest
import torchref

ROOT = Path(__file__).resolve().parents[1]
PINNED = re.search(r"torchref(?:\[.*?\])?==(\S+)", (ROOT / "requirements.txt").read_text())[1]


def pytest_sessionstart(session):
    if torchref.__version__ != PINNED:
        pytest.exit(
            f"these scripts target TorchRef {PINNED} (requirements.txt) but "
            f"TorchRef {torchref.__version__} is installed; see README 'Setting up'",
            returncode=3,
        )


@pytest.fixture(scope="session")
def paper_root() -> Path:
    """The repository root."""
    return ROOT


@pytest.fixture(scope="session")
def test_files_dir() -> Path:
    """Small models bundled for these tests only."""
    return ROOT / "tests" / "files"


@pytest.fixture(scope="session")
def figure3_data() -> Path:
    """The 1DAW model and reflections shipped with Figure 3."""
    return ROOT / "figure3_performance" / "data"
