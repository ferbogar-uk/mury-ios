# MURY Sharing Video Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make real video generation reliable, correct the requested Classic composition, complete the reference-based transparent templates and fit complete routes into 15/30/60-second clips.

**Architecture:** Keep the current UIKit image compositor and AVAssetWriter pipeline. Bound each frame's temporary resources, reuse platform pixel buffers, preserve cancellation and expose progress. Keep route reveal/segmentation separate from saved activity totals and use the supplied stacked artwork. A 3D renderer is a separate technical study, not an enabled placeholder.

**Tech Stack:** Swift, UIKit, SwiftUI, AVFoundation, CoreVideo, MapKit, existing XCTest/UI suites; no new dependency.

**Spec:** [Approved design](../specs/2026-11-02-sharing-video-reliability-design.md). Owner approved recommended scope, feature-branch commits/push and CI; reports crashes on iPhone 14 Pro Max and iPhone 17 Pro Max. Preserve the already requested multi-agent execution method.

## Global Constraints

- feature/mury-branding only; all command helpers hidden.
- No new TestFlight upload without final-candidate approval; preserve workflows, signing, secrets and bundle rdyy.larping.
- No recording/schema/storage/HealthKit/backup changes; preserve the Larping backup discriminator.
- Logo uses only red #B20E1C, white #FFFFFF and light blue #A7D8F3; reuse original supplied artwork.
- Canvas 1080x1920, H.264 MP4; target 30 fps, durations 15/30/60 seconds, default 30.
- Transparent PNG and Files/copy/native-share contracts remain intact; unavailable values are omitted.
- Metrics-off logo-only applies to transparent overlays, not fixed-stat Classic/Map/Video.

## Review Focus

- Long/full exports: memory must stay bounded and the app must yield to UI/cancellation.
- Failure, duration change, backgrounding and dismissal: release temporary files without leaving a stale shareable URL.
- Long/localized text or all metrics off: no overflow, invented values or checkerboard pixels in output.
- Missing/stationary/invalid GPS segments: no fabricated connecting line, divide-by-zero or missing final point.
- Device vs simulator: native export success does not close the reported iPhone crash until owner reproduction passes.

## File ownership and interfaces

Initial parallel work has disjoint files. Video owner: Core/ShareVideoComposer.swift and larpingTests/ShareVideoComposerTests.swift. Artwork owner: Core/ShareImageComposer.swift, approved stacked asset catalogue, larpingTests/ShareImageComposerTests.swift. Parent: ShareActivityView.swift, ShareActivityTests.swift, later ShareRoute.swift/tests and integration. No shared-file edits until the preceding owner stops. Parent alone commits, pushes, dispatches CI or uploads.

Final video API remains async throwing and accepts the existing snapshot/coordinates/stats/style plus nested ClipDuration (fifteen=15, thirty=30, sixty=60; default thirty), optional segmented coordinates and an optional main-actor progress callback. Preserve the existing call signature through defaults. Do not expose a 3D option until it generates a genuine verified MP4.

### Task 1: Reproduce complete export and repair resource lifetime

**Files:** ShareVideoComposer.swift; ShareVideoComposerTests.swift.
**Consumes:** current ShareImageComposer.composeMapCard and Stats/ShareStyle.
**Produces:** same async composeVideo -> URL with reliable completion/cancellation; useful LocalizedError if the writer fails.

- [ ] Add a complete, network-independent MP4 export regression using the real compositor, then load AVURLAsset video track/duration and decode samples; assert 1080x1920, expected duration/frame count and a completed readable file. Keep cancellation test. Add a bounded memory/responsiveness observation without logging route/health data.
- [ ] Parent runs baseline native CI before any production repair. Distinguish device hypothesis from an observed simulator failure/peak; retain the actual complete log. If export passes, do not invent a reproduced crash.
- [ ] Based on evidence, apply the smallest lifetime/backpressure repair: synchronous per-frame autorelease pool; adaptor pixel-buffer-pool allocation; checked writer/input/buffer failure; cooperative yielding/cancellation. Keep failure cleanup and write-completion checks. Do not move UIKit objects across actors without SDK/type evidence.
- [ ] Run complete native suite after repair and inspect logs; repeat actual full generation. Commit via Nimbalyst proposal, preserving unverified iPhone acceptance.

### Task 2: Classic hierarchy and reference-derived overlays

**Files:** ShareImageComposer.swift; Assets.xcassets/LogoStackedBlueWhite.imageset; ShareImageComposerTests.swift.
**Consumes:** supplied mury-stacked-dark master and existing Stats/OverlayValue/PNG export.
**Produces:** Classic stacked header and sport below route; OverlayLayout preserves column/route, replaces Compact display with Chips, adds Ticket/Edge/Receipt.

