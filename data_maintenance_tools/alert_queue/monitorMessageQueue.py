#!/usr/bin/env python3
"""Poll local Dropbox alert folders for .pending files and send FCM pushes.

Designed for cron every ~5 minutes:

  */5 * * * * /path/to/alert_queue/.venv/bin/python .../monitorMessageQueue.py --no-prompt

For each festival in the config:
  1. Scan dropbox_dir for *.pending alert files
  2. Send file contents via sendGoogleMessage
  3. Rename to .completed on success, .error on failure

Secrets (config + credentials JSON) must stay out of git.
"""

from __future__ import annotations

import argparse
import os
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

try:
    import yaml
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "PyYAML is required. pip install -r "
        "data_maintenance_tools/alert_queue/requirements.txt"
    ) from exc

# Allow `python monitorMessageQueue.py` from this directory.
_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

import sendGoogleMessage  # noqa: E402


PENDING_SUFFIXES = (".pending",)
ALERT_PREFIXES = ("bandannouncements-", "customalert-")


def _expand(path: str) -> Path:
    return Path(os.path.expanduser(path)).resolve()


def _default_log_path() -> Path:
    return Path.home() / "omf_message_queue.log"


def log_line(log_file: Path, message: str, *, also_stderr: bool = True) -> None:
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    line = f"[{stamp}] {message}"
    if also_stderr:
        print(line, file=sys.stderr)
    try:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        with log_file.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except Exception as exc:
        print(f"failed writing log {log_file}: {exc}", file=sys.stderr)


def load_config(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}
    if not isinstance(data, dict):
        raise ValueError("Config root must be a mapping/object")
    festivals = data.get("festivals")
    if not isinstance(festivals, list) or not festivals:
        raise ValueError("Config must include a non-empty festivals: list")
    return data


def resolve_credentials_file(
    festival: dict[str, Any],
    credentials_dir: Optional[Path],
    *,
    log_file: Optional[Path] = None,
) -> Optional[Path]:
    """Resolve service-account JSON for a festival, or None for ADC/OAuth.

    Supports:
      credentials_file: ~/path/to/file.json  (required if set; missing → error)
      credentials_tag: mdf   (+ credentials_dir)
        tries: {tag}.json, google{tag}Auth.json, {tag}-firebase-adminsdk.json
        If none exist, returns None so sendGoogleMessage can use ADC and
        (interactively) prompt for `gcloud auth application-default login`.
        OAuth does not create per-festival SA JSON files.
    """
    explicit = (festival.get("credentials_file") or "").strip()
    if explicit:
        path = _expand(explicit)
        if not path.is_file():
            raise FileNotFoundError(
                f"Firebase credentials file not found: {path}"
            )
        return path

    tag = (festival.get("credentials_tag") or festival.get("tag") or "").strip()
    if not tag:
        return None
    if not credentials_dir:
        if log_file is not None:
            log_line(
                log_file,
                f"{festival.get('id')}: credentials_tag={tag!r} but "
                "credentials_dir unset — using ADC/OAuth",
            )
        return None

    candidates = [
        credentials_dir / f"{tag}.json",
        credentials_dir / f"google{tag}Auth.json",
        credentials_dir / f"{tag}-firebase-adminsdk.json",
    ]
    for path in candidates:
        if path.is_file():
            return path

    if log_file is not None:
        log_line(
            log_file,
            f"{festival.get('id')}: no SA JSON for tag={tag!r} under "
            f"{credentials_dir} (tried {', '.join(p.name for p in candidates)}); "
            "falling back to ADC/OAuth",
        )
    return None


def is_alert_pending(path: Path) -> bool:
    name = path.name.lower()
    if not name.endswith(".pending"):
        return False
    # Ignore Dropbox/write probes and non-alert files.
    if name.startswith("."):
        return False
    return any(name.startswith(prefix) for prefix in ALERT_PREFIXES)


def list_pending_files(dropbox_dir: Path) -> list[Path]:
    if not dropbox_dir.is_dir():
        raise NotADirectoryError(f"dropbox_dir does not exist: {dropbox_dir}")
    files = [p for p in dropbox_dir.iterdir() if p.is_file() and is_alert_pending(p)]
    files.sort(key=lambda p: p.stat().st_mtime)
    return files


