# Open Metal Fest Admin

Cross-platform festival admin app (Flutter). **macOS first** for local testing.

Part of the Open Metal Fest Suite — open source apps for metal festivals.

`data_maintenance_tools/` stays as the existing Flask prototype — this app is separate.

## Ownership model

- **App maintainer** owns pointer files and gives you testing + production pointer URLs.
- **Promoter** edits lineup / schedule / description files **in place** (stable Dropbox share links — never delete/replace files).
- Edits target **testing**; **Promote** copies testing → production in place.

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
| Multi-festival registry + Settings (pointers, venues, access) | Done |
| Load testing/production pointers → derive lineup/schedule/map URLs | Done |
| Connect Dropbox (PKCE, local callback) | Done |
| File-access gating (hide Band / Schedule / Descriptions without write) | Done |
| Create festival (existing pointers or bootstrap new Dropbox files) | Done |
| Bands list + add/edit (Discover; optional city/state; inline description) | Done |
| Schedule entry / view / stats (local staging + background Dropbox sync) | Done |
| Descriptions write + map | Done |
| Promote testing → production (in place, scoped by write access) | Done |

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

## How to use (macOS)

1. **Settings** — paste testing + production pointer URLs (or **Add New Festival**),
   then **Load from pointer**. Connect Dropbox if prompted.
2. **Bands** — Discover from Metal Archives / MusicBrainz; save to the testing lineup.
   Optional **Add description** writes the file and map on save.
3. **Schedule** — add events quickly; saves go to a local staging file and sync to
   Dropbox in the background (View shows Pending vs Synced).
4. **Descriptions** — write files and maintain the description map when needed.
5. **Promote** — preview counts, confirm, then copy testing → production in place.

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

**Windows** (if added later): local-only — no iCloud.

### Xcode one-time setup

1. Apple Developer → Identifiers → enable **iCloud** + Containers for
   `com.rdorn.open-metal-fest-admin`
2. Create container `iCloud.com.rdorn.open-metal-fest-admin` if missing
3. In Xcode (macOS + iOS targets) → Signing & Capabilities → **iCloud** →
   iCloud Documents → select that container
4. First Mac launch migrates existing Application Support config into iCloud
