"""Native folder picker for the local data-entry app."""

from __future__ import annotations

import platform
import subprocess
import sys
from pathlib import Path


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


def _choose_directory_tkinter(initial_dir: str, title: str) -> str:
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
    )
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        raise RuntimeError(stderr or "Folder picker failed")
    return (result.stdout or "").strip()


def choose_directory(initial_dir: str = "", title: str = "Choose a folder") -> str:
    """Open a native folder picker. Returns '' if the user cancels."""
    initial = ""
    if initial_dir:
        candidate = Path(initial_dir).expanduser()
        if candidate.is_dir():
            initial = str(candidate.resolve())
    if not initial:
        initial = str(Path.home())

    system = platform.system()
    if system == "Darwin":
        return _choose_directory_macos(initial, title)
    return _choose_directory_tkinter(initial, title)


def _initial_dir_for_path(path_str: str) -> str:
    if not path_str:
        return str(Path.home())
    candidate = Path(path_str).expanduser()
    if candidate.is_file():
        return str(candidate.parent.resolve())
    if candidate.is_dir():
        return str(candidate.resolve())
    parent = candidate.parent
    if parent.exists():
        return str(parent.resolve())
    return str(Path.home())


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
    )
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        raise RuntimeError(stderr or "File picker failed")
    return (result.stdout or "").strip()


def choose_file(initial_path: str = "", title: str = "Choose a file") -> str:
    """Open a native file picker. Returns '' if the user cancels."""
    initial = _initial_dir_for_path(initial_path)
    system = platform.system()
    if system == "Darwin":
        return _choose_file_macos(initial, title)
    return _choose_file_tkinter(initial, title)
