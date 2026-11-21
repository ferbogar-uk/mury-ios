# iOS App — Status Log

Chronological build history in commit order. For "what it looks like now" read
`ARCHITECTURE.md`; this file is "how it got here" and the reasoning behind
non-obvious fixes. `git log --oneline` for exact diffs.

## Pre-refactor era (API-backed, all since superseded)

Commits `4d45766`→`7674b43` built the original **server-backed** app: auth
(login/register + JWT session), `APIClient`/`SessionStore`, activity
list/detail against the NestJS API, S3 cover-photo upload, background
recording, an offline retry queue (`PendingActivityQueue`), Stats tab, GPX
import, and the share feature. Notable root-cause fixes preserved for context:

- `cc7209a` — `UIBackgroundModes` is array-typed and `INFOPLIST_KEY_*`
  doesn't synthesize it → explicit merged `Info.plist` +
  `PBXFileSystemSynchronizedBuildFileExceptionSet`. (Still applies today.)
- `18cae6f` — client-only `id` field inside a request body was 400-rejected
  by the backend's `forbidNonWhitelisted` ValidationPipe → keep local-only
  fields out of network request types. (Moot now — no networking.)

## `d40a648` — Offline-first rewrite: SwiftData, zero API

The pivot. Removed `APIClient`, `APIError`, `KeychainStore`, `UploadService`,
`SessionStore`, `Auth/Upload/User` models, `PendingActivityQueue`,
`LoginView`, `RegisterView`. Added SwiftData `CDActivity`/`CDTrackPoint`,
`.modelContainer` wiring, and rewrote `ActivitiesStore` as local CRUD.
`RecordView` **auto-saves on finish** (no form/discard). Dropped cover photos
and the visibility picker. `ProfileView` became local (`@AppStorage`).
`Accent`/`AccentColor` made adaptive monochrome.

## `aa3b310` — Share card: "LARPING <sport>" header

Icon-left-of-title header, repo URL footer. (Layout superseded by `88cb77e`;
the LARPING prefix + footer stuck.)

## `8919504` — Backup export + docs rewritten

`BackupService.backupFile` → system `fileExporter` (saves to Files / iCloud
Drive). All docs rewritten to the offline-first reality.

## `90efbe9` — Backup import/restore + share layout tweaks

`BackupService.restore` (idempotent, skips existing ids, rejects junk) +
Profile "Import backup" with confirmation dialog. Share: no endpoint dots,
icon aligned to title line, stats as one column, footer raised above the IG
reply bar; share view renders plain background on open, Camera|Gallery row +
plain-bg link + share button.

## `c2d307a` — Monochrome button contrast, icon stretch fix

Default Apple-contrast failed on white accent → prominent button labels forced
`Color.canvas`. Share icon was stretched into a square box → aspect-preserved.
Record map stopped ignoring top safe area at the time. Domine font embedded
as base64 for the share overlay.

## `60e8ca0` — Drop Domine, fix destructive text, location button to header

Domine removed (SDK's synced group won't bundle `.ttf`; system font instead).
**Destructive Finish buttons keep native red+white text** (no `Color.canvas`
override — that made black text on red). Record map restored to full-bleed
top; the default `MapUserLocationButton` dropped for a
toolbar top-trailing "location" button aligned with the nav bar. Route drawn
into an **aspect-matched box centered** in the share area (symmetric margins
for any route size).

## `68cdc77` — Seed sample data + remove duplicate location button

`SeedData` seeds one-time sample activities (7, all sports, last-7-days,
random-walk loop paths) guarded by the `seedSampleDataV1` UserDefaults flag —
never re-seeds after the user deletes everything. Removed the leftover default
`MapUserLocationButton` (was double with the toolbar one).

## `88cb77e` — Bolder stat tiles, organic seed paths, share header on top

- `ActivityDetailView` stat values: `.title3.monospacedDigit().bold()`.
- Seed paths: random-walk (drifting heading, steered to center), not circles.
- Share header: **big centered sport icon on top**, smaller "LARPING <SPORT>"
  (54 heavy) + date beneath it.
- Share pace value loses the redundant ` /km` (speed sports keep `km/h`);
  the strip lives in `ShareActivityView.stats`.

## Uncommitted — Event names, live profile cover, redesigned share templates

A broad UX pass across Record / Profile / Share / Detail:

- **Event names.** `CDActivity.eventName` (optional `String` — lightweight
  migration; also round-trips through backups). `RecordView` auto-fills the
  field as `Larping <Sport>` and bumps to `… 1`, `… 2` whenever that exact name
  already exists (`EventNamer.nextName(base:existing:)` — matching titles only,
  non-numeric suffixes ignored). Blank field → auto name at save time. Share
  cards and the detail hero use the event title with **casing preserved**
  instead of a forced "LARPING <SPORT>".
- **Profile** became a cover banner: accent→black gradient (or user photo via
  PhotosPicker, persisted to `Documents/profile-cover.jpg`) with the avatar/
  name/bio over a dark scrim, the horizontal wordmark small at top-leading
  (black in dark mode on the lime accent, white in light — a translucent chip
  backs it when a photo is set), animated bouncing avatar. The appearance
  segmented picker was replaced by an icon+label control
  (System/Light/Dark, `AppearanceMode.symbolName`). The "About" section is
  gone; a small "Larping vX.Y (N)" footer sits bottom-centered (from
  `CFBundleShortVersionString`).
- **Share templates reworked.** Classic card with no photo exports a
  **transparent PNG** (white content + dark shadows → pasteable anywhere).
  The map template flipped its layout: full-canvas map snapshot as the
  *background* (dimmed + bottom scrim), route overlaid, and a bottom
  info-card holding title/date/stats/logo/URL. The **video** renders the same
  map design: one snapshot fetched once, then
  `composeMapCard(...routeRevealFraction:)` per frame — no per-frame tile
  fetches. Video lives in `temporaryDirectory` and is **deleted on sheet
  dismiss** (must save/share right away). Previews are bigger and tap to
  open full-screen; camera/gallery sit *below* the Share button so swiping
  templates doesn't reshuffle controls.
- **Detail map** is now a hero: taller route map with the title/date overlaid
  on a scrim and a bouncing sport-symbol rider at the draw tip.
- Icons animate in place via `symbolEffect(.bounce)` (run/cycle/walk glyphs
  — no GIFs needed): profile avatar, record header while recording, detail
  map rider.

Root causes worth remembering:
- Map-bg video must fetch the snapshot once, not per frame (the old video used
  the non-map composer; a per-frame map would be ~360 tile fetches per export).
- Full-bleed map drawing stays aligned because the snapshot is requested at
  `canvasSize`, making `MKMapSnapshotter.point(for:)` a 1:1 canvas mapping.

### Follow-up pass — fixed items an earlier attempt at this same work skipped

- **Profile cover overlap bug.** The wordmark chip and the name/bio block were
  each independently bottom-pinned inside the `ZStack` with their own fixed
  `.padding(.bottom, ...)` — on a short bio they landed ~8pt into each other.
  Rebuilt as one `VStack` (`Spacer()` + info + logo row) so the logo can never
  overlap the info block regardless of content length. Scrim changed from
  top-`.clear`→bottom-black to a 3-stop gradient that darkens the *whole*
  cover, so the accent-gradient fallback (no photo set) never shows a patch of
  raw, undimmed lime/blue.
- **Appearance picker** — bigger icon (17→22pt), label (`.caption`→
  `.subheadline`), padding, and corner radius.
- **Activities toolbar circle.** A bare `Image` in `.topBarLeading` picks up
  iOS's "glass" toolbar chip background by default, making the wordmark look
  like an accidental button. Fix: drop the "Activities" title text and use the
  wordmark as the `.principal` toolbar item instead (no leading slot at all).
