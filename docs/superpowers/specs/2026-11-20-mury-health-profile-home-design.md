# MURY: Health sync, profile, Settings and a richer Home — design

Status: draft for Ricardo's approval. Nothing here is built yet.

## Intent and why

Ricardo compared Strava's first launch and Settings with MURY and finds MURY too simple. What he liked in Strava:

- On first launch it asks profile and interest questions.
- It pulls the whole Apple Health history on its own, with GPS routes drawn, and shows walks he recorded on the Watch without opening Strava.
- Its Home is full from minute one.
- Its Settings have privacy controls, units and training zones.

He wants MURY to feel complete in the same way, and the profile data (date of birth, sex, height, weight) will also feed calorie maths and the future gym app (separate app, same profile logic).

## Goals

1. Apple Health import that is broad and automatic: workouts, routes, heart rate, plus the profile characteristics.
2. First-launch flow: Health permission, profile confirmation (manual fallback), three interest questions.
3. Settings: profile data, privacy controls, units and training zones, Health connection status.
4. A Home that uses real data from the above.

## Non-goals

- No account, no server, no social features in this work (decided later, separately).
- No remote push notifications (need a server) and no default-map setting yet (Ricardo had no preference; Claude's call).
- Strava's social notifications (kudos, comments, clubs, challenges, friends, events) stay out: they need accounts and a server.
- No gym/strength calculations; only store the profile they will need.

## Anti-goals

- No screen that looks like a feature but does not work. Anything untested is said plainly.
- No networking added for any of this. The app stays on-device (Apple Maps and MapTiler are the existing exceptions).

## Current state (verified in code, 2026-11-20)

- `HealthKitService.requestAuthorization` asks to read workouts, routes and heart rate only. No date of birth, sex, height, weight or energy.
- Import is manual: `fetchRecentWorkouts(limit: 20)`, one workout per tap. No 90-day backfill, no background delivery.
- The import list is gated on `shareStatus == .sharingAuthorized` (write permission), not read permission. This may hide the list when write was denied. Unconfirmed as the cause of the missing walks; to verify in slice 1.
- Settings today: Profile card, themes, appearance, backup. No privacy, units or zones screen.
- No onboarding other than the mandatory theme choice and splash.

## Approaches considered

- A. Everything in one build: fastest to see, but without a Mac every CI failure is expensive and one bug blocks all.
- B. Slices, data first (chosen by Ricardo): each slice works alone and is tested on his phone before the next.
- C. Home first: most visible, but cards would sit on placeholder data, which breaks the honesty rule.

## Chosen design: three slices, each its own build

### Slice 1 — Health and profile (foundation)

- Request read access for: workouts, routes, heart rate, active energy, height, body mass, date of birth, biological sex.
- Gate the import on read availability, not write status.
- Backfill the last 90 days on first connect, routes included, skipping workouts already imported. Exact import de-duplication key is left to the builder (workout UUID is the natural one).
- New workouts appear without tapping import (HealthKit observer plus background delivery). Needs the HealthKit background-delivery entitlement; if it cannot be tested on device, say so.
- Profile model on-device: date of birth, sex, height, weight, plus three interest answers (sports, goal, level). Health pre-fills; user confirms or edits; manual entry when Health is off or denied.
- Conflict rule between Health and hand-typed values is an open question for Ricardo (see below).
- First-launch flow after the theme choice: Health permission screen, profile confirmation, interests.

### Slice 2 — Settings

- Profile data (editable).
- Privacy controls: hide start and end of a route when sharing; applies to share cards, flyover and render.
- Units (metric or miles) and temperature.
- Training zones for heart rate, defaulting from age, editable.
- Health connection: what is connected, what was imported, a way to re-run the backfill.
- Local notifications that need no server (Ricardo chose this): "workout imported from Health", "goal or milestone reached", and an optional record reminder, each with its own toggle.
- Weather on activities (Ricardo chose this, knowing it breaks "zero networking"): temperature, wind and humidity per activity, with a Settings toggle to hide it. Apple's weather service (WeatherKit) sends the activity's place and time to Apple. Needs the WeatherKit capability on the app's identifier in Ricardo's Apple Developer account, which Claude cannot confirm from here. Which slice carries this (2 or later) is left open until that capability is checked.
- Because of weather, `CLAUDE.md` and the README must stop saying "zero networking" and say instead exactly what leaves the device (map tiles, weather) and what never does (activities, profile, Health data).

### Slice 3 — Home

- Rebuilt using real data: recent activities with maps, week and month summary, progress toward the stated goal, and a prompt to record.
- Adapts to the interest answers. Exact layout is designed with mockups at the start of the slice.

## Constraints

- SwiftUI, SwiftData, no networking; follow `CLAUDE.md` (update README, ARCHITECTURE, STATUS, KNOWN_ISSUES in the same change).
- Verification is CI only (no Mac). TestFlight only on Ricardo's explicit yes, from a green main commit.
- Core logic that is Foundation-only stays `nonisolated` and covered by `scripts/test-core-logic.sh`.

## Open questions for Ricardo

1. When Health and a hand-typed value differ (weight, say), which wins? Claude's proposal: the newest value wins, and the app shows where it came from.
2. Should the 90-day backfill be longer (all history)? Proposal: 90 days, with an option in Settings to import more.

## Left to the builder

File layout, model naming, HealthKit query details, screen visuals within the existing black and white theme.