def rename_status(path: Path, new_suffix: str) -> Path:
    """Replace final extension (.pending) with new_suffix (.completed / .error)."""
    name = path.name
    lower = name.lower()
    for old in PENDING_SUFFIXES:
        if lower.endswith(old):
            new_name = name[: -len(old)] + new_suffix
            dest = path.with_name(new_name)
            path.rename(dest)
            return dest
    dest = path.with_name(name + new_suffix)
    path.rename(dest)
    return dest


def warm_festival_auth(
    festival: dict[str, Any],
    *,
    credentials_dir: Optional[Path],
    allow_prompt: bool,
    verbose: bool,
    log_file: Path,
) -> None:
    """Initialize Firebase auth for a festival (may open browser for ADC login).

    Called interactively even when there are no .pending files, so first-run
    OAuth is not deferred until the first alert.
    """
    fest_id = str(festival.get("id") or festival.get("name") or "unknown")
    cred_path = resolve_credentials_file(
        festival, credentials_dir, log_file=log_file
    )
    project_id = (festival.get("project_id") or "").strip() or None
    if cred_path:
        cred_desc = f"SA {cred_path}"
    else:
        cred_desc = "ADC/OAuth"
        if project_id:
            cred_desc += f" project={project_id}"
    log_line(log_file, f"{fest_id}: ensuring credentials ({cred_desc})")
    sendGoogleMessage.ensure_firebase_app(
        credentials_path=str(cred_path) if cred_path else None,
        project_id=project_id,
        allow_prompt=allow_prompt,
        verbose=verbose,
    )


