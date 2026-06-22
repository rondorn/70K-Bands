# Add a New Festival (Open Metal Fest Suite)

High-level guide for adding a festival to the shared Android + iOS codebase. **Technical details** (JSON fields, Gradle, Xcode, assets): [config/festivals/README.md](config/festivals/README.md).

---

## Before you start

**Work through this repository.** Open Metal Fest Suite is GPL-licensed; forks are allowed, but collaboration here is strongly encouraged. The platform is under active development — a shared codebase means fixes and features benefit every festival app. **Reach out to maintainers before building or forking separately.** In most cases, adding a flavor here is less work than a parallel implementation. We do not want independent releases that diverge without coordination.

**Data is the hard part, not code.** Engineering (flavor, icons, Firebase, store listings) is days of work. Keeping lineup, schedule, logos, and notes accurate **every year** is the long-term job. Name who owns data before you ship.

**Organizer involvement helps, but is not required.** Ideal: the promoter or staff maintains data (or works with volunteers). Without that, ambiguous band names, missing logos, and schedule corrections are harder — **MDF Bands** runs on volunteer curation successfully, but it asks more of the data maintainer.

**Plan for multiple years of data, not a one-year launch.** Platform maintenance (OS updates, store rebuilds, suite code) is handled through Open Metal Fest Suite. Your commitment is **festival data**: entry and QA before each event, updates as announcements change, and at least one **prior year** of history so the app is not an empty shell.

---

## What you are building

Each festival is **its own Play Store and App Store app** — not a toggle inside an existing app.

- **Launch (once)** — branding, `config/festivals/{id}.json`, Firebase project, store listings, reporting hookup
- **Every year** — lineup CSV, schedule CSV, production pointer (**most of the ongoing effort**)
- **Suite-wide** — Android/iOS updates and shared code (not per-festival)

---

## Roadmap

1. **Contact maintainers** — confirm the festival belongs in the shared suite.
2. **Name ownership** — app name and icon; **data owner** for pointers/CSVs each year; optional notes curator (crowd-sourced notes are supported, but coverage is more hit-and-miss than a dedicated curator).
3. **Festival config** — copy `mdf.json` or `70k.json` → `{id}.json`, edit all fields, add share extension to [registry.json](config/festivals/registry.json), wire Android flavor + iOS target. See [config/festivals/README.md](config/festivals/README.md).
4. **Festival data** — at least **previous year** + **current/upcoming year**: lineup CSV, schedule CSV, production pointer (and test pointer for QA). Host on Dropbox or your CDN like existing festivals; validate with [qa-config/QA_WALKTHROUGH.md](qa-config/QA_WALKTHROUGH.md).
5. **Firebase** — separate project per app; register package/bundle IDs; add `google-services.json` / `GoogleService-Info-*.plist` (gitignored). FCM topics in `registry.json`. **Do not commit API keys.**
6. **Store release** — listings, screenshots, signing, fastlane flags for both platforms.
7. **Reporting** — new Firebase project included in stats HTML generation; verify in-app stats screen.
8. **Every year after** — update CSVs and pointers; JSON only when venues/URLs/features change; wrong-band reports are usually **data fixes**, not code.

---
