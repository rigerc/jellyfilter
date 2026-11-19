# Agent notes for Jellyfilter

Jellyfilter is a Flutter (Dart 3.12, Material 3) Jellyfin discovery client for
Android and iOS. Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before moving
code between layers.

## Commands

```bash
flutter pub get
flutter gen-l10n     # after editing lib/l10n/app_en.arb; generated code is committed
dart format lib test tool
flutter analyze --fatal-infos --fatal-warnings
flutter test
tool/verify.sh       # full gate: gen-l10n, format, analyze, tests, coverage
```

Never pass Markdown or other non-Dart files to `dart format`.

## Conventions

- Keep the feature layering `presentation -> domain <- data`. `domain/` must not
  import Flutter, network, storage, or another feature.
- User-facing strings go through `AppLocalizations`; add keys to
  `lib/l10n/app_en.arb`, then run `flutter gen-l10n`.
- Give new interactive widgets a key in `lib/core/keys/widget_keys.dart` so tests
  can find them without matching on text.
- No force unwraps on parsed or untrusted Jellyfin data. Validate through typed
  nullable helpers and filter with `whereType<T>()`.
- Prefer guard clauses and early returns over nested conditionals.
- Honor `MediaQuery.disableAnimationsOf(context)` in any new animation.
- Every release bumps `version:` in `pubspec.yaml` and adds a `CHANGELOG.md`
  entry written in plain user-facing sentences.

## Testing

- Tests mirror `lib/` under `test/`; shared fakes and robots live in
  `test/shared/`.
- Keep tests deterministic: no real network, and no assertions on timings.
  Benchmarks that measure milliseconds belong in a throwaway script, not the
  suite.

## Lessons

Record agent mistakes in [AGENTS_LEARNING.md](AGENTS_LEARNING.md). Append only;
never rewrite past entries.