def process_festival(
    festival: dict[str, Any],
    *,
    credentials_dir: Optional[Path],
    default_topic: str,
    dry_run: bool,
    allow_prompt: bool,
    verbose: bool,
    log_file: Path,
) -> tuple[int, int]:
    """Returns (success_count, error_count)."""
    fest_id = str(festival.get("id") or festival.get("name") or "unknown")
    name = str(festival.get("name") or fest_id)
    title = str(festival.get("default_title") or f"{name} Band Announcement")
    topic = str(festival.get("topic") or festival.get("channel") or default_topic or "global")
    dropbox_raw = (festival.get("dropbox_dir") or "").strip()
    if not dropbox_raw:
        raise ValueError(f"Festival {fest_id!r} missing dropbox_dir")

    dropbox_dir = _expand(dropbox_raw)
    cred_path = resolve_credentials_file(
        festival, credentials_dir, log_file=log_file
    )
    project_id = (festival.get("project_id") or "").strip() or None

    if not dropbox_dir.is_dir():
        log_line(
            log_file,
            f"{fest_id}: skip — dropbox_dir does not exist: {dropbox_dir} "
            "(create the folder and re-run)",
        )
        return 0, 0

    if verbose:
        log_line(
            log_file,
            f"{fest_id}: scanning {dropbox_dir} topic={topic} "
            f"credentials={cred_path or '(ADC)'}",
        )

    pending = list_pending_files(dropbox_dir)
    if not pending:
        if verbose:
            log_line(log_file, f"{fest_id}: no pending alerts")
        return 0, 0

    ok_n = 0
    err_n = 0
    for path in pending:
        try:
            text = path.read_text(encoding="utf-8")
            if not text.strip():
                raise ValueError("pending file is empty")

            log_line(log_file, f"{fest_id}: sending {path.name}")
            sendGoogleMessage.send_to_topic(
                topic,
                text,
                title=title,
                credentials_path=str(cred_path) if cred_path else None,
                project_id=project_id,
                dry_run=dry_run,
                allow_prompt=allow_prompt,
                verbose=verbose,
            )
            if dry_run:
                log_line(
                    log_file,
                    f"{fest_id}: dry-run ok for {path.name} (left as .pending)",
                )
            else:
                dest = rename_status(path, ".completed")
                log_line(log_file, f"{fest_id}: completed → {dest.name}")
            ok_n += 1
        except Exception as exc:
            err_n += 1
            log_line(log_file, f"{fest_id}: ERROR {path.name}: {exc}")
            log_line(log_file, traceback.format_exc(), also_stderr=verbose)
            if not dry_run:
                try:
                    dest = rename_status(path, ".error")
                    log_line(log_file, f"{fest_id}: renamed → {dest.name}")
                except Exception as rename_exc:
                    log_line(
                        log_file,
                        f"{fest_id}: failed renaming {path.name} to .error: "
                        f"{rename_exc}",
                    )
    return ok_n, err_n


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Monitor Dropbox alert folders and send FCM pending files"
    )
    parser.add_argument(
        "--config",
        default=str(Path(__file__).resolve().parent / "message_queue.config.yaml"),
        help="Path to message_queue.config.yaml (default: next to this script; gitignored)",
    )
    parser.add_argument(
        "--festival",
        action="append",
        default=[],
        help="Only process this festival id (repeatable)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Send path dry-run; do not rename pending files",
    )
    parser.add_argument(
        "--no-prompt",
        action="store_true",
        help="Never prompt for OAuth/ADC (required for cron)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Verbose logging",
    )
    parser.add_argument(
        "--log-file",
        default="",
        help="Override log file (default: ~/omf_message_queue.log or config)",
    )
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    config_path = _expand(args.config)
    if not config_path.is_file():
        print(f"error: config not found: {config_path}", file=sys.stderr)
        return 2

    try:
        config = load_config(config_path)
    except Exception as exc:
        print(f"error: invalid config: {exc}", file=sys.stderr)
        return 2

    log_file = _expand(args.log_file or config.get("log_file") or str(_default_log_path()))
    default_topic = str(config.get("default_topic") or "global")
    cred_dir_raw = (config.get("credentials_dir") or "").strip()
    credentials_dir = _expand(cred_dir_raw) if cred_dir_raw else None
    allow_prompt = not args.no_prompt

    festivals = config["festivals"]
    only = {f.strip() for f in args.festival if f.strip()}
    if only:
        festivals = [
            f
            for f in festivals
            if str(f.get("id") or f.get("name") or "").strip() in only
        ]
        if not festivals:
            print(f"error: no festivals matched --festival {sorted(only)}", file=sys.stderr)
            return 2

    log_line(
        log_file,
        f"monitor start config={config_path} festivals={len(festivals)} "
        f"dry_run={args.dry_run}",
    )

    # Interactive first-run: establish ADC/OAuth before scanning, even with no
    # pending files. Cron uses --no-prompt and skips this.
    if allow_prompt and sys.stdin.isatty():
        log_line(log_file, "warming credentials (interactive ADC/OAuth allowed)")
        for festival in festivals:
            fest_id = str(festival.get("id") or festival.get("name") or "?")
            try:
                warm_festival_auth(
                    festival,
                    credentials_dir=credentials_dir,
                    allow_prompt=True,
                    verbose=args.verbose,
                    log_file=log_file,
                )
            except Exception as exc:
                log_line(log_file, f"{fest_id}: auth warm-up ERROR: {exc}")
                log_line(log_file, traceback.format_exc(), also_stderr=args.verbose)
                print(
                    f"error: could not establish credentials for {fest_id}: {exc}",
                    file=sys.stderr,
                )
                return 1

    total_ok = 0
    total_err = 0
    for festival in festivals:
        fest_id = str(festival.get("id") or festival.get("name") or "?")
        try:
            ok_n, err_n = process_festival(
                festival,
                credentials_dir=credentials_dir,
                default_topic=default_topic,
                dry_run=args.dry_run,
                allow_prompt=allow_prompt,
                verbose=args.verbose,
                log_file=log_file,
            )
            total_ok += ok_n
            total_err += err_n
        except Exception as exc:
            total_err += 1
            log_line(log_file, f"{fest_id}: festival-level ERROR: {exc}")
            log_line(log_file, traceback.format_exc(), also_stderr=args.verbose)

    log_line(
        log_file,
        f"monitor done ok={total_ok} errors={total_err}",
    )
    return 1 if total_err else 0


if __name__ == "__main__":
    raise SystemExit(main())
