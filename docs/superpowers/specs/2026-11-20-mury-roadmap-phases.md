# MURY roadmap: nine phases to completion

Status: agreed with Ricardo on 2026-11-20 after a question-by-question interview. Each phase gets its own short design and plan right before it starts. Detail for phase 1 is in `2026-11-20-mury-health-profile-home-design.md` and `docs/superpowers/plans/2026-11-20-phase-1-health-and-profile.md`.

## Rule for every phase

A phase starts and finishes completely before the next begins. Done means: everything in it works (nothing visual only); CI is green and docs updated in the same change; merged to main and on TestFlight with Ricardo's explicit yes; he tried it on his phone and says it is good, or what is wrong is fixed first. Anything not testable from here is said plainly.

## Decisions from the interview

- Social features come last, with a server (Cloudflare is available). Until then MURY stays fully on the device, apart from map tiles and, in phase 6, weather.
- Home centres on activity cards with a map (like Strava's feed, but only Ricardo's own activities), with a Record button and sport chips at the top.
- Progress features wanted: weekly or monthly goals, week streak, 12-week chart, personal records, trophies and milestones.
- Activity types: the wide Apple Exercise list, each with its own icon. First they are imported from Health; recording them on the iPhone and the Watch comes in later phases.
- Privacy controls wanted: hide the start and end of a route, and private zones (home, work). Not chosen: app lock, hiding health data when sharing.
- Weather on activities is wanted (accepting that it sends place and time to Apple).
- Local notifications are wanted (workout imported, goal or milestone reached, record reminder).

## The phases

| # | Phase | What it contains | Depends on |
|---|-------|------------------|------------|
| 1 | Health and profile | Broad Health read, 90-day backfill with routes, sync on open, first-launch flow (profile and interests). In progress on branch `phase-1-health-profile`. | none |
| 2 | Activity types | Wide Apple list (run, walk, hike, cycle and indoor cycle, treadmill, strength, elliptical, rowing, HIIT, yoga, pilates, swim, climbing, stairs, dance, other), SF Symbol icon for each, indoor or outdoor flag, workouts without GPS shown without a map but with heart rate, calories and duration. Activities imported in phase 1 as "Other" are re-classified from their Health id. Backup keeps working both ways. | 1 |
| 3 | Settings | Editable profile data, privacy (trim 200, 400 or 800 m from start and end; private zones with name and radius; applied to share cards, flyover and render), units and temperature, training zones from age and editable, Health connection status with "import more history", local notifications each with a toggle. | 1, 2 |
| 4 | Home | Activity cards with map thumbnails, Record button with sport chips, adapts to the sports and goal chosen at first launch. Mockups are shown before building. | 2 |
| 5 | Progress | Goals (weekly or monthly, by distance, time or count, per sport), week streak, 12-week chart, personal records, trophies and milestones, goal and milestone notifications. All computed on the device. | 3, 4 |
| 6 | Weather | Temperature, wind, humidity per activity with a Settings toggle. Needs the WeatherKit capability on the app's identifier and a documentation change from "zero networking" to the exact list of what leaves the device. | 3 |
| 7 | Record indoors on iPhone | Timer-only recording for treadmill, strength, elliptical and the rest; heart rate from the watch when available; saved to MURY and written to Health. | 2 |
| 8 | Record indoors on Apple Watch | The watch app (Stage 3 of the watch plan) records indoor workouts and sends them to the iPhone. | 7 |
| 9 | Social | Accounts, friends, feed, challenges on a Cloudflare backend. Needs its own interview first: privacy model, costs, moderation, what data leaves the phone. | all |

## Running alongside every phase: move CI work from macOS to Linux

Ricardo asked for this on 2026-11-20. macOS runners are slow (about 25 minutes, queued) and cost more; Linux takes about a minute. Rule for each phase: decision logic goes into Foundation-only `nonisolated` files with tests listed in `scripts/test-core-logic.sh`, so it runs on Linux; screens stay thin. Planned steps:

1. Done in build 32: the brand and protected-file check runs on Linux (`core-tests.yml`).
2. Move more existing logic into Linux tests (activity store rules, share route maths, onboarding validation already pure).
3. Run SwiftLint and a project-file sanity check on Linux.
4. Only start macOS when Swift or project files change, and keep UI tests on main and by hand (already so).
5. What cannot move: compiling the iOS app, UI tests, HealthKit, MapKit and video export need macOS.

## Open items per phase (settled at the start of that phase)

- Phase 2: exact list and icon choices; whether strength activities link later to the separate gym app.
- Phase 3: default trim distance; how a private zone is entered (search, current location, pin on the map).
- Phase 4: card design variants.
- Phase 5: trophy list and goal defaults; wording of notifications.
- Phase 6: confirm the WeatherKit capability in his Apple Developer account.
- Phase 9: everything.
