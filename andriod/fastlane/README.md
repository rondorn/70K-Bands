fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android release_all_apps

```sh
[bundle exec] fastlane android release_all_apps
```

Release all enabled apps to Google Play (build AABs first via release_full_automation.sh / Gradle)

### android upload_to_play_only

```sh
[bundle exec] fastlane android upload_to_play_only
```

Upload existing release AABs only (no Gradle). Use to debug Play API / service account permissions.

### android build_all_apps

```sh
[bundle exec] fastlane android build_all_apps
```

Build release AABs for all apps

### android download_metadata

```sh
[bundle exec] fastlane android download_metadata
```

Download metadata from Google Play Console

### android validate_aabs

```sh
[bundle exec] fastlane android validate_aabs
```

Validate AAB files

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
