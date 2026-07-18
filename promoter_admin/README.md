# Open Metal Fest Admin

Cross-platform festival admin app (Flutter). **macOS first** for local testing;
Windows builds via GitHub Actions.

Part of the Open Metal Fest Suite — open source apps for metal festivals.

Festival admin for artists, schedule, descriptions, and publish lives here.
Other one-off tools (for example the 70K schedule QR poster) remain under
`data_maintenance_tools/`.

**Promoter / operator guide:** [docs/USER_GUIDE.md](docs/USER_GUIDE.md)

## Ownership model

- **App developer** owns fan-app wiring and usually owns the official Testing /
  Production **pointer files**. They give promoters the two Dropbox links, or
  use links the festival created to populate those files.
- **Promoters / volunteers** edit **Artists**, **Schedule**, and/or **Descriptions**
  on Dropbox (stable share links — never delete/replace files). Access is flexible:
  any mix of those capabilities is fine. Without write access, Artists, Schedule,
  and Descriptions stay viewable; Artists/Schedule Add · Edit · Delete are disabled.
  Without description-map write, you can still author description files (local
  Dropbox folder, first-time prompt) and copy the share link for a map admin.
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
| File-access gating (Artists / Schedule / Descriptions viewable; map write gated) | Done |
| Create festival (existing links or bootstrap new Dropbox files) | Done |
| Artists list + add/edit (Discover; optional city/state; inline description) | Done |
| Schedule entry / view / stats (local staging + background Dropbox sync) | Done |
| Default event types: Show, Clinic, Meet and Greet, Special Event, Unofficial Event | Done |
| Descriptions list (Create Description / Attach Link / Edit / Delete; date cache bump) | Done |
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

Also ensure scopes include: `account_info.read`, `files.content.read`,
`files.content.write`, `files.metadata.read`, `sharing.read`, `sharing.write`.

After changing scopes in the Dropbox developer console, users must
**Disconnect** and **Connect Dropbox** again so a new token is issued.

## How to use

1. **Settings** — paste Testing + Production links (or **Add New Festival**),
   Connect Dropbox, then **Load festival data**. Your app developer may ask you
   to copy those links back to them.
2. **Artists** — Discover from Metal Archives / MusicBrainz; save to the Testing
   lineup. Optional **Add description** writes the file (and updates the map when
   you have description write access).
3. **Schedule** — add events quickly; saves go to a local staging file and sync to
   Dropbox in the background (View shows Pending vs Synced). Event types always
   include Show, Clinic, Meet and Greet, Special Event, and Unofficial Event;
   festival-specific types can be added in Settings. Non-band events can include
   a description (schedule-only path for non-artist titles).
4. **Descriptions** — alphabetical artist list. Missing entries are greyed with
   **Create Description** / **Attach Link** (link only with map write).
   Mapped rows get **Edit** / **Delete**. Edit bumps the cache date (`-1`, `-2`
   same day). Without map write you can still create files and copy the share link.
5. **Publish** — preview counts, confirm, then copy Testing → Production.

## Config storage

On **macOS / iPad**, festival config and Dropbox auth sync via iCloud Documents
when iCloud is **configured** on the device (signed into iCloud and this app’s
Documents container is available):

```text
iCloud.com.rdorn.open-metal-fest-admin
  Documents/OpenMetalFestAdmin/festival_registry.json
  Documents/OpenMetalFestAdmin/dropbox_auth.json
```

If iCloud is not set up on the device, the same files live only under local
Application Support (`…/OpenMetalFestAdmin/`). A local mirror is also kept when
iCloud sync is enabled. Temporary network loss does not switch modes — ubiquity
writes still go to the container and sync later.

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
