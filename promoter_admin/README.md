# Open Metal Fest Admin

Cross-platform festival admin app (Flutter). **macOS first** for local testing;
Windows builds via GitHub Actions.

Part of the Open Metal Fest Suite — open source apps for metal festivals.

`data_maintenance_tools/` stays as the existing Flask prototype — this app is separate.

## Ownership model

- **App developer** owns fan-app wiring and usually owns the official Testing /
  Production **pointer files**. They give promoters the two Dropbox links, or
  use links the festival created to populate those files.
- **Promoters / volunteers** edit **Artists**, **Schedule**, and/or **Descriptions**
  on Dropbox (stable share links — never delete/replace files). Access is flexible:
  any mix of those capabilities is fine; sections without write access are hidden.
- Edits target **Testing**. **Publish to Production** copies Testing → Production
  without breaking share links.
- In the **fan app**, most attendees see **Production**. **Testing** is available
  under Advanced preferences (most users never switch).

## Two setup paths

**Path 1 (usual):** Install → paste Testing + Production links from the app
developer → Connect Dropbox → **Load festival data** → work.

**Path 2 (new festival / handoff):** Install → create festival links on Dropbox →
send those URLs to the app developer. They may use that data to fill the official
pointers the fan app uses (the created links are not always wired into the app
directly).

## Run on this Mac

```bash
cd promoter_admin
flutter pub get
flutter run -d macos
```

Or open in Xcode after first build:

```bash
open macos/Runner.xcworkspace
```

## Features

| Feature | Status |
|---------|--------|
| Multi-festival registry + Settings (Testing/Production links, venues, access) | Done |
| Load festival data from Testing/Production links → Artists / Schedule / Description map URLs | Done |
| Connect Dropbox (PKCE, local callback) | Done |
| File-access gating (hide Artists / Schedule / Descriptions without write) | Done |
| Create festival (existing links or bootstrap new Dropbox files) | Done |
| Artists list + add/edit (Discover; optional city/state; inline description) | Done |
| Schedule entry / view / stats (local staging + background Dropbox sync) | Done |
| Default event types: Show, Clinic, Meet and Greet, Special Event, Unofficial Event | Done |
| Descriptions write (auto map update) + Description map when needed | Done |
| Publish Testing → Production (scoped by write access) | Done |

## Dropbox console (one-time)

This app uses app key `ug24jfmymp185wi` (same family as the Flask tool). Add
**both** redirect URIs on the Dropbox app settings page:

```text
http://127.0.0.1:53682/oauth/dropbox/callback
omfadmin://oauth/dropbox/callback
```

- Desktop (Mac/Windows) uses the localhost URI.
- iPhone/iPad uses `omfadmin://…` so the system auth sheet can dismiss and return
  to the app (Safari + localhost hangs because iOS suspends the app).

Also ensure scopes include: `account_info.read`, `files.content.write`,
`files.metadata.read`, `sharing.read`, `sharing.write`.

## How to use

1. **Settings** — paste Testing + Production links (or **Add New Festival**),
   Connect Dropbox, then **Load festival data**. Your app developer may ask you
   to copy those links back to them.
2. **Artists** — Discover from Metal Archives / MusicBrainz; save to the Testing
   lineup. Optional **Add description** writes the file and updates the map on save.
3. **Schedule** — add events quickly; saves go to a local staging file and sync to
   Dropbox in the background (View shows Pending vs Synced). Event types always
   include Show, Clinic, Meet and Greet, Special Event, and Unofficial Event;
   festival-specific types can be added in Settings.
4. **Descriptions** — write files (map updates automatically when you choose that
   save path). **Description map** remains available for fixups and split ownership.
5. **Publish** — preview counts, confirm, then copy Testing → Production.

## Config storage

On **macOS / iPad** (when signed into iCloud), festival config and Dropbox auth sync
via iCloud Documents:

```text
iCloud.com.rdorn.open-metal-fest-admin
  Documents/OpenMetalFestAdmin/festival_registry.json
  Documents/OpenMetalFestAdmin/dropbox_auth.json
```

A local mirror is kept at `~/Library/Application Support/OpenMetalFestAdmin/`
(macOS) for offline fallback. Schedule staging stays device-local.

**Windows:** local-only — no iCloud.

## Windows builds (GitHub Actions)

You cannot compile Windows on a Mac. Use the **Promoter Admin Windows** workflow:

1. Push `promoter_admin/windows/` and `.github/workflows/promoter-admin-windows.yml`
   (must be on the default branch, `master`, for the Actions UI to list it).
2. GitHub → **Actions** → **Promoter Admin Windows** → **Run workflow**.
3. When the run finishes, open the run → **Artifacts** → download **omf-admin-windows**.
4. Unzip and run the `.exe` **from inside that folder** (DLLs must stay next to the exe).

### Xcode one-time setup

1. Apple Developer → Identifiers → enable **iCloud** + Containers for
   `com.rdorn.open-metal-fest-admin`
2. Create container `iCloud.com.rdorn.open-metal-fest-admin` if missing
3. In Xcode (macOS + iOS targets) → Signing & Capabilities → **iCloud** →
   iCloud Documents → select that container
4. First Mac launch migrates existing Application Support config into iCloud
