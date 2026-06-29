# QA testing config (shared, not platform-specific)

## For QA (Android & iOS)

Use **[QA_WALKTHROUGH.md](./QA_WALKTHROUGH.md)** only. It has **step-by-step chapters** and **ready-to-paste Custom Pointer URLs** (GitHub **`raw.githubusercontent.com`** links to `qa-config/pointers/` on **`master`** — no Dropbox account needed).

Optional link table: **[DROPBOX_GENERATED_URLS.md](./DROPBOX_GENERATED_URLS.md)** (same URLs; filename is legacy).

---

This folder lives at the **repository root**. The same CSV fixtures and pointer files are used by **Android** and **iOS**: both apps resolve `artistUrl`, `scheduleUrl`, `descriptionMap`, and `eventYear` from the downloaded pointer text.

## Layout

| Path | Purpose |
|------|---------|
| `fixtures/` | Band lineup CSV, schedule CSV, description-map CSV, note files, and static assets (e.g. `fixtures/reports/`). Pointer files reference them via **GitHub raw** URLs. |
| `pointers/` | Pointer source files (`Section::key::value`); QA testers use **raw GitHub** URLs from the walkthrough. |
| `scripts/` | Regenerate fixtures (`build_qa_sixty_band_fixtures.py`), schedule times, optional Dropbox publish for maintainers. |

Per-festival app configuration (JSON) lives in **[config/festivals/](../config/festivals/)** at the repo root — not here.

## Using a pointer with Custom Pointer URL

1. Copy the full **GitHub raw** URL for your chapter from **QA_WALKTHROUGH.md** (`raw.githubusercontent.com/.../master/qa-config/pointers/...`).
2. In the app: **Preferences** → **Custom Pointer URL** → paste → save → refresh data (pull-to-refresh or background/foreground per build).
3. When finished testing, clear **Custom Pointer URL** and refresh to return to production.

## Pointer quick reference (file names)

| Pointer file | Use |
|--------------|-----|
| `pointer_bands_only.txt` | Lineup + empty schedule (header only). |
| `pointer_bands_and_preparties.txt` | Lineup + schedule with **Unofficial Event** and **Cruiser Organized** rows only (`qa_schedule_with_preparties.csv`; no ship **Show** rows). |
| `pointer_schedule_shows_only.txt` | Lineup + shows only (no pre-parties). |
| `pointer_schedule_march_2026_window.txt` | Lineup + March 2026–dated shows (“current window” fixture). |
| `pointer_qr_partial_receiver.txt` | Device A: partial schedule (Day 2 only) for offline QR import. |
| `pointer_qr_donor_full_schedule.txt` | Device B: full schedule to share QR (**70K** build only). |
| `pointer_description_notes.txt` | Lineup + schedule + description map with canned notes. |
| `pointer_auto_schedule_wizard.txt` | Shows + `AutoScheduleFlag` for Plan Your Schedule prompt. |

## Conventions

- **No Android- or iOS-only files** here; only data both apps already consume from production-style URLs.
- **QR flow:** two devices (or two installs); receiver and donor use different pointer URLs from the walkthrough.

Maintainer Dropbox tooling: **[DROPBOX_URLS.md](./DROPBOX_URLS.md)**.

### Scripts (maintainers)

| Script | Purpose |
|--------|---------|
| `scripts/build_qa_sixty_band_fixtures.py` | Downloads production lineup/schedule/description samples and overwrites canonical `qa-config/fixtures/*.csv` (see script docstring). |
| `scripts/regenerate_qa_schedule_times.py` | Rewrites `fixtures/qa_schedule_march_2026_current_window.csv` so show starts are ~**60 minutes** (and staggered) from run time — for **local alert** testing (see **QA_WALKTHROUGH.md Chapter 9**). Optional `--sync-event-year`. |
| `scripts/publish_dropbox_links.py` | Regenerate Dropbox shared links for `~/Dropbox/qa-config` (optional). |
