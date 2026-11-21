# MURY

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/brand/mury-horizontal-dark.png">
    <img src="docs/brand/mury-horizontal-primary.png" alt="MURY" width="360">
  </picture>
</p>

MURY 1.1 development uses the approved MURY brand identity, v1.3.

**Your private fitness and GPS tracker.** MURY is a free,
open-source iOS app that records GPS activities — runs, rides, hikes, walks,
swims — on a live map, with elevation gain and pause-aware timing (a
20-minute run stays 20 minutes even if you pause in the middle). Finish
auto-saves, so there's no lost workout.

Activities are stored on-device in SwiftData (SQLite). **No app account, backend or ads.** Apple Maps may request map imagery; optional HealthKit, backup and sharing move data only through their existing user-selected flows.

Open source, built with SwiftUI + SwiftData — no third-party
dependencies. Optional extras that keep the privacy promise: GPX import,
HealthKit sync/import (you opt in), and JSON backup/restore via iCloud Drive.
Works fully offline; GPS + Apple Maps tiles aside, the app itself never
touches the network.

## Features

- **Render crash report** — if the app is closed by the system during a 3D flyover render, the next launch shows where it stopped (frame, memory) with a Share button. Stays on the phone unless shared.
- **Activity types** (phase 2, build 36) — 22 types from Apple's Exercise list, each with its SF Symbol: outdoor with GPS (Run, Walk, Hike, Ride, Swim, Rowing, Tennis, Football, Other) and indoor/gym without a route (Strength, Treadmill, Indoor cycle, Stairs, Elliptical, HIIT, Yoga, Pilates, Core, Dance, Climbing, Indoor row, Boxing). Health workouts map to them (indoor running, cycling and rowing told apart by Health's indoor flag); imports saved as "Other" before build 36 are re-classified once on the next sync and get their heart rate and measured energy filled in. Indoor activities show no map but keep time, heart rate (graph and zones) and Health's calories. Record shortcuts list only the outdoor types: recording indoor workouts on the iPhone is phase 7. Activities written to Health from MURY carry the indoor flag when indoor.
- **Home** — default tab (premium redesign, build 34): the last seven days as one big distance figure that counts up, activity count and time, and a seven-day bar strip; a horizontal row of record shortcuts by sport; the three newest personal activities as map cards (route in white casing under the brand red, three headline numbers). Sample and future-dated activities are excluded from Home metrics/cards; existing history remains unchanged. Home shortcuts preserve active or paused recordings. Native lifecycle validation is pending.
- **Record** — GPS tracking (background-capable, elevation gain) with live
  map. **Finish attempts to save immediately** and shows an error if persistence fails.
  Pause time never counts toward the saved duration, pace, or average speed —
  a 20-minute run stays 20 minutes even it you paused in the middle.
  Event name auto-fills as "MURY Run" / "MURY Run 1" / "MURY Run 2"…
  (bumps only when that name already exists) and stays editable, but is
  **required** — clear it and Start disables until you fill it back in.
  Sport picked via a compact picker beside the event field; the sport icon
  bounces while recording, and a matching sport-symbol marker rides the live
  route tip on the map (falls back to the system blue dot before you start).
  Pausing is visibly distinct (bounce stops, a red `PAUSED` capsule appears),
  and if the GPS fix degrades mid-recording a small "GPS signal weak" warning
  appears — recording still continues, points are just limited to accurate
  fixes.
  Location button lives in the nav bar (top-trailing); the map is full-bleed
  (no top nav tint — the page is fully immersive), with the dark bottom
  control card in dark mode extending down to the tab bar (only Record's tab
  bar is tinted; other tabs keep the default liquid-glass). The card floats
  above the map as a translucent black overlay in dark mode (form
  content stays legible, map shows through faintly).
