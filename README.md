<p align="center">
  <img src="docs/icons/app-icon.png" width="96" alt="Jellyfilter app icon">
</p>

<h1 align="center">Jellyfilter</h1>

<p align="center">A Jellyfin discovery companion that helps you decide what to watch tonight.</p>

<p align="center">
  <a href="https://github.com/rigerc/jellyfilter/actions/workflows/android-ci.yml"><img src="https://github.com/rigerc/jellyfilter/actions/workflows/android-ci.yml/badge.svg" alt="Android CI"></a>
</p>

Jellyfilter signs in to your Jellyfin server and turns a large library into
something you can decide on in a few taps: a poster grid, a swipe deck, and a
slot-machine shuffle. Filters, favorites, and playlists all talk to Jellyfin
directly, so what you pick here is what you find there.

## Features

**Three ways to pick**

- **Grid** — poster-first tiles with title, year, and runtime; sort by
  recommended, recently added, title, release year, community rating, or
  runtime, in either direction.
- **Swipe** — a deck of cards that follow your finger and tilt, with LIKE and
  NOPE stamps, a flick to send a card flying, and a stack of what is coming
  next.
- **Shuffle** — a slot-machine reel that winds up, blurs through posters, and
  locks onto one pick. A "Favor favorites" slider tunes how often it leans
  toward titles you already love.

**Filters that fit a real library**

- Genres, Jellyfin tags, decades, content ratings, runtime, community rating,
  and watched or favorite state.
- Tap a chip once to require it, twice to exclude it; the same choice works for
  genres, tags, decades, and ratings.
- A tabbed sheet (Basics, Content, Ratings, Presets) with active-choice counts,
  plus a strip of active-filter chips above your titles.
- Tag lists are capped at your chosen tags plus the most used ones, with a
  search box, so libraries that carry thousands of TMDb keywords as tags stay
  responsive.
- Save the filters you just set as a preset.

**Details and library actions**

- A details sheet with a poster header, score, and Overview, Details, and
  Trailers tabs.
- Jellyfin trailers play in the app.
- Add a title to a Jellyfin playlist, or edit its tags, from the grid, the
  deck, or the details sheet. Tag editing needs a Jellyfin administrator.
- Hearts update instantly with a pop and a haptic tick, then confirm with the
  server in the background.

**Built to be pleasant**

- Charcoal and amber marquee palette, and a matching app icon.
- Reduce-motion and accessible-navigation settings are honored: the reel and
  card animations collapse instead of playing.
- Configuration lives on the device; nothing is sent anywhere but the Jellyfin
  server you sign in to.

## Requirements

- A Jellyfin server, current stable, with an account for the app.
- Android 8.0 (API 26) or later, or iOS via Xcode.
- Flutter stable with Dart 3.12 or later, JDK 17, and the Android SDK for
  development.

## Getting started

```bash
flutter pub get
flutter gen-l10n
flutter run
```

On first launch, enter your server URL and sign in. To skip the connection
screen during development, pass the URL at build time instead of committing it:

```bash
flutter run --dart-define=JELLYFIN_SERVER_URL=https://jellyfin.example
```

## Quality gates

```bash
tool/verify.sh              # gen-l10n, format check, analyze, tests, 80% coverage gate
tool/build_android_debug.sh # checksummed Android debug APK
```

CI runs the same checks on Linux and compiles the Android debug APK. It does not
replace installation on a device, accessibility, performance, or compatibility
checks against your own server; follow
[Release Verification](docs/RELEASE_VERIFICATION.md) for that evidence.

## Project layout

```text
lib/
  app.dart          app composition, routes, and dependency wiring
  core/             cross-cutting contracts, theme, media models, widget keys
  features/
    catalog/        Jellyfin library reads and mapping to neutral media models
    connection/     server sign-in and session handling
    discovery/      grid, swipe, shuffle, filters, and details
    favorites/      favorite state and syncing
    persistence/    on-device storage for settings and discovery state
  l10n/             ARB strings and generated localizations
```

Each feature owns `presentation -> domain <- data`, and `domain/` stays free of
Flutter and network imports. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
for the dependency rules.

## Network and privacy

HTTPS is used everywhere it is available. Cleartext HTTP is accepted only for
private-LAN addresses, and the app rejects public HTTP before any request is
made; invalid TLS certificates are never bypassed. Android builds disable
backup (`allowBackup=false`), and iOS asks for local-network access with an
explanatory usage string.

## Releases

Version history lives in [CHANGELOG.md](CHANGELOG.md). Release builds are signed
locally and verified on a device before distribution.