- [ ] Before production changes, add failing Classic hierarchy checks: blue symbol above white wordmark, both centered; white sport glyph below route, above statistics. Assert transparent corners and red/white route casing. Add expected overlay-name and no-metrics cases through existing enum raw values so baseline remains meaningful.
- [ ] Parent includes those tests in baseline CI; collect actual expected failures.
- [ ] Copy the supplied stacked SVG with its catalogue metadata, original rendering. Classic header: centered stacked mark in the top safe area; route retains its existing region; place sport around y=990 and start stats below it to avoid overlap. Leave Map/Video artwork unchanged in this task.
- [ ] Implement the reference layouts from the spec: Chips outlined rounded metric pills; Ticket weekday/date/sport with selected available values; Edge side values leaving center clear; Receipt bottom label/dot/value rows. Retain Statistics and Route + stats. Keep an early metrics-empty return before non-logo drawing.
- [ ] Expand alpha/bounds/long-content tests for every layout, and correct legacy pixel assertions only where the specified composition intentionally moved. No title/unit/data assertions may be weakened. Review against supplied screenshots, not assumptions about current Strava UI.

### Task 3: Segmented whole-route timing and duration output

**Files:** create Core/ShareRoute.swift and larpingTests/ShareRouteTests.swift; modify ShareVideoComposer.swift/tests after video owner stops; parent coordinates route drawing in ShareImageComposer.swift after artwork owner stops.
**Consumes:** ReplayTimeline.segments, built from saved timestamped activity points as ActivityReplayView already does.
**Produces:** ShareRoute(segments: [[CLLocationCoordinate2D]]) and revealedSegments(at progress: Double) -> [[CLLocationCoordinate2D]], cumulative valid-segment distance, no cross-gap distance.

- [ ] Add tests for uneven sample spacing, segment gaps, duplicates, invalid/nonfinite input, stationary routes, progress endpoints 0/1 and final valid point. Initial red must reflect missing behaviour, not a typo.
- [ ] Implement cumulative-distance reveal with interpolation inside an edge; exclude jumps between segments. Clamp progress safely, discard unusable coordinates, keep deterministic static fallback when total length is zero. Reuse ReplayTimeline gap rules at the caller; do not duplicate new pause heuristics.
- [ ] Add ClipDuration and set 30 fps/default30. Tests request 15/30/60 and validate MP4 metadata, frame counts and final complete route. End the writer session at the intended clip endpoint. Frame iteration remains streaming/bounded.
- [ ] Let map drawing consume revealed segment arrays without connecting them. Existing static full-route render geometry remains stable. Saved time/pace/distance do not change with output duration.

### Task 4: Sharing controls, selected preview and lifecycle integration

**Files:** ShareActivityView.swift; ShareActivityTests.swift; only required export tests if a contract is actually changed.
**Consumes:** final OverlayLayout cases, ClipDuration and segmented video API.
**Produces:** nine template choices total; duration/progress/cancel/retry UI; existing share/copy/Files output.

- [ ] Add UI checks for all intended menu labels, duration choices, generation/progress/cancel state, success/retry and continued PNG copy. Baseline checks should fail for missing controls before implementing them.
- [ ] Preserve Classic/Map/Video and expose Statistics/Chips/Route + stats/Ticket/Edge/Receipt. Render/cache only the selected transparent template where practical, rather than eagerly retaining every new full-resolution overlay.
- [ ] Build replay segments once from activity.trackPoints. Add a 15/30/60 picker, default30, readable progress, Cancel, localized actionable error and Retry. Changing duration cancels/invalidates the old generation safely; avoid stale completion publishing a replaced URL.
- [ ] Cancel an active generation on dismissal/background; release owned temporary files. Preserve Files document bytes independently of temporary-video cleanup and do not delete a URL still owned by active sharing.
- [ ] Run static branding/protection, Swift syntax, diff checks and the full native suite. Review final source diff and compare templates with the supplied references. Keep real-device recheck explicitly pending.

### Task 5: Genuine 3D export technical study and handoff

**Files:** docs/mury-3d-video-export-feasibility.md; ignored throwaway spike only if it can be evaluated without a new service/account/dependency.
**Consumes:** existing MapKit replay camera/timeline and official map-provider documentation.
**Produces:** concrete renderer recommendation with technical/export-rights/attribution evidence, unsupported cases and measured vs unmeasured limits.

- [ ] Check whether a documented API can yield moving, actual 3D building/terrain frames with attribution and permitted export. Do not equate a tilted still with 3D video.
- [ ] Record coverage, texture readiness, camera clearance, output speed and memory tests that require an actual device. If no complete renderer can be verified here, document the precise gap and next experiment rather than adding a disabled or fake 3D selector.
- [ ] Produce final validation report with exact commits/runs, complete test totals, root-cause evidence, remaining device acceptance and no automatic TestFlight upload.

## Verification commands and source of truth

All commands run hidden. Local: node scripts/check-branding.mjs; swiftc -frontend -parse changed Swift files; git diff --check. Native: gh workflow run ci.yml --repo ferbogar-uk/mury-ios --ref feature/mury-branding, verify exact head SHA, download larping-test-logs and inspect complete test.log. Existing workflow has no focused-test input; do not modify it. Expected final BUILD/TEST success and zero unreported failures/skips. Test-only baseline may be red and must be reported accurately. All commits use developer_git_commit_proposal after get_session_edited_files + actual git status.

Self-review: each approved stage has a task, shared files are serialized, call sites consume the stated interfaces, and device/3D unknowns remain explicit. This plan makes no additional product or release decision beyond the approved design.
