# Release Verification

This guide defines the evidence required for the Android and iOS development
MVP. Automated checks and build output are necessary but do not replace
hands-on device, accessibility, performance, compatibility, or network tests.

## Prerequisites

- Flutter stable and the Dart version accepted by `pubspec.yaml`.
- JDK 17 and an Android SDK for the Android build.
- macOS with Xcode for the iOS build.
- Android and iOS test devices or simulators.
- A current-stable Jellyfin server with a dedicated test account.
- A deterministic library containing 2,000 movie or whole-series candidates.
- A trusted test proxy such as mitmproxy or Charles for traffic inspection.

Record the Flutter version, Jellyfin version, server capabilities, host OS,
device model, device OS, and artifact checksum with every verification run.

## Automated Linux And Android Checks

Run from the project root:

```bash
flutter pub get
tool/verify.sh
tool/build_android_debug.sh
```

`tool/verify.sh` checks generated localization, formatting, strict analysis,
unit/widget tests, aggregate line coverage, and runtime configuration. The
Android script produces:

- `build/app/outputs/flutter-apk/app-debug.apk`
- `build/app/outputs/flutter-apk/app-debug.apk.sha256`

The GitHub Actions workflow runs the same commands and uploads both coverage
and Android artifacts. It does not prove Android installation, device flows,
iOS behavior, integration coverage, or release acceptance.

## Android Release Workflow

`.github/workflows/release.yml` runs when a `v*` tag is pushed. To release
manually, open Actions → Release Android → Run workflow and select `main` (or
another release branch or existing tag). Manual branch runs derive the release
tag from `version:` in `pubspec.yaml` and target the selected commit when creating
the draft. Existing tags must point to that same commit; the workflow never
moves a tag. For example, `1.0.32+33` uses tag `v1.0.32`. Tag-triggered runs must
match that version, and the changelog must contain a nonempty dated entry for
it. Before each new release, increase both the version and build number and add
user-facing release notes to `CHANGELOG.md`.

Configure these repository Actions secrets before running a release. The
workflow checks them before installing build tools or running quality gates:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64 encoding of the release signing keystore file. |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password. |
| `ANDROID_KEY_ALIAS` | Signing key alias within the keystore. |
| `ANDROID_KEY_PASSWORD` | Signing key password. |

Use the existing distribution key if the app has already been distributed;
keep a secure backup for future updates. Follow Flutter's
[Android signing guide](https://docs.flutter.dev/deployment/android#sign-the-app)
to create a key when preparing the first release. Never commit a keystore or
password. Debug builds continue to use the development key. Local release builds
are unsigned unless all four `ANDROID_KEYSTORE_PATH`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`
environment variables are set; the path must be absolute. The workflow requires
all signing secrets and removes the temporary keystore after the build.

After committing the version and changelog updates, either run the workflow
manually on that branch, or tag that commit and push the tag (replace the
example with the new version):

```bash
git tag -a v1.0.32 -m 'Jellyfilter 1.0.32'
git push origin v1.0.32
```

The workflow runs the full quality gate, checks that generated localization is
committed, and builds a signed universal APK and Android App Bundle. A 30-day
Actions artifact and a draft GitHub release contain the versioned binaries,
`SHA256SUMS`, and notes extracted from the changelog. Download both binaries and
the checksum file into one directory and run `sha256sum --check SHA256SUMS`.

Install the release APK and complete the device checks below before publishing
the draft in GitHub. The AAB is provided for a separate Play Console upload;
this workflow does not upload to an app store or build/sign iOS. The draft uses
GitHub CLI's [`--draft` and `--target` options](https://cli.github.com/manual/gh_release_create),
with `--verify-tag` for runs on existing tags.
If release creation fails after leaving a partial draft, delete only that draft
and rerun the workflow on the same tag. Existing releases are never overwritten.

## Install And Launch

Install the Android artifact on an attached development device:

```bash
adb devices
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell monkey -p com.jellyfinpicker.jellyfin_picker 1
```

On macOS, build the iOS simulator application:

```bash
flutter build ios --debug --simulator
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted com.jellyfinpicker.jellyfinPicker
```

Use Xcode with a development team to produce and install a signed device build.
Archive the build log, artifact checksum, installation result, and first-launch
screenshot. Do not mark iOS verified from project configuration or a Linux run.

## P0 Device Matrix

Run every PRD P0 journey on Android and iOS. Capture a screen recording and a
timestamped result log covering:

- HTTPS connection, authentication, secure restore, logout, and reconnect.
- Rejected public HTTP, confirmed private-LAN HTTP, and rejected invalid TLS.
- Catalog paging, title search, recently-added sorting and 7/30/90/365-day
  windows, combined filters, loading, empty, partial, and error states.
- Quick recently-added, unwatched, and favorites filters; active-filter reset
  must preserve presets, likes, rejections, recent picks, and dismissals.
- Browse, swipe, and shuffle/reveal mode switching with shared session state.
- Browse grid and list layouts, including the wide-screen list columns, large
  text, and keeping the top title in view when switching.
- Like, reject, favorite add/remove, and watched-state non-mutation.
- Local state restart, named presets, recent picks, dismissals, and clear data.
- Missing optional Jellyfin fields and unsupported required capabilities.

Record failures as failures. A source inspection or widget test is supporting
evidence, not a substitute for these device journeys.

## Accessibility Evidence

For both platforms, retain screenshots and an accessibility hierarchy for the
smallest and largest supported phone sizes. Exercise portrait and landscape,
largest accessibility text, high contrast, and reduced motion. Verify semantic
labels, focus order, readable contrast, safe areas, and minimum touch targets.

## 2,000-Candidate Evidence

Use a deterministic fixture or test server that logs every request and returns
bounded pages. In a profile build, record:

- Time to the first usable page and every requested `StartIndex`/`Limit`.
- A scroll from the first page through later pages and back without gaps.
- Repeated swipe decisions, mode switches, and shuffle reveals.
- Frame timing and memory from Flutter DevTools during those interactions.
- A recording showing that interaction begins before all 2,000 items arrive.

Archive the fixture definition, server request log, DevTools timeline, memory
snapshot, and recording. Passing data-layer tests alone does not satisfy the UI
responsiveness requirement.

## Privacy And Network Evidence

Configure the device to use a trusted inspection proxy and clear its capture.
Exercise login, restore, catalog and image paging, every discovery mode,
persistence restart, favorite mutation, logout, and primary error paths. Export
the raw capture as HAR or the proxy-native format, then create a host summary.

The capture passes only when every remote request targets the configured
Jellyfin origin and no analytics, crash, credential, or discovery-history
traffic targets another service. Repeat the capture on Android and iOS. Redact
credentials and access tokens from shared evidence without removing host,
method, path, status, or timing fields.

Static dependency and source scans can support this result but cannot replace
the packet capture. Private-LAN HTTP must be tested only on an isolated test
network because its traffic is intentionally unencrypted after confirmation.

## Evidence Checklist

- Quality-gate log and `coverage/lcov.info`.
- Android and iOS artifacts, checksums, install logs, and launch screenshots.
- P0 result matrix and screen recordings for both platforms.
- Accessibility screenshots and hierarchies for both platforms.
- Exact Flutter, Jellyfin, device, and OS compatibility matrix.
- 2,000-item fixture, request log, performance timeline, and recording.
- Android and iOS traffic captures plus redacted host summaries.

Keep TASK-20.6 open until each acceptance criterion is backed by these fresh
artifacts. Never infer a device, iOS, performance, or privacy pass from CI.
