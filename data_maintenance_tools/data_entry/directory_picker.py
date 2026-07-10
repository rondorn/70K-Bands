"""Native folder picker for the local data-entry app."""

from __future__ import annotations

import platform
import subprocess
import sys
from pathlib import Path

_SUBPROCESS_FLAGS = 0
if sys.platform == "win32":
    _SUBPROCESS_FLAGS = getattr(subprocess, "CREATE_NO_WINDOW", 0)


def resolve_picker_initial_dir(path_hint: str = "", fallback_dir: str = "") -> str:
    """
    Pick a starting directory for native file/folder dialogs.

    Prefers an existing directory derived from path_hint, then fallback_dir
    (last browse location), then the user's home directory.
    """
    hint = (path_hint or "").strip()
    if hint:
        candidate = Path(hint).expanduser()
        if candidate.is_dir():
            return str(candidate.resolve())
        if candidate.is_file():
            return str(candidate.parent.resolve())
        parent = candidate.parent
        if parent.is_dir():
            return str(parent.resolve())

    fallback = (fallback_dir or "").strip()
    if fallback:
        fb = Path(fallback).expanduser()
        if fb.is_dir():
            return str(fb.resolve())

    return str(Path.home())


def _choose_directory_macos(initial_dir: str, title: str) -> str:
    safe_title = title.replace("\\", "\\\\").replace('"', '\\"')
    initial = Path(initial_dir).expanduser()
    if initial.is_dir():
        script = (
            f'set chosenFolder to choose folder with prompt "{safe_title}" '
            f'default location POSIX file "{initial}"\n'
            "POSIX path of chosenFolder"
        )
    else:
        script = (
            f'set chosenFolder to choose folder with prompt "{safe_title}"\n'
            "POSIX path of chosenFolder"
        )
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        if "User canceled" in stderr or result.returncode == 1:
            return ""
        raise RuntimeError(stderr or "Folder picker failed")
    return (result.stdout or "").strip()


def _tkinter_available() -> bool:
    try:
        import tkinter  # noqa: F401
    except ImportError:
        return False
    return True


def _choose_directory_tkinter(initial_dir: str, title: str) -> str:
    if not _tkinter_available():
        raise RuntimeError(
            "Folder picker requires tkinter. Reinstall Python from python.org "
            "(check 'tcl/tk and IDLE') or type the folder path manually."
        )
    script = f"""
import tkinter as tk
from tkinter import filedialog

root = tk.Tk()
root.withdraw()
root.attributes("-topmost", True)
path = filedialog.askdirectory(initialdir={initial_dir!r}, title={title!r})
print(path or "")
root.destroy()
"""
    result = subprocess.run(
        [sys.executable, "-c", script],
        capture_output=True,
        text=True,
        check=False,
        creationflags=_SUBPROCESS_FLAGS,
    )
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        raise RuntimeError(stderr or "Folder picker failed")
    return (result.stdout or "").strip()


def choose_directory(
    initial_dir: str = "",
    title: str = "Choose a folder",
    *,
    fallback_dir: str = "",
) -> str:
    """Open a native folder picker. Returns '' if the user cancels."""
    initial = resolve_picker_initial_dir(initial_dir, fallback_dir)
    system = platform.system()
    if system == "Darwin":
        return _choose_directory_macos(initial, title)
    return _choose_directory_tkinter(initial, title)


def _choose_file_macos(initial_dir: str, title: str) -> str:
    safe_title = title.replace("\\", "\\\\").replace('"', '\\"')
    initial = Path(initial_dir).expanduser()
    if initial.is_dir():
        script = (
            f'set chosenFile to choose file with prompt "{safe_title}" '
            f'default location POSIX file "{initial}"\n'
            "POSIX path of chosenFile"
        )
    else:
        script = (
            f'set chosenFile to choose file with prompt "{safe_title}"\n'
            "POSIX path of chosenFile"
        )
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        if "User canceled" in stderr or result.returncode == 1:
            return ""
        raise RuntimeError(stderr or "File picker failed")
    return (result.stdout or "").strip()


def _choose_file_tkinter(initial_dir: str, title: str) -> str:
    if not _tkinter_available():
        raise RuntimeError(
            "File picker requires tkinter. Reinstall Python from python.org "
            "(check 'tcl/tk and IDLE') or type the file path manually."
        )
    script = f"""
import tkinter as tk
from tkinter import filedialog

root = tk.Tk()
root.withdraw()
root.attributes("-topmost", True)
path = filedialog.askopenfilename(
    initialdir={initial_dir!r},
    title={title!r},
    filetypes=[("CSV files", "*.csv"), ("All files", "*.*")],
)
print(path or "")
root.destroy()
"""
    result = subprocess.run(
        [sys.executable, "-c", script],
        capture_output=True,
        text=True,
        check=False,
        creationflags=_SUBPROCESS_FLAGS,
    )
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        raise RuntimeError(stderr or "File picker failed")
    return (result.stdout or "").strip()


def choose_file(
    initial_path: str = "",
    title: str = "Choose a file",
    *,
    fallback_dir: str = "",
) -> str:
    """Open a native file picker. Returns '' if the user cancels."""
    initial = resolve_picker_initial_dir(initial_path, fallback_dir)
    system = platform.system()
    if system == "Darwin":
        return _choose_file_macos(initial, title)
    return _choose_file_tkinter(initial, title)
