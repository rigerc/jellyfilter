# Changelog

## 1.0.29 — 2026-11-19

- Reduce suggested presets to a smaller, more useful set.
- Delete saved presets directly from the Presets tab.

## 1.0.28 — 2026-11-19

- Add more combined suggested presets in Filters → Presets, including Unwatched
  favorites, Short gems, Recent hits, Unwatched critics' picks, and Epic picks.

## 1.0.27 — 2026-11-19

- Add more advanced suggested presets in Filters → Presets, including Unwatched
  gems, New & unseen, Quick watch, and Critics' picks.

## 1.0.26 — 2026-11-19

- Start from handy suggested presets in the Filters → Presets tab, including
  Unwatched, Favorites, Added this month, Highly rated, and Under 2 hours.

## 1.0.25 — 2026-11-19

- Fix lag in libraries with many tags (Jellyfin often stores TMDb keywords as
  tags): the Content tab now shows your chosen tags plus the 30 most used,
  with a search box for the rest, instead of thousands of chips.
- Filtering is much faster: each title's tags and genres are prepared once,
  and filtered lists are computed once per change instead of once per view.

## 1.0.24 — 2026-11-19

- Reverse any directional sort (Title, Release year, Rating, Runtime, Recently
  added) from the header sort menu or the filter sheet.
- Filter by Jellyfin tags; titles must carry every tag you pick.
- Exclude genres, tags, decades, and content ratings: tap a filter chip once
  to require it, twice to exclude it, and again to clear it. Exclusions show
  as coral "Not …" chips above your titles.
- Tags edited from "Playlists & tags" apply to tag filters right away.

## 1.0.23 — 2026-11-19

- Fix Shuffle stalling with a favorites filter: liked titles only form the
  shortlist when some of them match the filters, and un-hearting the current
  pick keeps it on screen until the next spin.
- Sort Grid and Swipe from the header: Recommended, Recently added, Title,
  Release year, Community rating, or Runtime.
- Turn on "Fade watched" from the ⋯ menu to dim watched titles with a badge.
- Add titles to Jellyfin playlists (or create one) and edit Jellyfin tags:
  long-press a poster in Grid, or use the playlist button in Swipe, Shuffle,
  and the details sheet. Tag edits need a Jellyfin administrator.
- Redesigned details sheet: poster and score header, clear section headings,
  and Overview / Details / Trailers tabs.

## 1.0.22 — 2026-11-19

- Fix "Your library is unavailable" when opening Shuffle after every liked
  title had been shown recently; liked shortlists no longer exclude recent
  picks, and an exhausted random cycle starts over.
- An empty result for a narrowed Shuffle request now reads as "no titles fit",
  never as a library error.

## 1.0.21 — 2026-11-19

- Hearts respond instantly with a small pop and haptic tick, then confirm
  with Jellyfin in the background; a failed update flips back with a message.
- Rapid double taps on a heart now land on the right state without a
  spurious error.
- Background favorite refreshes and details loads can no longer undo a heart
  you just tapped.
- Smoother card dragging in Swipe, and fewer needless storage writes.

## 1.0.20 — 2026-11-19

- Keep favorites current: hearts you toggle no longer revert when more titles
  load, and favorites changed in other Jellyfin apps appear when you return
  to the app or switch modes.
- Opening a title's details also refreshes its favorite state everywhere.

## 1.0.19 — 2026-11-19

- Swipe like a dating app: cards follow your finger and tilt, LIKE and NOPE
  stamps fade in as you drag, a quick flick or a long drag sends the card
  flying, and a short drag springs it back.
- See the next titles waiting in a stack that rises into place as the top
  card leaves.
- Use round Nope, Details, and Like buttons; the one you are dragging toward
  fills in, with haptic feedback when a release will count.

## 1.0.18 — 2026-11-19

- Lean Shuffle toward your Jellyfin favorites with a "Favor favorites" slider:
  at 70%, at least seven in ten spins land on a favorite when one is
  available. The setting is remembered per server and user.

## 1.0.17 — 2026-11-19

- See every active filter as a chip above your titles in Grid, Swipe, and
  Shuffle; tap a chip to adjust filters, or its × to drop just that one.
- Clear all filters at once from the end of the chip strip.

## 1.0.16 — 2026-11-19

- Find filters faster in a tabbed sheet — Basics, Content, Ratings, and
  Presets — with flat, well-spaced groups instead of stacked cards.
