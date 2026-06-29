# Festival configuration (shared Android + iOS)

Single source of truth for per-festival app settings. Each file is **self-contained** — copy an existing JSON and edit every field; there is no shared defaults layer.

**Adding a festival?** Start with **[ADD_NEW_FESTIVAL.md](../../ADD_NEW_FESTIVAL.md)** (process, data ownership, multi-year commitment). Use this file for JSON and build details.

## Files

| File | Purpose |
|------|---------|
| `70k.json` | 70,000 Tons Of Metal |
| `mdf.json` | Maryland Deathfest |
| `mmf.json` | Milwaukee Metal Fest |
| `registry.json` | Share extensions + **FCM topic names** (same across all festivals; isolated per Firebase project) |

## Adding a new festival

1. Copy e.g. `mdf.json` → `xyz.json` and edit **all** fields.
2. Add `xyzshare` to `registry.json` → `shareFileExtensions` (FCM topics stay in registry — no per-festival copy).
3. **Android:** add flavor to `festivalFlavorMap` in `andriod/app/build.gradle`.
4. **iOS:** new target/scheme; `copy-festival-config.sh` selects JSON by product name (`*MDF*`, `*MMF*`, else `70k`).
5. Complete the **outside JSON** checklist below.

## JSON field notes

- **`firebaseConfigFile`**, **`logo`**, venue icons, and **`graphics`** use `{ "android": "...", "ios": "..." }` because asset names differ by platform.
- **`packageName`** (Android) and **`bundleIdentifier`** (iOS) are documented in JSON; authoritative IDs still live in Gradle / Xcode.
- **`eventTypeDisplayNames`** / **`eventTypeFilterDisplayNames`**: keys are canonical event types (`Show`, `Meet and Greet`, …); values are per-language maps (`en`, `de`, `es`, `fr`, `pt`, `da`, `fi`).
- **`about`**: team members for the About screen (`name`, `roleTranslationKey`, optional `photoPositionTranslationKey` for group-photo position labels). Optional **`photo`** (one image) or **`photos`** (array) per member — each entry uses `{ "android": "...", "ios": "..." }`. Images render below that member's title. For a shared group photo, attach it only to the last listed member (others omit `photo`/`photos`). For individual headshots, add one photo per member.

## Outside festival JSON (required per app)

These are **not** loaded from JSON:

| Item | Android | iOS |
|------|---------|-----|
| App / launcher icon | `src/<flavor>/res/mipmap-*` | Asset catalog app icon set |
| Logo & toolbar images | `drawable` names in JSON | Image assets in catalog |
| Firebase project file | `src/<flavor>/google-services.json` (gitignored) | `GoogleService-Info-*.plist` + `copy-firebase-config.sh` |
| Application / bundle ID | `productFlavors.applicationId` | Target → General → Bundle Identifier |
| Signing & entitlements | Gradle signing config | Xcode provisioning |
| Optional localized app name | `resValue` / `strings.xml` | `InfoPlist.strings` |
| Store release | fastlane, Play Console | App Store Connect |

## Build integration

- **Android:** `packFestivalAssets*` Gradle tasks copy `{id}.json` → `assets/festival.json` and `registry.json` → `assets/festival_registry.json` before each flavor build.
- **iOS:** `copy-festival-config.sh` (called from `copy-firebase-config.sh`) copies the same files into the `.app` bundle at build time.

## Runtime

- Android: `FestivalConfig.initialize()` in `Bands70k.onCreate()` → `FestivalConfigJsonLoader`.
- iOS: `FestivalConfig.current` → `FestivalConfigLoader.loadFromBundle()`.

See file-header comments in `FestivalConfig.java` and `FestivalConfig.swift` for the same checklist.
