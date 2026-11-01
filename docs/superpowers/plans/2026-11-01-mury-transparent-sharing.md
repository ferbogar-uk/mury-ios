# MURY Transparent Sharing Implementation Plan

> For agentic workers: execute inline with executing-plans on the existing feature branch.

**Goal:** Three transparent MURY overlays and sharing logo without a plaque.
**Architecture:** Extend existing ShareImageComposer; reuse route drawer and typography. Integrate ShareActivityView and existing PNG document.
**Tech Stack:** SwiftUI, UIKit, CoreTransferable, XCTest. No dependencies.
**Spec:** docs/superpowers/specs/2026-11-01-mury-transparent-sharing-design.md

## Global constraints
No GPS, data, permissions, workflows, signing, identifiers, build numbers or upload changes.

## Review focus
Missing/zero metrics; route-less activity; logo bounding-box alpha; PNG transport; control fit with six templates and Dynamic Type.

### Task 1: Rendering and data
Files: larping/Core/ShareImageComposer.swift; larpingTests/ShareImageComposerTests.swift.
Interface: OverlayLayout column/compact/route; OverlayMetric; OverlayValue; static overlayMetrics(for: CDActivity); composeOverlay(layout:coordinates:stats:metrics:) -> UIImage.
- [ ] Write tests for logo-surround alpha, three overlay PNG roundtrips, empty route/selection and metric availability/units.
- [ ] Remove filled classic logo plaque and implement bounded overlays.
- [ ] Syntax/static checks locally; native XCTest requires macOS CI.

### Task 2: UI and PNG transport
Files: larping/Features/Activities/ShareActivityView.swift; larping/Core/ShareExportDocument.swift; larpingTests/ShareExportDocumentTests.swift; larpingUITests/ShareActivityTests.swift.
Interface: PNGShare Transferable with PNG Data; six template choices, metric toggles and Copy PNG feedback.
- [ ] Write PNG transport tests and template/metrics/copy UI flow.
- [ ] Integrate overlays, checkerboard preview, controls and existing Files exporter.
- [ ] Branding checker, Swift parse, diff check, independent review; record results and native/device gaps.

## Progress
Clean feature/mury-branding at 74bec9f. Owner approved package. No new release approval.

Integration finding: ActivityDetailView blocked Share for route-less activities. Remove only that presentation gate, add action/share accessibility IDs; preserve replay gate. Include ActivityDetailView in Task 2 and UI entry test.

## Verification ledger
- Independent source review: one blocker found (empty metrics still drew title/date/route); corrected with logo-only early return and whole-content alpha test for empty/nonempty coordinates. No other source blockers.
- Local first pass: branding checker exit 0; 52 Swift files syntax parse exit 0; git diff --check exit 0. These are not iOS runtime tests.
- Native regression red/green has not been run: Windows lacks UIKit/Xcode. XCTest tests written; macOS simulator CI required.
- No commits, push, workflows or TestFlight uploads performed for this feature yet.