- See how many choices are active on each tab and in the sheet header.
- Keep "Show matches" pinned at the bottom of the sheet on every tab.
- Pick watched and favorite states with one-tap Any / Yes / No toggles, and
  read runtime and rating thresholds at a glance beside each slider.
- Save presets from the filters you just set in the sheet, not only the ones
  already applied.
- Browse content ratings from youngest audience to oldest.

## 1.0.15 — 2026-11-19

- Spin Shuffle like a slot machine: the reel winds up, races through posters
  with motion blur and haptic ticks, then locks onto tonight's pick.
- Enjoy a new warm marquee look: charcoal surfaces with amber highlights
  replace the violet palette, including the app icon.
- Browse a roomier grid with poster-first tiles, title and year · runtime
  captions, and a lighter header that gives more space to your library.
- See a clear message in Shuffle when no titles are left to pick.
- Read the selected mode label clearly in the bottom bar in every system
  appearance.

## 1.0.14 — 2026-08-14

- Play trailers supplied by Jellyfin directly from movie details.
- Combine multiple genre choices to find movies that match every selection.
- Read controls clearly on dark purple surfaces in dark mode.
- See a helpful no-matches state when filters return no movies, while genuine
  library errors remain distinct.
- Find filters through the familiar filter icon and see Jellyfilter named in
  the discovery header.

## 1.0.13 — 2026-08-14

- Discover movies faster with personalized Jellyfin recommendations and
  bounded Surprise batches that avoid recent decisions.
- Focus exclusively on movies, choose an accessible movie library, and filter
  with choices supplied by your Jellyfin server.
- Browse large libraries sooner with incremental loading and full title details
  fetched only when opened.
- See smoother, correctly proportioned poster placeholders using Jellyfin image
  metadata while preserving fallback artwork.

## 1.0.12 — 2026-08-13

- Switch among Grid, Swipe, and Shuffle anytime from the persistent bottom
  menu.
- See more discovery titles at once with a compact header and live result
  count.
- Find Recently added, Unwatched, and Favorites together inside Filters while
  keeping active filters visible from discovery.

## 1.0.11 — 2026-08-13

- Explore Jellyfilter in its new Violet-to-Blue identity across both light and
  dark appearance modes.
- Enjoy clearer actions, filters, panels, highlights, and feedback with Deep
  Sea, Abyss, Net Teal, Jelly Lavender, and Jelly Blush accents.

## 1.0.10 — 2026-08-13

- Meet Jellyfilter, the new app identity with supplied jellyfish artwork across
  the launcher, home, discovery, search, and filter surfaces.
- Open a valid saved Jellyfin server directly into discovery instead of
  stopping at an extra connection summary.
- Keep the first-time connection, recovery, and logout paths intact while
  tightening product copy and image memory usage.

## 1.0.9 — 2026-08-13

- Fill tall Android screens with discovery titles instead of leaving unused
  space beneath the grid.

## 1.0.8 — 2026-08-13

- Keep discovery titles visible to the bottom of the screen instead of leaving
  a large blank area after filters or the keyboard close.

## 1.0.7 — 2026-08-13

- Remove the remaining empty space below title details, including on devices
  with a bottom system inset.

## 1.0.6 — 2026-08-13

- Prevent the title details sheet from covering the lower part of the screen
  with a blank overlay when its content is shorter than the viewport.

## 1.0.5 — 2026-08-13

- Keep the saved session available when Jellyfin rejects an expired token so
  re-authentication can recover without losing the connection state.
- Retry transient secure-storage reads to preserve saved sessions and stable
  device identity across keychain or keystore misses.

## 1.0.4 — 2026-08-12

- Sort discovery by recently added, or filter to titles added within 7, 30, 90,
  or 365 days.
- Search titles by name and combine with media type, runtime, ratings, genre,
  release period, watched, favorite, content rating, and series state.
- Recently added, unwatched, and favorites are one tap away as quick filters.
- Active filters reset cleanly without clearing presets or your discovery
  history.
- Filter, search, and sort choices carry across the grid, swipe, and shuffle
  views and survive restarting the app.

## 1.0.3 — 2026-08-11

- Filters are grouped into roomier sections that remain comfortable at large
  text sizes.
- Discovery opens with a more distinctive cinema-style header and a live title
  count.
- Posters appear sooner through tiny blurred previews before the sharper image
  fades in.
