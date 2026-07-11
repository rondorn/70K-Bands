# Festival Promoter Admin (Flutter)

Cross-platform shell for Mac, iPad, and Windows store apps.

## Status

Prototype UI that talks to the local Flask **Workspace JSON API** while domain logic
lives in Python (`data_entry/workspace.py`, `promote.py`, `festival_layout.py`).

Native Dropbox OAuth inside Flutter (no local Flask) is the store-ship target; see
[STORE_SUBMISSION.md](../STORE_SUBMISSION.md).

## Prerequisites

1. [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.3+
2. Run the data-entry server: `../run.sh` or `../run.bat` (default `http://127.0.0.1:8080`)

## Run

```bash
cd promoter_admin
flutter pub get
flutter run -d macos          # or windows / chrome / ipad
```

Override API base URL:

```bash
flutter run --dart-define=API_BASE=http://127.0.0.1:8080
```

## Screens

| Screen | API |
|--------|-----|
| Workspace home | `GET /api/workspace` |
| Bands list / add | `GET/POST /api/bands` |
| Schedule list | `GET /api/schedule` |
| Promote | `POST /api/promote` |
| Create festival | `POST /api/festivals/create` |

Connect Dropbox and configure pointers in the Flask Config UI first (or via Create Festival).
