"""Re-exec this process under alert_queue/.venv when present.

Allows `./monitorMessageQueue.py` / `./sendGoogleMessage.py` to work without
manually activating the virtualenv created by setup.sh.

Important (Homebrew / macOS): do NOT compare Path.resolve() of sys.executable to
.venv/bin/python — both often resolve to the same Cellar binary, which would
incorrectly skip re-exec and leave you on the system site-packages.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path


def ensure() -> None:
    root = Path(__file__).resolve().parent
    venv_root = root / ".venv"
    venv_python = venv_root / "bin" / "python"
    if not venv_python.is_file():
        return

    # Correct check: are we already running with this venv as sys.prefix?
    try:
        if Path(sys.prefix).resolve() == venv_root.resolve():
            return
    except OSError:
        pass

    os.execv(str(venv_python), [str(venv_python), *sys.argv])