- **Activities** — premium redesign (build 38): horizontal wordmark header with the Import menu (GPX, Apple Health); sport filter chips (only sports present, most used first, shown when there are two or more); months as pinned headers with the month's distance, count and time ("November", or "October 2025" for other years); activities with a route as map cards (same card as Home), activities without a route as compact cards with a sport tile and up to three numbers (distance, time and pace for a treadmill, otherwise time, average heart rate and calories). The "This week" strip moved out (Home has it).
- **Share** — three swipeable 1080x1920 (Instagram Story ratio) templates:
  a classic card (sport icon + wordmark up top, a big route path line +
  stats, and the date in the footer — no event title, over a photo or a
  **transparent PNG** you can paste anywhere — previewed on a black backing
  so it stays visible in light mode, exported/shared fully transparent), a
  map template (real map fills the background with the wordmark top-right
  and the sport icon top-left over it, route overlaid with start/finish flag
  markers, and a bottom info card — sized to its content, no repo URL — holding
  the event title, date, and stats), and a slow 60fps animated video of the
  route drawing in over the same map. The map template's card title is the event name exactly as
  typed (casing preserved). Pace is shown without the ` /km` unit; speed
  sports keep `km/h`. Generated videos are temporary — share/save them before
  leaving, then they're cleaned up. Share through the system sheet or use **Save to Files** for the selected ready PNG/MP4. Save feedback distinguishes success, cancellation and retryable failures; the document owns its bytes before the picker opens. Native save behavior remains pending iOS validation.
- **Route flyover** — Strava-style 3D flight over the route (Activity detail →
  *Route flyover*): the whole route from above (fitted to the screen), a quarter turn tilting down onto
  the start, then the camera chases the moving point on the satellite 3D map
  with the trail growing and live time/speed on screen, and a pull-back to the
  full route at the end. Reachable from Activity detail and from Share → Video → *3D Flyover Video*. The camera heading is smoothed over the route so it stays on the route instead of swinging with GPS noise (the live Replay uses the same smoothing). The route line is smoothed (about 10 s each way), the marker drops in and lands on the start point, the camera follows close (450 m) and tilted (72 degrees, MapKit may clamp it), and the map area along the route is pre-loaded before *Preview* / *Record* start. Length 15 / 30 / 60 s (default 30). *Render in app* (frame-by-frame video from map snapshots, no screen recording) uses the chosen 15 / 30 / 60 s length again (build 28, to find what the device can do): the Apple 3D map engine keeps memory per frame, so a long clip may be stopped cleanly by the 2800 MB guard; the stop message and progress line show the memory at the start of the render. A waiting screen shows while it works (the bundled sample video if present). Every video (Apple flyover live and rendered) has the red MURY logo big across the top with a 3D look (darker red extruded side and a cast shadow, no band) and a Strava-style glass card along the bottom (avatar initials, name from the profile, activity title with sport icon, distance, pace or speed, elevation, thin route-progress bar). *Preview* plays it;
  *Record video* captures it with the system screen recorder (in-app only, asks
  for permission the first time) and offers the clip to share. Needs a physical
  iPhone to record; satellite/3D detail depends on Apple Maps coverage.
- **GPX import** — `.gpx` file → activity (`source: gpx_import`); the sport
  is auto-detected from the file's `<type>` element (unknown/absent keeps
  the picker default).
- **HealthKit import** — the first-launch flow (and Profile → "Sync Health now")
  asks Health for workouts, routes, heart rate, calories and your body details
  (birth date, sex, height, weight), imports the last 90 days of workouts with
  route and heart rate where Health has them (`source: healthkit_import`, Health
  id kept so nothing imports twice), and tops up whenever MURY opens; Health may
  also wake MURY in the background when a new workout is saved. Workouts MURY
  itself wrote to Health are never imported back. No route/HR means a
  metadata-only activity, never fabricated data. Activities → Import → "Import
  from Health" still lets you pick one workout and override its sport.
- **First launch** — after the theme choice, five steps with a progress bar and
  back button: connect Apple Health (optional; explains the benefit first),
  confirm birth date, sex, height and weight (values from Health tagged
  "Health"), pick sports from 16 Apple Exercise types in large cards, pick a goal,
  then a welcome that shows how many workouts came in and the newest one on a
  map. Stored on the device only (`ProfileStorage`, key `userProfile`).
- **Stats** — last-7-days distance chart + per-sport totals (distance, time,
  activity count, max heart rate when present), plus all-time totals and
  personal bests (longest distance, longest duration, highest heart rate).
- **Sample data** — one-time seed (7 activities, all sports, last 7 days,
  organic random-walk paths) on first install so the app isn't empty. Users
  can delete everything; it never re-seeds (`seedSampleDataV1` flag).
