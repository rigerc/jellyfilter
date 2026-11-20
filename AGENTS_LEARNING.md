# Agent Learning Log

This file is auto-maintained by AI agents as a self-improving mistake log.
Each iteration captures a concrete mistake, the pattern to avoid, and the better approach.
Do not edit past entries; append only.

---

## Agent Learning Log: Iteration #1

**Date**: 2026-08-14 | **Task**: Add safe Jellyfin trailers and correct discovery filters
**Signal**: Pre-write violation

### ❌ Mistake Made
The first `_trailers` parser draft in `jellyfin_catalog_repository.dart` force-unwrapped nullable trailer URIs after filtering, violating the active Dart null-safety rule.

### 🚫 Pattern to Avoid
- **No force unwraps in parsing pipelines**: Validation in an earlier collection stage does not give Dart sound promotion in later closures.

### ✅ Better Approach
Parse each untrusted trailer object through a typed nullable helper, return `null` for invalid values, and use `whereType<CatalogTrailer>()` to retain only validated results.

---

## Agent Learning Log: Iteration #2

**Date**: 2026-08-14 | **Task**: Add safe Jellyfin trailers and correct discovery filters
**Signal**: Pre-write violation

### ❌ Mistake Made
The first trailer-button label expression in `discovery_details_sheet.dart` force-unwrapped `trailer.name` after checking a derived nullable expression.

### 🚫 Pattern to Avoid
- **No repeated nullable property reads in display ternaries**: they encourage unnecessary force unwraps and obscure normalization.

### ✅ Better Approach
Normalize the nullable display value once in a helper and return the localized fallback when it is null or empty.

---

## Agent Learning Log: Iteration #3

**Date**: 2026-08-14 | **Task**: Add safe Jellyfin trailers and correct discovery filters
**Signal**: Session retrospective

### ❌ Mistake Made
The formatting command passed `AGENTS_LEARNING.md` to `dart format` alongside Dart source directories, producing an avoidable parser failure after the intended Dart files were formatted.

### 🚫 Pattern to Avoid
- **No mixed-language formatter targets**: Dart tooling treats Markdown as invalid source and turns a clean formatting step into a failing command.

### ✅ Better Approach
Pass only Dart files or Dart source directories to `dart format`; validate Markdown separately when a Markdown formatter is configured.


## 2026-11-19 — Jellyfin request optimization

Check query parameters against each endpoint's OpenAPI definition. Playlist
contents returns a total but does not accept the `enableTotalRecordCount`
parameter supported by `/Items`; do not copy request options between endpoints.


## 2026-11-19 — Discovery needs more than its first page

The API efficiency fix preserved 50-item pages but missed that Swipe never
requested another page and Shuffle could keep reusing its initial pool. Test
full catalog availability through app composition in every mode, not only
repository pagination. Show the first page immediately and continue loading
the remaining pages without requiring gestures or exhausted candidates.

## 2026-11-19 — Serialize Flutter builds and tests

Running the release build alongside the quality gate raced on the generated
Android plugin registrant: tests included `integration_test` while the release
Java compilation excluded that plugin. Run Flutter tests and Android builds
sequentially in the same checkout so generated plugin files stay consistent.

## 2026-11-20 — Manual releases should work from the default branch

Adding `workflow_dispatch` while rejecting all branch refs made the default
Run workflow action fail immediately. Support branch dispatch by deriving the
version tag from pubspec and targeting the selected commit. Validate signing
configuration before spending time on builds.

## Scoped stores with injected dependencies

The initial shortlist wiring eagerly constructed the SharedPreferences adapter
even when both stores were injected, which broke widget tests without a platform
plugin. Initialize platform-backed defaults lazily so injected stores stand alone.

The shared Shuffle placeholder still used filtered-catalog copy and exhaustion
state after switching sources. Verify the ready-to-spin state and its text
against the selected source, especially when the catalog has no matches.

The shortlist strip reduced Shuffle's available height enough to put Spin
below the fold on a standard test viewport. Check the primary action with
the persistent strip and active filter chips visible together.

CustomSemanticsAction is defined in Flutter's semantics library. Import it
explicitly when adding custom accessibility actions to Material widgets.
