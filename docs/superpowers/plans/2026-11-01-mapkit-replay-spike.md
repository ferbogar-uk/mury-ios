# MapKit Replay Spike Implementation Plan

> **For agentic workers:** Use subagent-driven-development with disjoint file ownership; no automatic commits.
**Goal:** Add a local interactive MapKit replay prototype to saved activities without changing recording, persistence, branding or sharing.
**Architecture:** Foundation-only immutable timeline and small playback state feed a SwiftUI Map. One owner integrates the detail entry. Aerial/Top-down/Free camera modes establish feasibility; low street-level flight and video export remain unproven and excluded.
**Tech Stack:** Existing Swift, SwiftUI, MapKit, XCTest; no dependencies.
**Spec:** ../specs/2026-10-31-mury-3d-flyover-proposal.md (bounded prototype only).
**Later approval:** Owner explicitly requested commit, GitHub push and TestFlight connection/upload; no secret/signing/workflow changes implied.
**Approval:** Owner selected “MapKit prototype (recommended)” on 1 November 2026, explicitly authorizing local prototype, existing data and Pink/Tiffany; no paid services, CI, commits, pushes or TestFlight.

## Global Constraints
- Work in existing feature/mury-branding checkout; no new branches/main changes.
- No persistent model, recorder, HealthKit, permission, signing, secret, dependency, workflow or current sharing changes.
- New replay is an experimental prototype; no claim of city coverage, collision avoidance or successful iOS runtime tests.
- Windows executable checks are separate from unavailable Xcode/UI/device verification.
- Concurrent workers own different files. Integrator alone edits ActivityDetailView. Reviewers never edit or run CI.

## Frozen shared contract
All types in Features/Activities/ReplayTimeline.swift, import Foundation only:
- ReplayCoordinate: Equatable, latitude/longitude Double.
- ReplayPoint: timestamp Date, latitude/longitude Double, altitudeMeters Double?, speedMps Double?; init with optional metric defaults nil.
- ReplayFrame: elapsedSeconds TimeInterval, position ReplayCoordinate?, headingDegrees Double?, altitudeMeters Double?, speedMps Double?, revealedSegments [[ReplayCoordinate]].
- ReplayTimeline.init(points:[ReplayPoint],startedAt:Date,endedAt:Date?); duration TimeInterval; segments [[ReplayCoordinate]]; sample(at:TimeInterval)->ReplayFrame.
- ReplayPlayback.init(duration:TimeInterval); private(set) elapsedSeconds=0, isPlaying=false, speed=1.0; mutating play(), pause(), seek(to:TimeInterval), setSpeed(Double), advance(by:TimeInterval).
The UI consumes these exact names. No Apple map types in the timeline. Full route and revealed segments must not bridge data gaps.

## Review Focus
1. Unsorted/duplicate/invalid timestamps and coordinates must not crash or invent movement.
2. Large gaps must not animate fictional connections.
3. Repeated seek to same time returns same marker/metrics/reveal.
4. Free-view camera must not be overridden; background/exit pauses replay.
5. New entry must not alter old sharing or recording.

## Task 1: Timeline and playback
Owner: timeline worker. Files: create ReplayTimeline.swift, larpingTests/ReplayTimelineTests.swift and scripts/replay-smoke.swift.
- [ ] Write checks before implementation: irregular samples at 0,2,10 seconds; t=1 midpoint; stable first input duplicate timestamp retained; invalid coordinates/timestamps discarded; optional invalid metrics nil; empty/single point; negative/overrun/nonfinite seeks; large gaps.
- [ ] Gap rule for prototype: break at >30 seconds or implied speed >100 m/s. Label as heuristic, not pause detection. Use haversine distance; shortest longitude interpolation/bearing across antimeridian. Do not interpolate metrics if either endpoint missing.
- [ ] Build deterministic timeline; usable point time anchored to saved startedAt when valid, ignore pre-start and post-end points; duration uses valid saved end or last accepted point. Empty/single point is not playable.
- [ ] Playback only accepts speeds 1,2,4, ignores invalid deltas, stops at end; play at end restarts. Pause and seek do not depend on previous sampling.
- [ ] Try red/green portable checks against actual Swift source on Windows. No parallel-language algorithm. XCTest native execution remains NOT RUN without SDK. If linker/toolchain unavailable, document limitation and keep tests without claiming pass.
- [ ] Return source paths, actual commands/output and edge-case decisions; no commits.

## Task 2: Native MapKit replay UI
Owner: map worker. Files: create ActivityReplayView.swift and larpingUITests/ReplayTests.swift only.
- [ ] Use frozen timeline/playback API. Public view init(activity:CDActivity), capture copies of point values once; no model writes.
- [ ] Write UI journey test first using existing sample activity where available; skip honestly if none. No owner-data deletion or new app launch injection/config.
- [ ] Paused initial overview, play/pause, scrub slider, 1x/2x/4x, Aerial/Top-down/Free modes, Return to Follow.
- [ ] Aerial means higher oblique follow camera, not 10–30m guarantee. Use realistic standard or hybrid map style; explicit “2D overview” uses standard flat top-down as fallback. User gestures enter Free mode. Never hide attribution.
- [ ] Use one monotonic elapsed-time tick (approximately12Hz, lower under Reduce Motion); one frame drives marker, reveal and available elapsed/speed/altitude. No historic moving-time fiction. Show saved final totals separately.
- [ ] Scene inactive and disappear pause, cancellation stops ticking; no live GPS permissions. Unsupported/empty routes show useful unavailable state. Avoid asserting automatic 3D coverage detection; honest coverage notice and explicit 2D fallback.
- [ ] Accessibile labels/identifiers, Dynamic Type controls in scrollable container, theme tokens. No rebrand/export/current share edits.
- [ ] Swift syntax checks if available; report all native compile/UI/device checks NOT RUN.

## Task 3: Integration and independent review
Owner: integrator for ActivityDetailView and docs only; fresh reviewer for all new code.
- [ ] Add separate visible Replay button when detail has route; .sheet NavigationStack ActivityReplayView, accessibilityIdentifier activity-replay. Preserve existing RouteMap/Share.
- [ ] No project membership edits expected (filesystem-synchronized groups).
- [ ] Run portable timeline checks, all-Swift syntax parsing, node scripts/check-branding.mjs and git diff --check.
- [ ] Review full delta against frozen contracts/protected hashes and independent reviewer; fix demonstrated issues and rerun affected checks.
- [ ] Record actual checks, gaps and exact native test steps; no CI/signing/release.
