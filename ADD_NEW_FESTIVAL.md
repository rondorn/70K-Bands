# Add a New Festival (Open Metal Fest Suite)

High-level guide for standing up a **new festival app** on the shared Android + iOS codebase. For JSON field reference and build wiring, see [config/festivals/README.md](config/festivals/README.md).

**Start here:** read [Work with the main repository](#work-with-the-main-repository) before planning a separate implementation.

---

## Work with the main repository

Open Metal Fest Suite is released under the **GPL**. Independent forks are permitted, but **collaboration through this repository is strongly encouraged**.

The platform is under active development. A shared codebase means bug fixes, improvements, and new features benefit the **entire** metal festival community

**Please reach out before creating a separate implementation.** In most cases, adding your festival here (config JSON, assets, Firebase, store listings) is less duplicated effort and a better experience for organizers and attendees. The main obstacle is **lineup and schedule data**, not the application code.

We do **not** want independent releases that diverge from the suite without coordinating with the maintainers. Parallel codebases split maintenance, duplicate platform work, and leave festivals behind when Android, iOS, or Firebase requirements change — work the shared project already handles.

---

## Read this first

### 1. Changing the app is the easy part; maintaining festival data is the hard part

Adding a festival flavor, icons, Firebase, and store listings is **a few days of engineering**. Keeping lineup, schedule, venues, logos, notes, and corrections accurate **for every festival year** is where most effort lives.

**Do not underestimate data work.** If you cannot name who will own data entry before you ship, stop here.

### 2. We strongly prefer to work with festival organizers

Ideal: the **promoter or their staff** maintains data (or works directly with the volunteers who do).

Without organizer involvement, you are more likely to face problems like:

- Which of the fifty bands named **Hate** did they actually book?
- Where is the logo for the obscure opener no one has heard of?
- Did the set time move, or is that a typo in a Facebook post?

Volunteer curators are welcome — **MDF Bands** has run successfully without direct festival involvement. That model is possible, but it is more difficult and asks much more of the data maintainer: confirming ambiguous details, chasing corrections, and keeping the app accurate when there is no official channel to the promoter. Stale or wrong data hurts everyone.

### 3. This is a multi‑year commitment, not a one‑year launch

We do **not** want to release an app for one festival season and let its lineup and schedule go stale.

**Platform maintenance** — Android/iOS updates, Firebase plumbing, store-policy rebuilds, and shared codebase work — is handled through Open Metal Fest Suite. That is **not** a per-festival obligation.

The multi‑year commitment is **festival data**. If you are championing a new festival, name who will own data work each year:

- Data entry and QA **before** each event
- Post‑announcement updates as bands and times change
- At least one **prior year** of historical data in the app (see below) so the product feels maintained, not empty

Sustainable data work is easier with continuity — identify who will own lineup and schedule updates beyond launch year, including who you expect to still be involved in year three.

---

## Overview — What you are building

Each festival ships as **its own Play Store and App Store app** — not as a mode inside an existing app.

Work falls into three buckets:

### Launch engineering (one time per festival)

- **Branding** — name, icon, About team  
  	- Effort: small
- **Festival config** — `config/festivals/{id}.json` + registry row  
  	- Effort: small
- **Firebase** — new project + FCM wiring  
  	- Effort: medium
- **Store listings** — metadata + first submission  
  	- Effort: medium
- **Reporting** — stats backend hookup  
  	- Effort: medium

### Ongoing festival work (every year)

- **Lineup, schedule, and pointer files**  
  	- Effort: **high** — the long-term commitment
- **JSON tweaks** — venues, URLs, feature flags  
  	- Effort: low; only when something changes

### Shared platform (not per-festival)

- Android/iOS updates
- Store-policy rebuilds
- Suite-wide code changes

Maintained through Open Metal Fest Suite — not by each festival’s data team. This is a key reason to add festivals **in this repo** rather than maintaining an independent fork.

---

## Phase 0 — Decide name, icon, and ownership

**Before writing code** — and ideally **before forking** — contact the maintainers to confirm the festival belongs in the shared suite.

1. **App name** — short store name (e.g. `MDF Bands`), festival full name for About copy (`festivalName` in JSON).
2. **App icon** — launcher icon sets for Android (`mipmap`) and iOS (asset catalog). Match festival branding guidelines if the organizer provides them.
3. **Data owner** — person or team responsible for CSV/pointer updates every year. Prefer **festival organizer contact**.
4. **Long‑term data owner** — who updates pointers and CSVs after year one? (Store releases and platform updates are shared across the suite.)
5. **Curator / notes** — who writes band summary text (if used)? Same data‑maintenance bucket as lineup/schedule.
   - This can be crowd-sourced — the app supports that — though note coverage tends to be more hit-and-miss than with a dedicated notes curator.

If phases 3 does not have a named owner, **pause**. Engineering can wait; bad data cannot be undone in the store reviews.

---

## Phase 1 — Festival config JSON

1. Copy an existing file: `mdf.json` → `{id}.json` (land-based festivals) or `70k.json` (cruise / special cases).
2. Edit **every** field: URLs, venues, event labels, `about` team, feature flags (`aiSchedule`, `scheduleQRShareEnabled`, etc.).
3. Add `{id}share` to [registry.json](config/festivals/registry.json) → `shareFileExtensions`.
4. Wire build targets:
   - **Android:** `festivalFlavorMap` + `productFlavors` in `andriod/app/build.gradle`
   - **iOS:** new target/scheme; extend `copy-festival-config.sh` / `copy-firebase-config.sh` name matching

Details: [config/festivals/README.md](config/festivals/README.md).

**Reminder:** JSON is a one‑time (per year) configuration. The **pointer files and CSVs** behind `defaultStorageUrl` are where daily pain lives.

---

## Phase 2 — Festival data (the real project)

Prepare data for **at least two years**:


-**Previous festival year**-  
  		- Proves the app is not a empty shell and ensure schedule data can be previewed even when current year schedule is not available
  	
-**Current / upcoming year**-  
  		- Active lineup and schedule (when announced)

Typical artifacts (hosted via Dropbox or your CDN — see existing festivals):

- **Artist lineup CSV** — canonical band names, priorities, metadata
- **Schedule CSV** — shows, venues, times, event types
- **Production pointer file** — `artistUrl`, `scheduleUrl`, `eventYear`, optional description map, test URLs
- **Test pointer** — parallel file for QA (`defaultStorageUrlTest` in JSON)


**Organizer involvement pays off here.** They have the definitive spreadsheet, stage names, and spelling of band names. Without them, you are reverse‑engineering Instagram posts.


## Phase 3 — Firebase

Each festival app uses its **own Firebase project** (isolated FCM, analytics, crash data).

1. Create Firebase project; register Android package + iOS bundle ID from JSON / Gradle / Xcode.
2. Add config files (gitignored in repo):
   - Android: `google-services.json` under `src/<flavor>/`
   - iOS: `GoogleService-Info-{FESTIVAL}.plist` + `copy-firebase-config.sh`
3. FCM topics live in [registry.json](config/festivals/registry.json) (`subscriptionTopic`, test topic, unofficial events topic). Topics are namespaced per Firebase project.
4. Server / `.env` keys for release automation (push sends, if used).
5. Ensure Firebase API keys are NOT checked into the code base (major security issue)

Test on the **test topic** only until production send is intentional.

---

## Phase 4 — Store metadata (Apple + Google)

Per app, per platform:

- Store listing text, screenshots, feature graphic (Play)
- Privacy policy URL, support URL, category
- Content rating questionnaire
- Signing: Android keystore / Play App Signing; Apple provisioning + entitlements
- fastlane / release scripts — add festival flags to `release_full_automation.sh` (or successor manifest)

First submission takes longer; updates are faster — but **someone** still ships each year.

---

## Phase 5 — Reporting backend

Festival apps report usage and serve **stats** HTML (in-app WebView) from Firebase-backed or hosted reporting pipelines.

At high level:

1. Ensure the new Firebase project is included in whatever generates **stats HTML** and dashboards (see existing 70K / MDF / MMF reporting setup in the repo ops docs).
2. Verify the in-app stats screen loads for the new flavor (cached fallback behavior exists on Android).
3. Confirm analytics / crash reporting appear under the correct Firebase project.

This is engineering setup once; **content** in stats reports still depends on good festival data (Phase 2).

---

## Phase 6 — Ship and do not walk away


**Every year**

- New CSVs + pointer update (organizer or curator — **not** “we’ll fix it in code”)
- JSON tweaks only if venues, URLs, or features change
- Platform/store releases when OS or policy requires them (handled through the shared suite, not per-festival code ownership)
- Respond to wrong-band / wrong-time reports quickly — that is data, not a bugfix in `FestivalConfig`

---

## Summary

**Shipping a new festival app is straightforward. Keeping it accurate for a decade is not.**

Work through the **main Open Metal Fest Suite repository** — reach out early, add a festival flavor here, and focus energy on **data** (lineup, schedule, ownership), not a parallel codebase. Prefer organizer partnerships, plan for two years of data on day one, and treat engineering as the small part of the job. If that does not match how your festival operates, discuss before adding `{id}.json` — not after the store listing goes live.
