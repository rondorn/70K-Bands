"""Cross-platform TCP port release before starting the local server."""

from __future__ import annotations

import os
import signal
import subprocess
import sys
import time


def pids_using_port(port: int) -> list[int]:
    if sys.platform == "win32":
        return _pids_windows(port)
    return _pids_unix(port)


def release_port(port: int) -> None:
    pids = pids_using_port(port)
    if not pids:
        return

    print(f"Port {port} is in use by PID(s): {', '.join(map(str, pids))}")
    print("Attempting graceful shutdown...")
    for pid in pids:
        _terminate_pid(pid, force=False)

    time.sleep(1.0)
    remaining = pids_using_port(port)
    if not remaining:
        print(f"Port {port} released.")
        return

    print(f"Force releasing port {port}; killing PID(s): {', '.join(map(str, remaining))}")
    for pid in remaining:
        _terminate_pid(pid, force=True)
    time.sleep(0.5)


def _terminate_pid(pid: int, force: bool) -> None:
    if sys.platform == "win32":
        flag = "/F" if force else ""
        subprocess.run(
            ["taskkill", "/PID", str(pid), *([flag] if flag else []), "/T"],
            capture_output=True,
            check=False,
        )
        return

    sig = signal.SIGKILL if force else signal.SIGTERM
    try:
        os.kill(pid, sig)
    except (ProcessLookupError, PermissionError):
        pass


def _pids_unix(port: int) -> list[int]:
    if shutil_which("lsof"):
        result = subprocess.run(
            ["lsof", "-ti", f"tcp:{port}"],
            capture_output=True,
            text=True,
            check=False,
        )
        return _parse_pid_lines(result.stdout)

    if shutil_which("fuser"):
        result = subprocess.run(
            ["fuser", f"{port}/tcp"],
            capture_output=True,
            text=True,
            check=False,
        )
        # fuser prints "8080/tcp:  1234 5678"
        pids: list[int] = []
        for token in (result.stdout or "").replace(f"{port}/tcp:", "").split():
            if token.isdigit():
                pids.append(int(token))
        return pids

    return []


def _pids_windows(port: int) -> list[int]:
    result = subprocess.run(
        ["netstat", "-ano"],
        capture_output=True,
        text=True,
        check=False,
        encoding="utf-8",
        errors="replace",
    )
    pids: list[int] = []
    needle = f":{port}"
    for line in (result.stdout or "").splitlines():
        if "LISTENING" not in line.upper() or needle not in line:
            continue
        parts = line.split()
        if parts and parts[-1].isdigit():
            pids.append(int(parts[-1]))
    return sorted(set(pids))


def _parse_pid_lines(text: str) -> list[int]:
    pids: list[int] = []
    for line in (text or "").splitlines():
        line = line.strip()
        if line.isdigit():
            pids.append(int(line))
    return pids


def shutil_which(cmd: str) -> str | None:
    from shutil import which

    return which(cmd)
