# MURY sharing: video reliability, composition and templates

Status: owner approved stages 1–4 plus the 3D technical study, feature-branch commits/push and CI on 2026-11-02. No new TestFlight upload approved.

## Owner request

Build 1.1 (3) closes during Generate video. Fix generation; provide a 3D video option and an option to fit the whole route into at most 60 seconds. In Classic, move the sport glyph below the route, use the app symbol above the Mury wordmark and center both. Check the sharing collection against the previously supplied Strava screenshots and build equivalent useful layouts with MURY identity.

## Evidence and limits

ShareVideoComposer currently encodes a six-second, 60 fps, 1080x1920 H.264 MP4 using one static standard MapKit snapshot. It recreates a UIImage and CVPixelBuffer for each of 360 frames. The app target defaults to MainActor isolation. There is no per-frame explicit autorelease pool or use of the adaptor pixel buffer pool. Memory pressure and main-thread responsiveness are hypotheses requiring a complete export reproduction or crash report; neither is a confirmed device root cause. The existing video test cancels before rendering, so the previous 87-test pass did not test successful video generation.

The existing replay screen's tilted MapKit camera is separate from the static video composer. It is not already an exportable cinematic 3D renderer.

## Recommended stages

### 1. Reliable video export

Investigate the actual failure, including available TestFlight crash feedback. Add a full-generation regression that opens/decodes the MP4 and verifies portrait dimensions, frame count/duration, completion and cleanup. Collect frame/memory/responsiveness evidence before choosing a repair. Keep cancellation and temporary-file cleanup. Show useful errors and allow retry after failure. A spinner is not evidence that export is progressing.

No recording, storage, HealthKit, GPS calculations or saved statistics changes. Do not expose location/heart-rate information in diagnostic logs.

### 2. Exact Classic composition correction

Use the supplied mury-stacked-dark master: light-blue symbol above white Mury letters. Both centered on the canvas horizontal axis, with no filled plaque. The sport glyph moves below the route and above statistics. Route remains red with white casing. Preserve transparent pixels, photo background option, selected activity title, units and accurate saved values. This changes sharing artwork, not the Home navigation logo.

Assets already supplied: design/branding/brand-pack/01-Logos/mury-stacked-dark.svg and .png; SVG fills are only #A7D8F3 and #FFFFFF. Preserve original artwork; do not recreate lettering with a font.

### 3. Sharing collection matched to supplied references

| Supplied reference | MURY layout | Final behaviour |
|---|---|---|
| Route plus stats | Classic / Route | Stacked identity, route, sport below route, stats |
| Large centered values | Statistics | Readable vertical metric column |
| Outlined rounded chips | Chips | Compact outlined labels/values that reflow safely |
| Day/date ticket | Ticket | Sport, localized weekday/date and optional available metrics |
| Vertical edge labels | Edge | Side-aligned statistics leaving photo center clear |
| Dotted receipt at bottom | Receipt | Label/value rows connected by dot leaders |

Keep Statistics and Route + stats, replace Compact with Chips and add Ticket/Edge/Receipt; preserve Classic, Map and Video, for nine templates total. Use the screenshots already supplied, not invented claims about the current Strava app. Keep MURY artwork, Rubik, red/white/light-blue identity and original spacing suitable for the canvas. Preserve Copy PNG, Files and system sharing. Checkerboard appears only in preview. Omit unavailable values and do not estimate calories. No empty placeholders, fabricated achievements or social/profile links. For transparent overlays with selectable metrics only, all metric selections off keeps the existing logo-only contract: no title/date/sport/route. Classic, Map and Video retain their existing fixed-stat behavior; do not silently extend the empty-selection rule to them. Keep existing Map and Video modes.

Render selected previews on demand where practical: adding templates must not multiply retained full-resolution images and aggravate export memory pressure. Tests must cover alpha, bounds, long/localized content, no-route and no-metric cases.

### 4. Route duration controls

Recommendation: 15 / 30 / 60 seconds, default 30, 1080x1920 portrait, H.264 MP4, 30 fps. This is a MURY product target, not a claim that Instagram caps all Reels at 60 seconds. The full recorded route fits the selected duration; do not cut off the final segment. Saved distance/time/pace remain the activity's actual totals, separate from clip duration. Prefer cumulative-distance progression within valid segments, excluding jumps between segments, and reach the final valid point. The current coordinate arrays do not preserve timestamps/gaps: explicitly permit the sharing caller to consume existing timestamped activity points and ReplayTimeline.segments, then pass segmented route data to the composer. Do not invent gaps from coordinate spacing or change recording algorithms. A stationary/zero-length route uses a deterministic static route fallback. Keep a clear distinction between clip length and real activity time.

Generate frames incrementally and reuse bounded resources. Do not simply extend the current allocation-heavy loop to 60 seconds. Changing duration invalidates the old clip safely, cancels an in-progress export and does not delete a file still needed by an active share/export. Test 15/30/60 durations, final route completeness, cancellation, failure/retry and readable export.

### 5. Real 3D export

Recommended next technical spike: verify a genuine moving 3D camera export, building/terrain coverage, attribution and permitted video use for the map provider, and memory/time on a real iPhone. Use the existing replay timeline/camera where it is valid; do not present a static tilted map as cinematic 3D. No new map dependency, provider account, paid service or workflow/signing change is approved here.

Only expose a selectable 3D export when a real MP4 can be generated and verified. If a route lacks 3D coverage, explain that and offer 2D explicitly; do not silently label a 2D result as 3D. This stage needs a separate concrete renderer decision after the spike.

## Files and ownership boundaries

Primary implementation: Core/ShareVideoComposer.swift, Core/ShareImageComposer.swift, Features/Activities/ShareActivityView.swift, approved asset catalog entries and matching compositor/export/UI tests. Duration/gap work may also need ReplayTimeline consumption; inspect actual callers before assigning it. Keep native share/Files export contracts and data bytes intact.

Preserve .github/workflows, signing, secrets, bundle rdyy.larping, all stored activities and backup discriminator Larping. Work on feature/mury-branding. No TestFlight upload without explicit approval of its final candidate.

## Acceptance

A generated MP4 decodes and plays; export errors/cancellation leave no broken share state or orphaned temp file. Device generation no longer closes the app in the reported reproduction. Classic matches the requested hierarchy. Each reference layout has a corresponding transparent MURY template. The full route reaches its end within the chosen clip duration, with accurate activity totals. Genuine 3D is separately demonstrated before being offered.

A simulator pass does not establish the device crash is fixed. Owner reports crashes on both iPhone 14 Pro Max and iPhone 17 Pro Max. iOS versions remain unspecified. Apple crash-feedback metadata returned HTTP200 with zero reports in two checks. These limits do not prevent adding an initial full-generation regression.

Read-only builder review completed: clarified logo-only scope, timestamp/segment input and separate iPhone acceptance. No reviewer commands, edits or native tests were run.

## Research sources

- Meta's official sample documents H.264/HEVC, 23–60 fps and recommended 9:16: https://github.com/fbsamples/reels_publishing_apis/blob/main/insta_reels_publishing_api_sample/README.md
- Apple MapKit snapshot API: https://developer.apple.com/documentation/mapkit/mkmapsnapshotter
- Apple Maps terms and attribution/export restrictions, Attachment 6: https://developer.apple.com/support/terms/apple-developer-program-license-agreement/