- **Record map had no rider.** Swapped the default `UserAnnotation()` for a
  sport-icon marker at the live route's last coordinate whenever
  `tracker.state != .idle` (falls back to the blue dot before a route exists)
  — same visual language as the detail-view rider.
- **Detail view: route line lagging the rider marker.** Both were driven by
  the same `revealedCount` each `TimelineView` tick, but MapKit implicitly
  animates polyline geometry changes while the annotation snaps immediately —
  so the marker visibly ran ahead and the line caught up after the fact.
  Fixed with `.animation(nil, value: revealedCount)` on the `Map`.
  Also moved event title + date to the hero map's bottom-right (previously
  empty) with the sport icon alone bottom-left, instead of a single merged
  label crowding one corner.
- **Delete UX.** Was a plain destructive-red link floating below the stat
  grid — reads as the most prominent thing on the screen the moment you open
  an activity. Moved into the toolbar's `ellipsis.circle` overflow menu
  alongside Share (a deliberate extra tap before anything destructive is even
  visible); the confirmation dialog now names the activity being deleted.
- **Share: wordmark barely visible.** Classic template: wordmark moved from a
  small 44pt footer mark (buried below three stat rows) to directly under the
  sport icon at 56pt, using a running `cursorY` layout so title/date/route
  shift down to make room. Map template: wordmark moved out of the info card
  entirely to float top-right over the map itself at 52pt with a dark
  backing (was 30pt, inline in the card, easy to miss); the repo URL stays in
  the card.
- **Share: transparent classic card invisible in light mode.** The photo-less
  card is intentionally a transparent PNG (white content) — previewed
  directly on the sheet's background, it disappeared entirely in light mode.
  Preview now sits on a black backing (preview-only; the actual composed/
  shared/saved image is unchanged, still transparent).
- **Share preview area enlarged** 560pt → 640pt across all three templates
  (was the same complaint for all of them, not just video — one shared
  `TabView` height, so one fix covers all three).

### Follow-up pass 2 — profile card felt like a literal cover photo, record polish, rename

- **Profile card overcorrected.** The first pass's 330pt banner still read as
  a literal "cover photo" hero. Shrunk to a 170pt wide card (avatar 72→46pt,
  no `symbolEffect` bounce — a constantly-animating icon on a settings-ish
  screen read as anxiety-inducing, not lively), wordmark moved to
  bottom-center at 14pt, and the camera/remove-cover button moved to a small
  top-trailing circle now that the bottom is reserved for the centered
  wordmark.
- **Appearance picker shrunk back down.** Icon+label stacked in a `VStack`
  made each option a big square tile. Changed to icon-left/label-right in an
  `HStack` (13pt icon, footnote text, 8pt vertical padding) — reads as a
  compact segmented control, not three large buttons.
- **Rename event.** `ActivitiesStore.rename(_:to:)` (trims, empty → nil so it
  falls back to the auto name) + an alert with a `TextField` from the detail
  view's overflow menu, alongside Share/Delete.
- **Record bottom control card.** `UnevenRoundedRectangle(topLeadingRadius:
  topTrailingRadius:)` so only the top corners round (matches the sheet/card
  language used everywhere else instead of a hard-edged bar). Background is
  solid `Color.black` in dark mode instead of `.thinMaterial` (which reads as
  translucent gray over the map) — light mode keeps `.thinMaterial`. The
  idle sport-picker + event-name row is bigger (14pt padding, 14pt corner
  radius, matching the appearance-toggle/card radius language) and the event
  field is now **required** — trimmed-empty blocks Start (with an inline
  hint), not just an auto-filled suggestion you could clear before hitting
  Start.

### Follow-up pass 3 — floating record card, cover-photo removal, real animation fix, richer Activities/Stats

- **Record bottom card floats over the map.** Was top-corners-only,
  edge-to-edge. Changed to a full `RoundedRectangle` with horizontal + bottom
  margins so it visually floats above the map, matching the already-
  transparent nav bar.
- **Profile cover-photo upload removed entirely.** No more `PhotosPicker`,
  `coverImage`/`coverPickerItem` state, `Documents/profile-cover.jpg`
  read/write, or camera/remove buttons — the cover is always the fixed
  accent→black gradient + scrim. The horizontal wordmark moved from
  bottom-center to top-trailing (where the camera button sat) and is now
  hardcoded `.foregroundStyle(.white)` for both light and dark mode, since
  the cover no longer changes color per photo/appearance.
- **Route-draw animation, actually fixed this time.** The prior
  `.animation(nil, value: revealedCount)` fix (pass 1) didn't address the
  real cause: `TimelineView(.animation(paused:))` ticks at ~60fps by default,
  and `MapPolyline`'s overlay reconciliation is too slow to keep up — so the
  line stayed visually static and only appeared, fully drawn, the instant
  ticking stopped (right as the lightweight `Annotation` marker, which only
  repositions and doesn't hit this bottleneck, had already reached the end).
  Fixed by throttling the schedule to `minimumInterval: 1.0/12.0`, giving
  MapKit time to actually apply each polyline update between ticks so the
  line now visibly draws in step with the marker.
- **Activities list enriched.** A "This week" distance/time/count strip sits
  above the list; activities are grouped into month `Section`s instead of one
  flat list; row titles now show the event name (falls back to sport label),
  matching Detail/Share.
- **Stats enriched.** Per-sport rows now show total time and activity count
  alongside distance. Added all-time totals (distance/time/count) and a
  "Personal bests" section (longest single-activity distance, longest
  single-activity duration).

### Follow-up pass 4 — Record card overlay, classic/map share template cleanup

- **Record bottom card is a translucent overlay, not solid black.** Dark mode
  background changed to `Color.black.opacity(0.75)` (was fully opaque) so the
  map shows through faintly while the form stays legible.
- **Classic share template dropped the event title.** The date moved into
  the footer at the same size/position the repo URL used to occupy, and the
  URL text itself was removed. The route's available area grew (504..970 vs
  580..970) to use the vertical space freed by removing the header's
  title/date block.
- **Map share template: icon moved top-left over the map** (mirroring the
  wordmark's top-right placement) so the info card's title/date can sit flush
  left instead of indented past an icon. The card's repo-URL footer was
  removed and its height shrunk from a fixed 580 (leaving empty space below
  the stats row) to 380, sized to its actual content. Card background alpha
  dropped 0.72→0.5 (was reading too dark) and corner radius bumped 32→48 to
  match the Record card's roundedness.

### Follow-up pass 5 — marker consistency, Record nav tint, share template polish

- **Sport marker icon color fixed for dark mode.** The accent background is
  lime in dark mode, so a white icon on top had poor contrast — icon color is
  now `colorScheme == .dark ? .black : .white`. Applied to both the live
  Record marker and Activity Detail's `RouteMap` marker, which also switched
  its background from a static `.black.opacity(0.6)` to `.accent` to match
  Record exactly.
- **Record's nav bar now tints black in dark mode** via
  `.toolbarBackground(Color.black.opacity(0.75), for: .navigationBar)` +
  `.toolbarColorScheme(.dark, for: .navigationBar)` (dark mode only) so the
  liquid-glass bar matches the black card overlay below it instead of
  rendering a mismatched light glass. Light mode is untouched.
- **Classic share template: icon/logo proportions reversed.** Icon shrunk
  230→130pt, wordmark grown 56→110pt (logo is now the dominant element), and
  header start `cursorY` moved 110→190 for more top clearance when shared to
  Instagram Story (avoids the profile chip/close button overlay).
- **Map share template date text matches the classic footer's style** (32pt
  @0.8 alpha → 30pt @0.72 alpha). The card's separator line was removed
  entirely (no `drawCardDivider` call left; the now-unused function was
  deleted) for a cleaner look. The top-right logo and top-left icon both
  moved down (`y: 90` → `y: 170`) so Instagram Story's own overlay doesn't
  cover them.
