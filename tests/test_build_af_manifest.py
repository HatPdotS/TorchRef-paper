"""``figure2_alphafold_start/build_af_manifest.py`` reads chain sequences."""

import importlib.util


def test_local_sequences_reads_the_deposited_chain(
    paper_root, figure3_data, tmp_path, monkeypatch
):
    path = paper_root / "figure2_alphafold_start" / "build_af_manifest.py"
    spec = importlib.util.spec_from_file_location("build_af_manifest", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    (tmp_path / "1DAW").mkdir()
    (tmp_path / "1DAW" / "1DAW.pdb").symlink_to(figure3_data / "1DAW.pdb")
    monkeypatch.setattr(module, "DATA", tmp_path)

    sequences = module._local_sequences("1DAW")

    assert list(sequences) == ["A"]
    assert len(sequences["A"]) == 327
