"""API package initialization helpers."""

from pathlib import Path
import sys


def _ensure_local_pipecat_on_path() -> None:
	"""Make the local pipecat submodule importable in development."""
	repo_root = Path(__file__).resolve().parent.parent
	pipecat_src = repo_root / "pipecat" / "src"
	if pipecat_src.exists():
		pipecat_src_str = str(pipecat_src)
		if pipecat_src_str not in sys.path:
			sys.path.insert(0, pipecat_src_str)


_ensure_local_pipecat_on_path()
