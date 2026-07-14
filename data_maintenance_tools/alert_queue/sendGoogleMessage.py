#!/usr/bin/env python3
"""Send an FCM topic push via Firebase Admin.

Enhanced from DetectChangesNew/sendGoogleMessage.py to support:
  - per-festival titles
  - per-festival Firebase credentials (service-account JSON)
  - dry-run / verbose testing flags
  - callable API used by monitorMessageQueue.py

Auth (in order):
  1. --credentials / credentials_file service-account JSON
  2. GOOGLE_APPLICATION_CREDENTIALS
  3. Application Default Credentials (gcloud ADC)
     If ADC is missing and stdin is a TTY, prompts:
       gcloud auth application-default login
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from typing import Any, Optional

import firebase_admin
from firebase_admin import credentials, messaging


def _app_name(credentials_path: Optional[str], project_id: Optional[str]) -> str:
    if credentials_path:
        return f"cred:{os.path.abspath(credentials_path)}"
    if project_id:
        return f"project:{project_id}"
    return "[DEFAULT]"


def ensure_firebase_app(
    *,
    credentials_path: Optional[str] = None,
    project_id: Optional[str] = None,
    allow_prompt: bool = True,
    verbose: bool = False,
) -> firebase_admin.App:
    """Initialize (or reuse) a Firebase app for the given credentials/project."""
    name = _app_name(credentials_path, project_id)
    try:
        return firebase_admin.get_app(name)
    except ValueError:
        pass

    options: dict[str, Any] = {}
    if project_id:
        options["projectId"] = project_id

    cred: Any = None
    if credentials_path:
        path = os.path.expanduser(credentials_path)
        if not os.path.isfile(path):
            raise FileNotFoundError(
                f"Firebase credentials file not found: {path}"
            )
        cred = credentials.Certificate(path)
        if verbose:
            print(f"Using service account credentials: {path}", file=sys.stderr)
    else:
        # Application Default Credentials (user OAuth via gcloud, or env SA).
        try:
            import google.auth  # type: ignore

            adc, adc_project = google.auth.default(
                scopes=["https://www.googleapis.com/auth/firebase.messaging"]
            )
            cred = adc
            if not project_id and adc_project:
                options["projectId"] = adc_project
            if verbose:
                print(
                    f"Using Application Default Credentials "
                    f"(project={options.get('projectId', '(none)')})",
                    file=sys.stderr,
                )
        except Exception as first_err:
            if allow_prompt and sys.stdin.isatty():
                print(
                    "Google credentials are not available.\n"
                    "Run Application Default Credentials login now? "
                    "(opens browser) [Y/n] ",
                    end="",
                    file=sys.stderr,
                )
                answer = input().strip().lower()
                if answer in ("", "y", "yes"):
                    subprocess.check_call(
                        ["gcloud", "auth", "application-default", "login"]
                    )
                    import google.auth  # type: ignore

                    adc, adc_project = google.auth.default(
                        scopes=[
                            "https://www.googleapis.com/auth/firebase.messaging"
                        ]
                    )
                    cred = adc
                    if not project_id and adc_project:
                        options["projectId"] = adc_project
                else:
                    raise RuntimeError(
                        "No Firebase credentials. Provide credentials_file / "
                        "--credentials, set GOOGLE_APPLICATION_CREDENTIALS, "
                        "or run: gcloud auth application-default login"
                    ) from first_err
            else:
                raise RuntimeError(
                    "No Firebase credentials available for non-interactive run. "
                    "Provide credentials_file for each festival (recommended for "
                    "cron), or run once interactively: "
                    "gcloud auth application-default login. "
                    f"Original error: {first_err}"
                ) from first_err

    return firebase_admin.initialize_app(
        credential=cred,
        options=options or None,
        name=name,
    )


def send_to_topic(
    topic: str,
    message_text: str,
    *,
    title: str = "Band Announcement",
    credentials_path: Optional[str] = None,
    project_id: Optional[str] = None,
    dry_run: bool = False,
    allow_prompt: bool = True,
    verbose: bool = False,
) -> str:
    """Send (or dry-run) an FCM notification to [topic]. Returns message id or dry-run token."""
    topic = (topic or "global").strip()
    if not topic:
        raise ValueError("topic is required")
    if not (message_text or "").strip():
        raise ValueError("message text is required")

    title = (title or "Band Announcement").strip()
    body = message_text.strip()

    if verbose or dry_run:
        print(f"title={title!r}", file=sys.stderr)
        print(f"topic={topic!r}", file=sys.stderr)
        print(f"message={body!r}", file=sys.stderr)

    if dry_run:
        print("DRY-RUN: not calling Firebase Messaging", file=sys.stderr)
        return "dry-run"

    app = ensure_firebase_app(
        credentials_path=credentials_path,
        project_id=project_id,
        allow_prompt=allow_prompt,
        verbose=verbose,
    )

    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data={
            "message": body,
            "alert": body,
            "title": title,
        },
        android=messaging.AndroidConfig(
            ttl=86400,
            notification=messaging.AndroidNotification(
                click_action="NONE",
            ),
        ),
        topic=topic,
    )

    response = messaging.send(message, app=app)
    if verbose:
        print(f"Successfully sent message: {response}", file=sys.stderr)
    return response


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Send an FCM topic alert via Firebase Admin"
    )
    parser.add_argument(
        "-t",
        "--topic",
        dest="topic",
        default="global",
        help="FCM topic (default: global)",
    )
    parser.add_argument(
        "-m",
        "--message",
        dest="message",
        default="",
        help="Notification body text",
    )
    parser.add_argument(
        "--title",
        dest="title",
        default="Band Announcement",
        help="Notification title",
    )
    parser.add_argument(
        "--credentials",
        dest="credentials",
        default="",
        help="Path to Firebase service-account JSON for this festival app",
    )
    parser.add_argument(
        "--project",
        dest="project_id",
        default="",
        help="Optional Firebase/Google Cloud project id (ADC / options)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be sent; do not call Firebase",
    )
    parser.add_argument(
        "--no-prompt",
        action="store_true",
        help="Never prompt for gcloud ADC login (use in cron)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Verbose logging to stderr",
    )
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    if not args.message.strip():
        print("error: --message is required", file=sys.stderr)
        return 2
    try:
        response = send_to_topic(
            args.topic,
            args.message,
            title=args.title,
            credentials_path=args.credentials or None,
            project_id=args.project_id or None,
            dry_run=args.dry_run,
            allow_prompt=not args.no_prompt,
            verbose=args.verbose,
        )
        print(response)
        return 0
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
