# MURY — staged implementation roadmap

**Date:** 1 November 2026  
**Status:** Proposed sequence; planning only. Future stages are not implementation or release approval.  
**Baseline:** feature/mury-branding at a70ab268d14663e35d8c84322b5f43172c658c8c. Application source tested at 8b08004203de25e16ccdd5ccc5c3762af0f51a02.

**Goal:** Expand MURY into a more useful personal fitness app, starting with sharing and reusing existing recording, activity, HealthKit and replay code.

**Architecture:** Keep SwiftUI, local SwiftData and the existing native media composers. Separate export presentation from recorded activity data. Introduce server-backed functionality only through a separate approved architecture decision.

**Tech stack:** Existing Swift/SwiftUI, UIKit, MapKit, HealthKit and XCTest. No new dependency or service selected by this roadmap.

## Verified starting point

- Transparent sharing package implemented and pushed: three overlay templates, selectable available metrics, logo without a filled plaque, PNG clipboard/native sharing/Files export and route-less sharing.
- Native CI41330019457 passed 74 unit + 13 UI tests, zero failures/skips. See [validation](../../mury-transparent-sharing-validation.md).
- This sharing package is NOT in the currently delivered TestFlight 1.1 (2).
- Real-iPhone testing, Instagram paste and largest-text visual inspection remain unverified.
- Existing source already has local history, weekly/statistical summaries, personal-best summaries, HealthKit import/export and timestamp-based route replay. Improving them does not mean building replacements.
- Current exported video is a flat-map route reveal. Cinematic 3D export, social accounts, public links and comments are not implemented.

## Recommended order

~~~mermaid
flowchart TD
    S0["0 · Transparent sharing: implemented"] --> S1["1 · iPhone acceptance and controlled release"]
    S1 --> S2["2 · Sharing editor and export privacy"]
    S2 --> S3["3 · Activity history and personal progress"]
    S3 --> S4["4 · Indoor and HealthKit workout experience"]
    S4 --> S5["5 · Advanced replay feasibility and playback"]
    S5 -. "Separate product decision" .-> S6["6 · Accounts and social features"]
~~~

Stages 2–5 can be specified while Stage 1 device testing is pending. Do not bundle all stages into one release.

## Stage 0 — Transparent sharing foundation

**Status:** Implemented and automated checks passed; device/release gates below remain open.

Delivered: Statistics, Compact and Route + stats transparent PNGs; editable metric inclusion; logo-only export by clearing metrics; actual alpha; Classic logo plaque removed; clipboard PNG; existing photo/map/video/Files paths preserved.

Do not reimplement this stage. Its release readiness depends on Stage 1.

## Stage 1 — Validate the candidate on an iPhone

**Recommended immediate stage. No additional product feature required.**

User journey: update the existing app, retain activities, open an activity, select a sharing template, choose metrics, copy/save/share, and paste over a photo in the intended receiving app.

- [ ] Record the current installed version and export a backup through the existing app, without deleting owner data.
- [ ] Prepare the next build number after checking App Store Connect; do not assume an unused number.
- [ ] Obtain approval for the exact source candidate and each TestFlight upload.
- [ ] Verify upgrade retains history, appearance and onboarding completion.
- [ ] Test each transparent layout with a route, without a route, with all available metrics and with none.
- [ ] Check red/white/light-blue logo artwork, transparent surround and contrast on light/dark photos.
- [ ] Paste the PNG in Instagram on the iPhone. A successful clipboard byte test is not proof of receiving-app behaviour.
- [ ] Verify native share and Files export; cancellation/error recovery; Classic photo/map and existing video playback.
- [ ] Inspect small iPhone screen, largest accessibility text and VoiceOver labels.
- [ ] Perform short GPS/background/pause/resume/save smoke test; test HealthKit only with owner-controlled device data.

**Files/components:** Existing sharing views/composers/tests; docs/mury-transparent-sharing-validation.md; app version setting only if a new candidate is authorized.

**Exit:** Device evidence recorded, important regressions fixed, owner reviews the candidate. External review/public release stays separate. If a receiving app flattens PNG, document its actual behaviour before selecting an integration workaround.

## Stage 2 — Sharing editor and export privacy

**Status:** Proposed; first recommended new-feature increment after Stage 1.

User journey: open Share, select a layout and output format, place it over an optional photo, adjust appearance, choose whether route details are included, preview the actual export, then copy/save/share.

### Stage 2A — Format and readability

- Add Story 9:16 (1080×1920), portrait post 4:5 (1080×1350), square 1:1 (1080×1080).
- Reflow content to fit the selected dimensions; do not crop the current Story canvas.
- Allow approved red, white or light-blue logo variants and matching readable foreground treatment.
- Keep transparent output explicit. A photo background intentionally makes the composed image opaque.
- Apply selected metrics consistently to preview, copy, native share and Files output.

**Likely files:** ShareActivityView.swift, ShareImageComposer.swift, ShareExportDocument.swift, ShareImageComposerTests.swift, ShareExportDocumentTests.swift, ShareActivityTests.swift. Confirm affected callers, including ShareVideoComposer.swift, before changing the canvas interface.

**Acceptance:** Exact dimensions and alpha roundtrip; no clipped logo/units/metrics in any format; missing data absent; cancel/photo-load failure leaves a usable export; existing video dimensions unchanged unless separately approved.

### Stage 2B — Layout adjustment and route privacy

- Add bounded placement/size controls only after Stage 2A establishes format geometry.
- Offer a route-free export and an optional start/end concealment control for exported routes.
- Apply concealment before calculating export map bounds or generating imagery, so hidden endpoints are not revealed indirectly by the map framing.
- Keep the saved activity and full GPS trace unchanged. Never represent partial exported distance as a newly measured activity total.
- Explain that hiding endpoints does not guarantee anonymity.