- **Backup** — Profile → Export all as JSON to Files/**iCloud Drive**, and
  Import backup back (idempotent — existing ids are skipped). Event names
  round-trip through backups. Profile shows when the last successful
  export/import happened.
- **HealthKit writes (optional)** — after a recording finishes, the saved
  activity is mirrored to the Health app as a workout with its route. Recording
  works identically with or without it, and a failed/denied write never blocks
  or loses the local save.
- **Profile** — a compact card (not a tall hero banner) with a fixed accent
  gradient (no custom cover photo) behind avatar/name/bio and a full-height
  darkening scrim so the gradient never reads as raw lime/blue, and the
  horizontal wordmark small top-trailing, always white in both light and
  dark mode. Profile → Settings holds theme and the independent System/Light/Dark controls. A small version footer sits at the bottom.
- **Themes** — mandatory first-launch Pink or Tiffany Blue selection, persisted locally and changeable in Profile → Settings. Theme is independent of System/Light/Dark appearance.
- **Appearance** — light/dark/system toggle (icon picker), persisted.
- **Splash** — branded launch: the horizontal logo wordmark over the app's
  canvas background, white in dark mode / black in light mode, with a static
  same-color `UILaunchScreen` behind it (no flash between phases).

## Data

Everything lives in the SwiftData store: `CDActivity` + `CDTrackPoint`
(cascade delete). No network, no auth, no tokens. Cosmetics (display name,
bio, appearance) are `@AppStorage`.

Data lives only on this device. To keep it safe / move devices: **Profile →
Export all activities** (save the JSON in iCloud Drive / Files), then
**Profile → Import backup**. No scheduled/automatic backup yet
(`docs/KNOWN_ISSUES.md`).

## MURY 1.1 development

Development branch: feature/mury-branding. New private destination: ferbogar-uk/mury-ios. Publication and validation checkpoints are recorded in docs/mury-master-progress.md and docs/mury-validation.md.

See [the local palette/asset proof](design/branding/branding-preview.html), [master completion plan](docs/mury-master-plan.md), [current progress](docs/mury-master-progress.md), [validation evidence](docs/mury-validation.md) and [native acceptance checklist](docs/mury-device-qa.md). The proof is a static web review, not the native app.

Compatibility identifiers remain unchanged: bundle rdyy.larping, SwiftData schema, HealthKit metadata and the backup discriminator app: "Larping". Existing activity titles and profile values are retained. The icon uses system light/dark/tinted variants; changing the in-app colour theme does not switch the home-screen icon.

Windows checks: node scripts/check-branding.mjs verifies the actual colour assets and protected-file hashes. Swift parsing checks syntax only. iOS compilation/XCTest, four-combination screenshots and upgrade/GPS/HealthKit device checks remain pending. No distribution workflow, commit or push is authorized by implementation approval.

## Build & verify

```bash
xcodebuild -project larping.xcodeproj -scheme larping \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  2>&1 | grep -Ei "error:|warning:|BUILD SUCCEEDED|BUILD FAILED"
```

Known non-code warnings that always appear (don't chase them): the
`AccentColor` asset-symbol redeclaration warning, and the
`appintentsmetadataprocessor` "no AppIntents.framework" note.

## Known limits (summary)

- Route map in detail uses Apple Maps → needs network for tiles; the recorded
  **data** is always offline.
- True background iCloud sync would need an iCloud/CloudKit entitlement
  (paid Apple Developer Program) — today it's manual export to iCloud Drive.
- Live-record notification (Dynamic Island/Lock Screen) is NOT built — needs
  a Widget Extension target, see `docs/KNOWN_ISSUES.md`.
- Apple Watch app records on its own (sport choice, GPS, heart rate, pause/finish, saved on the watch). Recordings are sent to the iPhone automatically and imported without duplicates. New activities get an automatic title such as "Corrida da manhã em Wembley". No scheduled automatic backup, no HealthKit active
  energy/calories — full rationale in `docs/STATUS.md` "Next / not built".

## Documentation

- `docs/ARCHITECTURE.md` — current structure, theming, conventions
- `docs/STATUS.md` — how it got here / commit-by-commit log
- `docs/KNOWN_ISSUES.md` — known gaps and non-bugs

## Contributing

See `CONTRIBUTING.md` for setup, conventions, and PR process.

## License

This project is licensed under the [MIT License](LICENSE).