- **Map share template gets start/finish markers.** `drawRoute(onto
  snapshot:...)` now draws a small white-outlined badge with a flag glyph at
  the route's first and last points once the route is fully revealed (static
  image / finished state only — the video's in-progress leading dot is
  unchanged).
- **Apple Maps attribution cannot be hidden.** Apple's MapKit terms require
  the logo/legal attribution to stay visible on any map view; there is no
  compliant API to remove it, so this was intentionally left as-is (see
  `docs/KNOWN_ISSUES.md`).

## `(pending)` — Record correctness pass: product name, fetch cap, GPS + pause feedback

- **Product-name fix.** Location permission strings said "LarpingRun"
  (old working title) — all four `INFOPLIST_KEY_NSLocation*UsageDescription`
  values in both Debug/Release build configs now say "Larping".
- **ActivitiesStore fetch cap raised.** `refresh()` was capped at 50 most-
  recent activities, silently dropping older ones from the Record history
  heatmap. Now 500 — bounded enough to keep the heatmap from piling up
  hundreds of routes while covering realistic activity counts. (The
  Activity list itself never had this problem — it's `@Query`-driven.)
- **GPS-degraded feedback.** `LocationTracker` used to silently drop points
  with `horizontalAccuracy >= 50` (or invalid) while recording. New
  `isGPSDegraded` flag (set per received fix, reset on `start()`) drives a
  small warning-colored "GPS signal weak" note under Record's stat row —
  recording behavior unchanged, no fabricated points.
- **Pause is now visually distinct.** Pausing keeps the existing card/layout
  but the header sport icon drops to `.secondary` (bounce stops) and a red
  `PAUSED` capsule appears next to it.

## `(pending)` — HealthKit write (optional workout export)

- **New `Core/Health/HealthKitService.swift`.** Single flat `enum` (matches
  `BackupService`/`GPXParser` shape) with availability check, share-auth
  request, and `saveWorkout(from:)`. Writes an `HKWorkout` (sport mapped via
  `HKWorkoutActivityType(sport:)`, duration, GPS distance) and attaches the
  route polyline via `HKWorkoutRouteBuilder.insertRouteData` +
  `finishRoute(with:)`. Route samples re-report accuracy at the recorder's
  accepted 50m ceiling (honest — never overstated). Active energy not written:
  Larping's calorie figure is a crude formula, not measured data.
- **Project config.** `com.apple.HealthKit` in target `SystemCapabilities`,
  new `larping/larping.entitlements` (`com.apple.developer.healthkit`,
  referenced by `CODE_SIGN_ENTITLEMENTS`, added to the synced-group
  `membershipExceptions` like `Info.plist`), and
  `INFOPLIST_KEY_NSHealthShare/UpdateUsageDescription` build settings for
  scalar-key security copy. `import HealthKit` auto-links; no pbxproj
  framework phase needed.
- **Profile "Health" section** (shown only when
  `HKHealthStore.isHealthDataAvailable()`) with an opt-in
  "Allow HealthKit access" button; reflecting on re-appear.
- **Record Finish hook.** The local SwiftData save happens first and
  unconditionally; only after it succeeds does a fire-and-forget
  `Task { await HealthKitService.saveWorkout(from: activity) }` mirror the
  workout. HealthKit denial/absence/failure never blocks or loses a
  recording.
- No data-model schema change (no stored active-energy field — not needed for
  an energy-less write).

## `(pending)` — HealthKit read / import (Watch workouts into Larping)

- **`HealthKitService` read side.** `fetchRecentWorkouts(limit:)`,
  `fetchRoute(for:)` (HKSampleQuery for `HKWorkoutRoute` + `HKWorkoutRouteQuery`,
  continuation-based), `heartRateSamples(for:)` (windowed HKSampleQuery,
  gated on read auth). `requestAuthorization` now also requests read for
  workouts/routes/heart-rate. `SportType(workoutActivityType:)` back-maps
  Apple's activity types (unknown types → `.other`).
- **`ImportHealthKitView`** mirrors `ImportGPXView`: newest workouts list,
  sport-type override picker, summary, single Import action. Route polyline →
  track points (`source: "healthkit_import"`), heart rate merged onto the
  nearest point at-or-before its timestamp (`heartRateBpm` finally populated
  for Watch-recorded activities); distance prefers `HKWorkout.totalDistance`
  else route sum; elevation/max speed from route. No route/HR → imports
  metadata-only. Graceful paths: unavailable (menu entry hidden), denied
  (explanation + Open Settings), empty store (`ContentUnavailableView`).
- **Activities toolbar** became an Import `Menu` (GPX + HealthKit) — GPX
  import itself unchanged.
- Import goes through the existing `ActivitiesStore.create` path, so backups,
  rename, share, stats all work identically.

## `(pending)` — Heart-rate display, backup timestamp, GPX sport autodetect

- **Heart-rate stats finally visible.** Imported HealthKit activities carry
  HR samples but nothing displayed them. `CDActivity` gains `@Transient`
  `maxHeartRateBpm`/`averageHeartRateBpm` (derived from track points);
  `ActivityDetailView` shows Avg HR / Max HR stat tiles when present; Stats
  adds per-sport "max N bpm" and a "Highest heart rate" personal best. Live
  iPhone recordings still have no HR — tiles just stay hidden (nil).
- **Last-backup timestamp.** Profile stamps `@AppStorage("lastBackupDate")`
  on every successful export and import and shows "Last backup: …" in the
  Backup section — a cheap answer to "when did I last back up?".
- **GPX sport auto-detect.** `GPXParser` captures the `<type>` element;
  `sportType(from:)` maps it (case-insensitive substring: run/cycl/rid/bike/
  walk/hik/trail/swim; unknown → nil). `ImportGPXView` pre-selects the
  detected sport when parsing a file, overriding the `.run` default.
  Substring order matters: "trail run" counts as Run (run checked before
  trail), "Cycling_Sport"→Ride. Covered by two new `GPXParserTests`.

## `(pending)` — Splash screen + immersive Record tab

- **Animated splash.** `SplashView` (Features/Root) overlays the app on
  launch: `LogoHorizontal` wordmark over `Color.canvas`, tinted white in dark
  mode / black in light mode via `colorScheme` (the template asset recolors —
  no new PNGs). `larpingApp` fades it out after ~1.4s. The static launch
  screen previously flashed system white/black ahead of the app; the explicit
  `Info.plist` now sets `UILaunchScreen` with `UIColorName = Canvas` so the
  pre-SwiftUI phase matches the splash in both modes — seamless handoff.
- **Record's dark overlay moved from top nav to bottom tab bar.** The old
  `toolbarBackground(Color.black.opacity(0.75), for: .navigationBar)` +
  dark scheme made the Record nav bar a black strip over the map. Removed —
  the top is now transparent full-bleed (no title, recenter button remains
  top-trailing). The same black overlay is re-applied to the bottom **tab
  bar**, scoped with `.toolbarBackground(…, for: .tabBar)` from Record's own
  view, so in dark mode the map + bottom control card + tab bar read as one
  dark block. Other tabs keep the default liquid-glass tab bar untouched.
  Light mode unchanged (automatic).

## `(pending)` — Active duration fix (pause no longer inflates duration/pace)

Root cause: `LocationTracker.stop()` stored `endedAt - startedAt` (wall clock),
so pausing inflated `durationSeconds`, average pace, and average speed.
The on-screen timer was already pause-aware, but as a separate `@State`
`elapsedSeconds` in `RecordView` — two clocks, one right and one wrong.

Fix keeps active-duration state in the session logic (`LocationTracker`), not
the UI:
- `LocationTracker` now owns the clock: `activeTime` (sub-second-precise
  `TimeInterval`) accumulated per recording interval at start/pause/resume/
  finish boundaries, plus `elapsedSeconds` (whole-second view) driving the
  on-screen timer via its own 1s tick. `startedAt`/`endedAt` remain real
  wall-clock timestamps.
- `Recording` gains `activeDurationSeconds` + `durationSeconds` (Int).
  `RecordView`'s own timer is gone — the tracker is the single source of
  truth for both display and persistence.
- `durationSeconds` stored = `activeTime` floored; `averageSpeedMps` divides
  distance by `activeDurationSeconds` (guarded `> 0.5s` for near-zero
  recordings). Distance, elevation, calories unchanged; GPX/HealthKit import
  paths untouched (GPX has no pause concept; HealthKit uses Apple's own
  active duration).
- Injectable `currentDate` clock seam (default `Date()`) lets tests drive
  start/pause/resume/finish deterministically — no real sleeps.

New `LocationTrackerTests` (fake clock, `@MainActor`): no pause, single
pause (the 10'/20'/10' example → active 20'), multiple pause/resume
accumulation, finish-while-paused, finish-while-recording, near-zero
duration safety, and `elapsedSeconds` tracking.

## `(pending)` — CI: UI test "operation never finished bootstrapping" crash

GitHub Actions UI test run died with `Early unexpected exit, operation never
finished bootstrapping` before the test runner connected. Root cause: the Test
step let `xcodebuild test` boot the simulator lazily and launch the runner
before CoreSimulator was fully ready (a known flake on `macos-latest` fresh
VMs). Fix in `.github/workflows/ci.yml`: a `Prepare Simulator` step that
`simctl shutdown all`, boots the target device, then `simctl bootstatus -b`
(blocks until boot completes) before running tests. Note that dropping the
proposed `erase all` step is by design — each GitHub Actions job runs on a
pristine VM, so there are no stale devices to erase; hardcoded
`SimDeviceType`/`SimRuntime` ids are the real flake risk (they differ per
Xcode image) and were left out.

## Tech-debt pass: backup/save correctness, stats cap, store tests

Four silent-failure / correctness issues fixed in one pass:

- **Backup export capped at 2000 + `try?` swallowed errors.** `BackupService
  .backupFile` silently fetched at most 2000 activities (the "Export all"
  button was a lie past 2000) and silently fell back to an empty list on any
  SwiftData fetch failure — the user would see "backup exported" with zero
  data in it, the only off-device copy of their activities. Removed the
  fetch limit entirely and changed to `try` so errors propagate to the
  Profile export UI instead of masquerading as success.
- **Backup re-import duplicate-on-failure bug.** `restore` built the
  idempotency set of existing activity IDs with `(try? ...)?.map(...)` — if
  the SwiftData fetch failed, the set was treated as empty, causing every
  activity in the backup to be re-imported as duplicates. Changed to `try`
  so a failure aborts the import and surfaces the error to the user instead
  of silently duplicating every record.
- **Auto-save-on-finish swallowed SwiftData save errors.** `ActivitiesStore
  .create` called `try? modelContext.save()`. On a save failure (disk full,
  corrupt store, migration gone wrong) the activity was inserted into the
  in-memory `activities` array and a "saved" alert shown — but the data
  never persisted, so it vanished on next launch; meanwhile a HealthKit
  workout was still written for the phantom activity. `create` now `throws`;
  only the in-memory insert runs after a confirmed save. All three callers
  (Record finish, GPX import, HealthKit import) wrap the call in `do/catch`
  and surface errors to the user instead of silently reporting success.
- **Stats "All time" silently capped at 500 activities.** `ActivitiesStore
  .refresh()` capped `activities` at 500 for the Record heatmap, but
  `StatsView` uses the same array for all-time totals and personal-best
  computations — silently wrong past 500 activities. Removed the cap from
  the store; the heatmap now slices `activities.prefix(500)` itself, leaving
  Stats to see the full dataset.
- **ActivitiesStoreTests added** covering create-persists, rename, delete,
  and the all-time-uncapped refresh behavior. Saved the heatmap
  `DateFormatter` as a static let in `ActivitiesListView` to avoid
  re-creating it on every body evaluation. Fixed a stale doc comment in
  `HealthKitService` that claimed the read/import side "is deliberately not
  here yet" — it's been there since the HealthKit import pass.

## Tech-debt pass 2: persistence error propagation

Second persistence-correctness pass, extending the first (`create` throws) to
every user-visible persistent op. Principle: **a persistence failure must
never present as a successful mutation**, and an uncommitted (pending) state
must never survive a failed save to be committed later by an unrelated one.

- **`ActivitiesStore.rename`/`delete` no longer swallow save failures.** Both
  used `try? modelContext.save()` — renaming the event in memory / removing
  it from `activities` even when the save failed, so the UI showed a success
  that reverted on next launch. Both now `throws`: rename reverts the
  in-memory name on failure; delete rolls the pending delete back out of the
  context. `ActivityDetailView` surfaces both ("Couldn't save changes" alert)
  and no longer dismisses on a failed delete.
- **`create` now rolls back uncommitted inserts on save failure.** The first
  pass made `create` throw, but a failed save left the new activity *pending
  in the context* — absent from `store.activities`, yet visible in the
  `@Query` list and committed by any later unrelated save. `create` now
  `modelContext.rollback()`s on failure, leaving zero trace.
- **`BackupService.restore` is atomic / all-or-nothing.** A save failure
  previously left every inserted backup activity pending in the context: the
  error surfaced (pass 1) but the partial import stuck around and could be
  committed by a later save. Restore now `rollback()`s the whole uncommitted
  import — the store is left exactly as it was, so re-importing after fixing
  the cause is clean. Also guards against malformed backups listing the same
  activity id twice (only the first occurrence imports, the rest count as
  skipped).
- **Last user-visible persistence `try?` removed.** `RecordView
  .suggestedEventName` replaced a raw `modelContext.fetch` (`try?` → empty on
  failure → could suggest an already-used name) with the already-loaded
  `activitiesStore.activities`.
- **Track-point "duplication on reimport" investigated → not a bug.**
  Idempotency keys on **activity** ids and delete cascades free an activity's
  point ids, so re-importing a backup after deleting an imported activity
  revives it (activity + points) exactly once — never as duplicates. The only
  path that regenerates ids (`create`, for live/GPX/HealthKit import) is off
  the restore path entirely. See `docs/KNOWN_ISSUES.md`.
- **Test seams, not a DI framework.** `ActivitiesStore.persistOperation`
  (nil → real save) and the defaulted `BackupService.restore(persist:)`
  parameter (default → real save) let tests force a save failure with a plain
  in-memory container.
- **Tests added.** ActivitiesStoreTests: create-rollback leaves zero rows in
  a fresh `ModelContext`; failed rename keeps the stored name in memory +
  persisted; failed delete keeps the activity alive in memory + store.
  BackupServiceTests: re-import twice duplicates neither activities nor track
  points; duplicate ids within one file import once; restore save-failure
  leaves no partial import; delete-then-reimport restores cleanly. All
  failure assertions read back through a **fresh** `ModelContext` so they
  prove store state, not just the object's in-memory copy.

## Next / not built

Deferred / do-not-build items, so a fresh session doesn't re-propose them:

- **Live-record notification** (Dynamic Island / Lock Screen with
  Pause/Finish actions) — needs ActivityKit **Widget Extension target**
  (UI cannot be defined from the main app); deferred. Adding it requires a new
  Xcode target, best added via Xcode GUI (File → New Target → Widget
  Extension) or careful pbxproj surgery.
- **Scheduled/automatic backup** — background app refresh + notification +
  file-conflict resolution; current manual export/import is sufficient.
- **Restore duplicate-conflict resolution** beyond skip — edge case for
  multi-device power users; "skip existing" is safe and correct.
- **Apple Watch companion app** — separate watchOS codebase/product decision;
  out of scope by design (this is an iPhone recorder).
- **Cloud sync / iCloud entitlement** — needs paid Apple Developer Program;
  changes the fundamental architecture. Backup via iCloud Drive suffices.
- **Social features** (feeds/followers) — contrary to "private by
  construction".
- **Workout auto-detection** — significant ML/HealthKit complexity; manual
  Start is clear UX.
- **Custom/user-defined sports** — model migration + share-template changes;
  the current 6 sports cover real use.
- **Step cadence display** — Watch exposes steps/min, not RPM; the field stays
  `cadenceRpm` and unpopulated for now (see `KNOWN_ISSUES.md`).
- **Resting HR / VO2 max** — needs `HKQuantityType` reads + personal-best
  enrichment; nice-to-have, low impact.
- **HealthKit active energy / calories** — energy deliberately not written to
  Health (crude local formula); a stored `activeEnergyKiloJoules` field and
  real energy imports would be needed for accuracy.

## 2026-10-30 — MURY 1.1 local implementation (uncommitted)

Pink/Tiffany tokens, mandatory persisted initial choice, independent appearance, existing-screen styling and explicit sharing palettes are written locally on feature/mury-branding. Flow vectors/PNG assets are traced from the supplied board. Display name/version are MURY/1.1; compatibility identifiers and all protected service/model/workflow files remain unchanged. New private remote mury-ios remains empty. No commits/pushes/distribution/signing changes.

Final local verification: asset checker passed all four combinations, RGB icon formats and protected-file hashes; Swift 6.4 Windows parser passed all 39 Swift files; git diff --check passed. Independent review found icon alpha-channel packaging and two legacy Photos permission labels, both corrected; icon regression check failed before correction and passed afterward. These are limited checks, not an iOS build. XCTest, visual simulator captures, upgrade from Build 1, and physical-device GPS/HealthKit remain pending. See mury-1.1-plan.md for final review and updated verification results.

## 2026-10-31 — master completion scope (uncommitted)

Added richer first-launch previews and dedicated Settings; Tiffany-first defaults and the master Pink/dark-surface palette values. Added Home with real-only recent/seven-day data and consume-once recording shortcuts, discarding shortcut requests during active/paused sessions in source. Added explicit native Save to Files for ready PNG/MP4 with immutable payload ownership, cancellation and retry feedback. Independent task source reviews approved all three changes.

Lead checks: all 46 Swift app/test/UI files parse on Windows; actual asset/contrast/icon/protected hashes pass; repository-normalized git diff --check passes with line-ending advisories. HTML palette proof inspected at desktop/phone widths without overflow/page errors. Combined source review found Home clock staleness and omitted Home screenshots; both were corrected and scoped re-review found no new breakage. Full 46-file syntax, asset/protection and whitespace checks passed again afterward. No native typecheck/build/XCTest/simulator/device test has run; see mury-validation.md and mury-device-qa.md. No commit/push/workflow dispatch or distribution.

## 2026-11-06 — Watch app icon (TestFlight upload fix)

The first real TestFlight upload with the Watch app (build 4; build 3 was already on App Store Connect) was rejected by Apple validation: error 90713 (`CFBundleIconName` missing in `rdyy.larping.watchkitapp`) and 90391 (no icons for `larpingWatch.app`). Root cause: the `larpingWatch` target had no asset catalog at all, so no app icon. The earlier dry runs (`upload_to_testflight=false`) built, signed and found the Watch inside the IPA, but never reach Apple validation, so this only showed on a real upload.

Fix: `larpingWatch/Assets.xcassets` with a single-size watchOS `AppIcon` (the MURY 1024 icon, same file as the iPhone marketing icon; watchOS masks it to a circle) and the same `AccentColor`; `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` on both Watch build configurations. `larpingWatch` is a file-system synchronized group, so the catalog joins the target without extra project edits. Each TestFlight upload also needs a higher build number than the last one sent (`CURRENT_PROJECT_VERSION`, iPhone and Watch kept equal).

## 2026-11-06 — Heart-rate graph and zones in the activity detail

New `HeartRateSection` under the stat tiles: a Swift Charts line of the saved heart rate with the five zones as coloured bands behind it (drag to read a moment, the header switches to that time and bpm), and a card with time in each zone as a bar plus a row per zone. Only appears with at least 10 readings, so activities without heart rate look as before.

The zone maths is Foundation-only in `larping/Core/HeartRateZones.swift` (edges at 60/70/80/90% of the max, rounded half up; a reading counts until the next one; gaps over 30 s count for nothing so a pause or a watch off never inflates a zone) with `HeartRateZonesTests`, both added to `scripts/test-core-logic.sh` so they run on Linux. The max is the highest real reading across all activities, no setting needed (see `KNOWN_ISSUES.md`). The graph and card were first drawn as mockups (options A graph only, B graph and zones) and B was chosen. Not yet seen on a device.

## 2026-11-07 — Route flyover (Strava-style 3D video)

Added `FlyoverPlan` (Foundation-only camera script: overview -> one turn tilting onto the start -> follow the point with a growing trail -> pull back) with unit tests in `FlyoverPlanTests` (also in the Linux core-logic script), `FlyoverView` (preview and screen-recorded video, 15/30/60 s, default 30, share via the system sheet) and a *Route flyover* button on Activity detail. Chosen over frame-by-frame MKMapSnapshotter rendering (about 900 snapshots for 30 s, slow, geometry unverified per `mury-3d-video-export-feasibility.md`). Not run on a device yet: camera smoothness, recording permission flow and Apple Maps 3D coverage need a TestFlight build to check.

## 2026-11-07 — Export compliance answered in the plist

Build 4 uploaded with no errors (Delivery UUID 721e7c13) but never showed up as an update in TestFlight, almost a day later. The app has no networking and no custom encryption, yet neither `Info.plist` declared `ITSAppUsesNonExemptEncryption`, so App Store Connect can hold a build at "Missing Compliance" until someone answers the question by hand. Both plists (iPhone and Watch) now carry `ITSAppUsesNonExemptEncryption = NO`, so later builds skip the question. A build already held in Missing Compliance still needs the answer given once in App Store Connect.
## 2026-11-07 — Steadier camera and 3D flyover inside Share

A device recording of the Replay (build 4) showed the camera swinging left and right: the heading was the raw bearing of the current GPS segment. `FlyoverPlan.smoothedHeading` now averages the bearing over roughly +-9% of the route and both the flyover and the Replay use it (tests with a zig-zag GPS track). Share → Video also gets a *3D flyover video* button that opens the flyover with its record and share flow, so the 3D option lives where people look for video sharing. The recording itself is still the real-time screen recording, so Share keeps the 2D rendered video as a separate button.

## 2026-11-07 — Flyover framing from the first device test of build 5

Build 5 on a phone showed the overview not fitting the route (distance was 2.6x the longest side, but a portrait screen is narrow) and a full 360 degree spin that felt like too much. The overview is now fitted from the route projected on screen axes for the opening heading (5x width, 2.4x height), and the orbit is a 90 degree quarter turn ending on the follow heading. The fit factors are an estimate (assumed field of view) and need a visual check on the device.

## 2026-11-08 — Flyover polish after the build 6 device test

Build 6 looked good; requested tweaks done: marker drops in and lands on the start (`markerDrop`, bounce), closer and more tilted follow camera (450 m, 65 degrees), route smoothed over about 10 s (`RouteSmoothing`, Linux-tested), map pre-load sweep before Preview/Record, Share button renamed *3D Flyover Video* with no duplicate icon, and the template carousel rebuilt as one uniform `ForEach` (pages after Video stopped half-way). All unverified on a device. Not done yet: video rendered inside the app so the screen-recording prompt goes away.

## 2026-11-08 — Flyover polish round 2 (build 7 device test)

Marker drop and button liked. Changes: orbit now tilts early and closes in late (Strava-like lap from afar), route drawn as one uniform red line (white casing removed, it made the width look uneven), the visible pre-load sweep replaced by invisible `MKMapSnapshotter` warm-ups (best effort; no public MapKit offline or cache-clear API), and the Share template carousel rebuilt as a ScrollView paging carousel with own dots because the page-style `TabView` still stopped half-way (build 7 screenshot: page offset about half a page, next page spinner at the right edge). All unverified on a device.

## 2026-11-13 — Experimental in-app flyover render (build 9)

Added `FlyoverRenderer` and a *Render in app (experimental)* button in the flyover screen: per-frame `MKMapSnapshotter` images from the same `FlyoverPlan`, overlay drawn on top, `AVAssetWriter` MP4, progress with seconds per frame, cancel, bounded waits. Goal: no screen-recording prompt. Unproven on a device (geometry, alignment, speed, licence); see KNOWN_ISSUES. `FlyoverPlan.frameTimes` added and tested.

## 2026-11-13 — Render in app fixes after the build 9 device test

Progress card now shows the last drawn frame and an elapsed clock; route drawn with own `FlyoverProjection` instead of `Snapshot.point(for:)`; 3 snapshot requests in flight; overview hold cut to 5 percent. Build 10. Unverified on a device.


## 2026-11-14 — Watch Stage 1: the watch records by itself

New `WatchRecorderCore`, `WatchActivityRecord`, `WatchActivityStore` (MirrorShared, Linux-tested), `WatchRecorder` and a new start screen with sport choice on the watch; the "Waiting for your iPhone" screen is gone. Watch target now independent of the companion app and asks for location. `RecorderMath`/`GeoDistance` moved to MirrorShared. Sending to the iPhone is Stage 2. Unverified on a device.


## 2026-11-14 — Watch Stage 2: sync to the iPhone and automatic titles

Watch recordings go to the iPhone with `transferFile` (queued, deleted on the watch only after delivery), land in an inbox and are imported once (duplicate check by source and start second), then written to Health like any activity. New automatic titles "Corrida da manhã em Wembley" replace "MURY Run" on the iPhone recorder and for watch imports; the place uses Apple's geocoder (user approved). Unverified on devices.


## 2026-11-14 — Render screen full-screen, shorter intro

Rendering now shows the frame being made on the whole screen with a translucent bottom bar instead of a boxed card with a small preview; the live map is hidden while rendering. Intro before the run shortened: phase shares overview 3% / orbit 17% / follow 70% / finish 10% (was 5/27/58/10) so the run starts sooner. Unverified on a device.


## 2026-11-15 — Marker falls once; route line from MapKit

The marker no longer bounces: a single gravity-like fall (`fallIn`) over the last 30% of the orbit, so the run starts as it lands. The rendered route line is now positioned by MapKit itself through a hidden `MKMapView` (`MapProjector`) with the old assumed projection as fallback, because the line still drifted on the build 13 device test. Unverified on a device.


## 2026-11-15 — Removed the MapKit projector after a crash

Build 14 crashed while rendering the flyover in the app. The only new thing in the render path was the hidden `MKMapView` used to place the route line, so `MapProjector` was removed and the renderer is back to `FlyoverProjection`. The no-bounce marker fall stays. Crash cause unconfirmed.


## 2026-11-15 — Render crash root cause: snapshotters kept alive (build 16)

Build 15 still closed the app silently at about frame 230 of 600 (phase "following"), the signature of the system killing it for memory. Cause: the per-frame timeout was a `DispatchWorkItem` capturing the `MKMapSnapshotter` strongly; cancelling a work item does not release it until its 15 s deadline, so about 150 flyover snapshotters (with their 3D data) stayed alive at ten frames a second. The timeout is now a `Task` holding the snapshotter weakly, cancelled when the frame returns, and `prefetchWindow` is 2. Inferred from the video and code, not from a crash log: unverified on a device.


## 2026-11-15 — Build 17: memory shown while rendering

Build 16 (timeout no longer keeps snapshotters alive) still closed the app mid-render on the device, so the memory theory is not proven. The render bar now ends its frame line with the app's memory footprint in MB (`FlyoverRenderer.currentMemoryMegabytes`, `phys_footprint`), and `prefetchWindow` is 1. A screen recording of the next render shows whether memory climbs until the app closes. If it stays flat, memory is not the cause.


## 2026-11-16 — Build 18: render crash report

The render still closed the app on the device and there is no Mac for a crash log. The renderer now leaves a breadcrumb file while it works (cleared on any normal end); if it is still there at the next launch, a sheet shows frame, phase and memory samples plus the newest MetricKit diagnostic, with a Share button. Nothing is sent anywhere (no network in the app by design). Tests: `RenderCrashLogTests`. Unverified on a device.


## 2026-11-16 — Build 19: render memory leak located by stage, clean stop

The first real report (build 18, iPhone, iOS 27.0.1): memory grew linearly about 15 MB per frame (1107 MB at frame 120, 3297 MB at frame 270) until the system closed the app near 3.3 GB at frame 275. The leak is not the snapshotter timeout (build 16). 15 MB is about four 720x1280 RGBA frames, so something keeps whole frames. Build 19 measures growth per stage (snapshot, draw, encode) on screen and in the report, sends full-size previews to the screen only every 4th frame, and stops the render cleanly at 2800 MB with a message. This is a diagnostic build, not a fix: unverified on a device.


## 2026-11-17 — Build 20: is the full-screen preview the cost?

Build 19 stopped cleanly at frame 233 / 2802 MB (about 12 MB per frame) but did not say which stage keeps memory. The person's hypothesis: the big full-screen preview (added in build 13) uses the memory, since renders did not crash before it. Build 20 adds a fourth measurement, "screen" (memory change after the preview is handed to SwiftUI, per picture shown), and puts all four numbers in the stop message, so one run answers it. Diagnostic build, no fix yet.


## 2026-11-17 — Build 21: lighter map pictures, snapshotter released

Build 20 numbers on a phone (stopped at frame 213 / 2807 MB): snapshot 9, draw 3, encode 0, screen -3 MB per frame. So the full-screen preview is not the cost; the map engine (MKMapSnapshotter, flyover) keeps about 9 MB per picture it makes, and the draw stage about 3. Build 21 requests the pictures at scale 1.5 (540x960, drawn enlarged to the 720x1280 video), runs the snapshotter on its own queue inside an `autoreleasepool` and calls `cancel()` when the picture arrives. Whether either lets the engine free its memory is unverified; the 2800 MB clean stop stays as the safety net. If it still climbs: shorter render-in-app clips, or screen recording only (see KNOWN_ISSUES).


## 2026-11-18 — Build 22: Render in app hidden

Build 21 still stopped at frame 239 (snapshot 10 MB per frame). The button is hidden behind `FlyoverView.offersRenderInApp = false` so nobody is led into a render that cannot finish; Preview and Record video are unchanged. Strava's own Flyover is its own 3D engine (Fatmap) with live playback; how it creates the shareable video is not published.


## 2026-11-18 — Build 23: Record video fixes

Record video failed twice on a phone (see KNOWN_ISSUES): the permission alert counted as "left the screen", and a stale start/stop raced a new recording. Only `.background` aborts a run now and the stop is guarded. Unverified on a device.


## 2026-11-18 — Build 24: Map cinema (MapTiler test)

New test screen *Map cinema (test)* (Activity detail menu): the same `FlyoverPlan` on a live MapTiler satellite map with 3D terrain, camera tilt 78 degrees (Apple Maps stops near 65; MapTiler allows 85), the route and a growing trail as GeoJSON lines, recorded with `RPScreenRecorder` and played on a separate black "cinema" screen with Share. One live map, no per-frame pictures, so the Apple snapshot memory growth does not apply. Added the `MapTilerSDK` Swift package (exact 2.4.0, product MapTilerSDK, WKWebView based, tools 6.0). The SDK has no snapshot or capture API, so frame-by-frame capture of the map was not attempted. Unverified on a device: whether the map loads, the camera/zoom conversion (`MapCinemaMath.zoom`) frames like the Apple flyover, whether the screen recording includes the WebGL map (black frames are possible), the 4 s fixed wait before Record is enabled. The key comes from the GitHub secret `MAPTILER_API_KEY` (see KNOWN_ISSUES).


## 2026-11-19 — Build 25: Map cinema with 3D buildings and map preload

From the build 24 device test: the satellite map is a flat photo over near-flat terrain (Upminster), with visible tiles loading. Build 25 adds a vector look (default, `MapChoice.vector`, MapTiler `streets` style plus our own `fill-extrusion` layer from source `maptiler_planet`, source layer `building`, minZoom 14) next to the satellite look (picker; the style is fixed at map creation so changing it rebuilds the map). Before filming, `warmUp()` covers the screen, frames the route plus 500 m margin from above, then flies a quick low pass along the route, waiting for the map `idle` event (`didTriggerEvent`), and only then starts recording. The fixed 4 s wait is replaced by waiting for the first `idle` (12 s cap). Also fixed the build 24 archive: profiles are set per target in the Release configs because a global specifier broke the MapTiler resource bundle target. Unverified on a device: that the style/source/layer names match (otherwise no buildings and no error), that `idle` fires reliably (every wait has a timeout), and that the cache keeps the tiles through filming.


## 2026-11-19 — Build 26: Map cinema satellite 3D, sky, direct start

From the build 25 device test: he wanted 3D buildings on the satellite look (like Apple Maps satellite), a sky at the horizon (it was white), no visible map loading, sharper imagery, and logos on the video. Satellite (default, "Satellite 3D") now adds the MapTiler vector tiles (`mt-planet`, `https://api.maptiler.com/tiles/v3/tiles.json?key=…`) as our own source under the building extrusion layer; "Streets 3D" keeps the style's own `maptiler_planet`. Sky/haze via `setSky` after the first idle. `pixelRatio` 3 for sharper drawing. MapTiler logo bottom left (SDK, required attribution) and a MURY mark bottom right on screen while playing/recording, so both end up in the recorded video. The preload fly-around and the overview from above were removed: the camera jumps to the first frame under a black "Getting the map ready…" cover, waits for the map `idle` (8 s cap), and the flight starts straight after. Unverified on a device: the tile URL/key handling and layer names, sky look, sharpness change, and the MURY mark position next to the SDK attribution text.

Build 26 also (Apple flyover): follow camera pitch 65 → 72 degrees (`FlyoverPlan.followPitchDegrees`; Apple Maps limits how low it goes, 72 is a conservative guess, unverified on a device), a MURY mark on the recorded screen and on rendered frames (next to the required "Apple Maps" credit), and Render in app switched back on for 8 s clips only (160 frames, below the ~230 frame memory stop) with a plain waiting screen instead of the growing picture. Sky cannot be set on the Apple map; its flyover draws its own. Unverified: 8 s is really safe on every device and iOS version.


## 2026-11-19 — Build 27 (fixes): Map cinema trail and runner, softer sky

From the build 26 device test (MapTiler): the red trail and the runner dot never appeared, and the horizon looked like a hard band. Root cause of the trail: `MTGeoJSONSource.setData(data: URL)` injects `source.setData('<url>')` into a web view loaded with no base URL, so a `file://` temp file cannot be fetched and the trail source stayed empty (the faint white route came from the initial JSON string, so it worked). Fix: the whole route is loaded once as per-step features tagged with a running index and the trail layer is revealed by a filter updated each frame; the runner is an `MTMarker`. Sky: horizon, fog and ground fog now share one pale blue (`fogGroundBlend` 0.85) so the far ground fades into the sky. Apple flyover Render in app feedback: fast and good quality. Unverified on a device: filter updates every 33 ms keep up, marker moves smoothly, sky look.


## 2026-11-19 — Build 28: Map cinema looks like the Apple flyover; render lengths back; start memory

From the build 27 device test: runner dot far too big and trembling, a white line beside the red trail, and a question why the old render worked for 30 s. Map cinema: no white line (full route faint red 30 %, trail solid red), and the runner is now a fixed SwiftUI overlay at the screen centre (the camera is centred on the runner in orbit and follow, so it cannot lag; dot size and look copied from the Apple flyover; none in the final pull-back). Render in app: back to the chosen 15 / 30 / 60 s (the 8 s limit is gone), guard still 2800 MB, and the progress line / stop message now begin with the memory at the start of the render. Code comparison with builds 9 and 10: the snapshot code is essentially the same and the live map is already removed from the view during a render, so the cause of the stops is not found; the start-memory number is meant to show whether the app is already near 2 GB before the first picture. Unverified on a device: the overlay stays exactly on the route in the orbit and follow phases, and what a 30 / 60 s render does.


## 2026-11-20 — Build 29: runner dot no longer trembles in the live Apple flyover

Device test of build 28 (Apple flyover, recorded video): the "Position" dot trembled and its text label showed under it. Cause: in SwiftUI `Map` the dot was an `Annotation` repositioned from its own state while the camera was set from the same state, so the two moved slightly out of step every frame. In the follow phase the camera centre is exactly the runner position (`followCenter`), so the dot is now a fixed overlay on the screen centre (`runnerBadge`); the map `Annotation` remains for the orbit drop-in and the final pull-back, where the camera is not on the runner. The annotation title is now empty (no "Position" label; `Map` has no `annotationTitles` modifier, the first try failed to compile). The MapTiler Map cinema overlay is now follow-phase only too, because in the orbit the camera centre is still moving to the start point (the build 28 overlay would have floated there). The in-app render (`FlyoverRenderer`) was never affected: it draws the dot at the snapshot point for each frame. Unverified on a device: the overlay sits exactly on the red line end during follow.

## 2026-11-20 — Build 30: logo on top and Strava-style card on every flyover video

Device feedback on build 29: wanted the real MURY logo at the top of the video, big and without a band, and the small "MURY" at the bottom right removed. Chosen from three mockups: white logo (`LogoWhite` asset) with a soft shadow. New `VideoOverlayInfo` (Core, plain text: name, activity title, sport symbol, distance, pace/speed, elevation) feeds the same card in the live Apple flyover (`VideoLogoMark` / `VideoInfoCard` in `VideoOverlayViews.swift`), the in-app render (`FlyoverRenderer.drawLogo` / `drawCard`, replacing `drawStats` and the `savedDistance` parameter) and Map cinema (which had no stats before). Athlete name comes from the `displayName` setting. Unverified on a device: logo size and card spacing in the rendered 360x640 frames and in the screen recording.

## 2026-11-20 — Build 31: Health import for real, profile and first-launch flow (phase 1 of the roadmap)

Ricardo's Strava comparison: MURY asked Health for only workouts, routes and heart rate, listed 20 workouts, imported one at a time, and his last week's Watch walks never showed. Now: broad Health read, 90-day backfill with routes and heart rate, a Health id on every imported activity (no duplicates, MURY's own workouts never come back), sync on every open plus background delivery as an extra, a first-launch flow (Health, profile, interests) and "Sync Health now" in Profile. Found on the way: heart rate was never read on import, because the code checked write status, which read-only types never report; that gate is gone. Roadmap of the nine phases: `docs/superpowers/specs/2026-11-20-mury-roadmap-phases.md`. Not testable in CI: HealthKit itself and background delivery; see the device checklist in the PR.

## 2026-11-20 — Build 32: small UI fixes from the UI UX Pro Max review

Code review against the UI UX Pro Max checklist (app not run, no simulator here). Unselected tab icons used iOS grey on the light-blue bar (about 2.1:1, below the 3:1 icon minimum): now ink at 70% via `UITabBarAppearance` in `RootTabView` (about 6:1). Two icon-only buttons had no VoiceOver name (Record "centre on my location", share preview "close"). Dark-mode `MurySurface` equals the canvas (#1F2937), so cards separate only by their border; left as is because the colour comes from the protected brand pack (`scripts/check-branding.mjs`), and changing it is Ricardo's call. New UI test opens the tabs at the largest accessibility text size; it checks the screens work, not how they look.
Also in build 32: build 31's main CI failed in two `HomeDashboardTests` UI tests. Root cause: UI tests run alphabetically on a fresh simulator, and `HomeDashboardTests` (first) launched the app plainly, so a fresh install correctly showed the new first-launch flow instead of the tab bar. A first guess (OnboardingTests leaving state behind) was wrong; its tearDown reset stays as a guard. Fix: UI tests that are not about the first launch use `XCUIApplication.skippingOnboarding()` (env `MURY_UI_TEST_SKIP_ONBOARDING`, honoured in DEBUG only). The app itself was not at fault.

## 2026-11-20 — Build 33: first launch redesigned (Laws of UX), 16 sports, 23 Health types

Device feedback on build 32: the first launch was too basic and broke Laws of UX (goal hidden behind a red "Not set" menu, unselected sports looked disabled, goal and level on one screen, "Intermedi…" truncated, no progress, no ending). Redesigned with UI UX Pro Max, taste and impeccable after a mockup Ricardo approved: five steps with progress and back, one question per screen (Hick), large cards with a check mark (Fitts), Health values pre-filled and tagged (recognition over recall), a welcome showing the imported workouts (peak-end). Interests now offer 16 Apple Exercise types. Health asks for 23 types, as Ricardo chose, each tied to a planned screen; the screens for VO2 max, heart rate variability, power and the other fitness measures arrive in the progress phase.

## 2026-11-20 — Build 34: Home in the premium style (phase 1.5 starts)

Ricardo approved the premium direction (mockups built with UI UX Pro Max, taste and impeccable). Home rebuilt as a scroll of cards: big week distance with a count-up, seven-day bars, record chips, and the newest activities as map cards (`ActivityRouteCard`, also used by the first-launch welcome). Only data MURY already has; no goal ring or streak until the progress phase.

## 2026-11-20 — Build 35: activity detail in the premium style (phase 1.5)

Mockup approved by Ricardo. The detail now leads with a full-width map, then a header (sport, date, where it came from, title, distance in large type, a grid of the other numbers), Replay and Flyover as two large buttons, and two new sections worked out from the stored GPS points: per-kilometre splits (time at each kilometre mark interpolated between points, the last stretch shown when 100 m or more, fastest full kilometre in brand red) and an elevation profile (hidden when no point has an altitude or the line is flat). Both live in the new `Core/ActivityAnalysis.swift`, Foundation-only and run in the Linux tests. Calories are labelled as an estimate because the existing formula ignores weight and sport; a proper figure comes with the profile and Health energy work. Unverified on a device: the layout, and how GPS noise on short Watch walks affects the splits.
Also in build 35: Ricardo asked for the red logo with a 3D look on the flyover videos instead of the white one. All three video paths (live Apple flyover, in-app render, Map cinema) now share `VideoLogo` in `VideoOverlayViews.swift`: the brand pack's red horizontal logo (taken as the light variant of `LogoHorizontal`, so dark mode cannot swap in the dark logo and no asset was added), five darker-red copies stacked one point lower for depth, and one soft shadow under the whole block. Unverified on a device: how the red reads over dark satellite and dense city maps.

## 2026-11-20 — Build 36: phase 2, activity types

Ricardo approved the 22-type list. New `SportType` cases with SF Symbols and Portuguese titles, Health mapping moved out of `HealthKitService` into `HealthSportMapping.swift` with the indoor flag, one-off re-classification of older "Other" imports, and heart rate plus Health's measured calories kept for workouts without a route (before this build an indoor workout's heart rate was thrown away, because heart rate was only stored on GPS points). Protected files changed and re-hashed, after telling Ricardo: Activity, CDActivity, ActivitiesStore, BackupService, GPXParser, HealthKitService. New Linux tests: `SportTypeTests`, `HeartRateSeriesCodecTests`. Unverified on a device: re-classification of his real Health history, and that every SF Symbol name renders.

## 2026-11-21 — Build 37: Map cinema removed, CI trimmed

Ricardo decided (voice call) to drop Map cinema and MapTiler: the Apple flyover stays, and a new Render in app comes next. Removed `MapCinemaView`, `MapCinemaMath` (and its tests), `MapTilerConfig`, the `MapTilerSDK` Swift package, the key steps in both workflows and the `.gitignore` entry. The MapTiler secret in GitHub is no longer read and can be deleted by him. CI: the macOS test step stops after 40 minutes and the job after 75 (build 34 hung for over 3 hours); tests already run on Linux are skipped on macOS (list read from `scripts/test-core-logic.sh`), except `GeoDistanceTests`, whose CoreLocation comparison only runs on Apple platforms. Process change: the full CI is no longer run by hand on feature branches; the push to main runs it before any TestFlight upload.

## 2026-11-21 — Build 38: Activities list in the premium style (phase 1.5)

Mockup approved. List rebuilt as cards with sport filter chips and month headers with totals; indoor activities get compact cards (time, heart rate, calories). Logic in `ActivityListRules` (Linux). UI tests that opened activities through list cells now use the card identifiers; new `ActivitiesListTests` checks a filter chip narrows the list. Unverified on a device: scrolling smoothness with many map cards (each card is a live `Map`), pinned headers over the cards.

## 2026-11-21 — Build 39: new Render in app (direct map copy)

Ricardo's idea in the voice call: cover the screen and copy the map behind it. The in-app render no longer asks `MKMapSnapshotter` for a new picture per frame (each kept memory the map engine never released, so long clips hit the 2800 MB guard); it moves one live Apple 3D map view, kept on screen under the render cover, to each frame's camera and copies it with `drawHierarchy` (`DirectMapCapture`). The old method is gone (it is in git history if this fails). Risk said up front: Apple's Metal-drawn 3D map can come out black when copied; the render checks frame 5 and stops with a clear message instead of making a black video. Unverified until tried on his phone: whether the copy shows the 3D map, speed per frame, and memory over 30 and 60 s clips (the memory line on the render screen still reports it).

## 2026-11-21 — Build 40: Render in app no longer looks hung

Ricardo tried build 39 on his phone: the render sat stuck. No numbers yet (screenshot of the render screen asked for). Likely cause: each frame waited up to 3 s for the map to report it had finished drawing, and if that callback does not fire on this phone a 30 s clip is hundreds of frames times 3 s. Now only the first 3 frames wait 3 s, later frames wait 0.7 s; at frame 12 the render stops with a clear `tooSlow` message if it averages over 1.5 s per frame. Unverified on a device: the cause itself (it is a hypothesis) and whether 0.7 s leaves blurry frames while tiles load.