**Acceptance:** Short routes, overlapping start/finish, all-points-hidden and no-route cases remain usable; export stats remain accurate; privacy treatment is consistent for every affected media path. Do not advertise privacy-safe video until its frames and map bounds obey the same rule.

**Approval boundary:** New preferences, permissions or persistence changes require a separate decision if proposed. Default recommendation: sheet-local editor controls and no new permissions.

## Stage 3 — Activity history and personal progress

**Status:** Proposed. Extend current history/statistics; no social backend.

- Search by activity title and filter by sport/date.
- Weekly and monthly totals plus a 12-week view using available distance/time/count.
- Calculate streaks and meaningful personal bests from actual personal activities; exclude sample/demo data.
- Share a weekly progress card using the Stage 2 format engine.
- Define calendar/time-zone boundaries and missing-data handling before implementing aggregation.
- Do not label highest heart rate as an athletic achievement or invent calories/fitness scores.

**Likely files/components:** ActivitiesListView.swift, StatsView.swift, existing Home summary logic, activity store read paths, dedicated aggregation tests, existing sharing composers.

**Acceptance:** Empty/filtered-empty states, mixed sports, missing distance, week/year transitions, duplicates and demo-only history produce honest results. Filters never delete or rewrite activities. UI tests cover navigation and reset/clear-filter recovery.

## Stage 4 — Indoor workouts and HealthKit presentation

**Status:** Proposed; data decisions required before implementation.

- Review current HealthKit workout-type mapping and actual imported fields.
- Preserve an appropriate activity label for strength/indoor workouts where source data supports it.
- Display duration and available heart rate without requiring route/distance.
- Reuse transparent sharing templates for non-GPS workouts.
- Include energy only when a reliable recorded source and provenance can be retained; current calculated calories are not treated as measured.
- Keep local saving independent from HealthKit authorization or availability.
- Defer sets/repetitions, voice entry and exercise-photo recognition; these are separate features.

**Likely files/components:** SportType definitions, HealthKitService.swift, import UI/mapping, activity presentation and sharing data adapter. CDActivity.swift or backup contracts only if the reviewed data model requires a separately approved migration.

**Acceptance:** Denied/unavailable HealthKit, no route, no heart rate, repeated imports, older stored sport identifiers and backup roundtrip. Real Watch/iPhone verification is required for actual health-source behaviour.

**Approval boundary:** Any new health permissions, stored fields, backup format or migration must be explicitly reviewed before edits.

## Stage 5 — Advanced route replay

**Status:** Proposal and feasibility work first.

- Reuse existing timestamp replay, play/pause, scrubbing, speed controls and data-gap handling.
- Validate map coverage, camera behaviour and accessibility on representative real devices/routes.
- Investigate smoother follow/aerial playback without changing recording algorithms.
- Treat cinematic 3D video generation as a separate feasibility milestone: coverage, attribution/licensing, rendering APIs, thermal/memory cost, cancellation and export reliability.
- Do not promise street-level collision avoidance, accurate building clearance or photorealistic cities based on concept images.

**Likely files/components:** ReplayTimeline.swift, ActivityReplayView.swift, replay tests, map/video composer boundary and docs/mapkit-replay-spike-validation.md.

**Exit:** A demonstrated playback improvement, or a documented go/no-go for cinematic export. Official provider documentation and current terms must be researched at this stage, before choosing a provider or paid service.

## Stage 6 — Optional social platform

**Status:** Deferred decision; not part of the current local-app implementation scope.

Possible future functions: accounts, private/public profile, follows, comments, clubs and activity links.

Before implementation, settle audience, identity, data ownership, visibility defaults, route/health-data exposure, moderation/blocking, deletion/export, service operation and costs. Recommend continuing with local functionality and native sharing until there is a clear need for this stage.

A separate product brief and backend/security design are required. No server, authentication provider or public route hosting is selected here.

## Ownership and integration

Reuse existing dedicated sessions; do not create duplicates.

- Parent: scope, acceptance, exact file assignments, integration and approvals.
- Screens/sharing + write-capable App implementation: editor and media changes.
- Brand foundation: approved identity and typography advice.
- GPS/HealthKit/data: data semantics and safe compatibility.
- Maps/replay: replay work.
- Build verification: test evidence and device/release checklist.
- Independent review/privacy: review actual bounded diffs.

The original three advisory sessions are read-only; only a write-capable assigned worker implements. No two workers edit the same file at once. The parent serializes shared composers, activity detail, theme and project changes. No automatic/background monitoring is promised.

## Delivery contract for each implementation slice

1. Read the current baseline and preserve unrelated changes.
2. Confirm bounded behaviour, exact files and interfaces.
3. Add meaningful tests; distinguish Windows checks, native simulator tests and device evidence.
4. Implement one coherent slice and independently review its actual diff.
5. Fix material findings and rerun affected checks plus suitable regressions.
6. Record actual results and remaining limitations.
7. Request explicit commit/push/release authorization where not already provided for that slice.

Always preserve main, Bundle ID rdyy.larping, existing TestFlight releases and installed data. No unapproved secrets, signing, workflow, schema, permissions, service or dependency changes. A roadmap is not approval to implement every stage.

## Next concrete action

Recommended: complete Stage 1 for the already-tested sharing package. In parallel, prepare the detailed Stage 2A design with format previews and exact canvas interfaces. Do not start Stage 2 product code or upload a new build from this planning request alone.

No deadlines or effort estimates asserted; scope and device findings determine subsequent slices.
