# MURY genuine 3D video export feasibility

Study date: 2 November 2026. This is a technical handoff, not a renderer implementation or release approval. The study used read-only repository source inspection and official Apple and Mapbox documentation; primary evidence is linked below.

## Recommendation and inspected baseline

Keep genuine 3D export out of the shipping selector. The smallest credible next experiment is serial, camera-specific MapKit snapshots compared with a visible 3D MapKit reference on a physical iPhone. Camera pitch alone does not prove building or terrain geometry. If snapshots fail the geometry gate, stop this path; do not add a disabled or fake 3D selector or describe tilted raster imagery as 3D.

The inspected baseline at HEAD 6082987 exports six seconds at 60 fps: ShareVideoComposer uses AVAssetWriter for H.264 MP4, reusing one MKMapSnapshotter snapshot while revealing the route. That is moving route artwork over a static scene. The separately approved future 30 fps and 15/30/60-second settings are not completed by this study.

ActivityReplayView provides an interactive SwiftUI Map with hybrid realistic elevation, 55-degree pitch and camera distance 700 outside Top-down; Reduce Motion uses zero pitch. Its camera replay is not a video pipeline. ReplayTimeline supplies sanitized time samples and heading/metric interpolation, splitting gaps above 30 seconds and jumps above 100 m/s. Reuse those segment semantics in an experiment. GPS altitude does not establish terrain height or building clearance.

## Provider evidence and unresolved permission

Apple's [Snapshotter](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter), [options](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter/options) and [camera](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter/options/camera?changes=la_4_5_8) provide imagery, camera configuration and output size; app overlays must be drawn separately. These documents do not establish Flyover fidelity, MP4 throughput or a video-export grant. [Map types](https://developer.apple.com/documentation/mapkit/mkmaptype/satellite) distinguish satellite imagery from Flyover; [feature availability](https://www.apple.com/ios/feature-availability/) is a coverage lead, not proof of snapshot coverage at each coordinate.

[MKMapView.camera](https://developer.apple.com/documentation/mapkit/mkmapview/camera?changes=lat_7_5_8) and the [rendering delegate](https://developer.apple.com/documentation/mapkit/mkmapviewdelegate/mapviewdidfinishrenderingmap(_:fullyrendered:)) do not prove stable high-resolution textures for every exported frame. [Apple DTS](https://developer.apple.com/forums/thread/772258) explains that tile/cache/preload state is not exposed and cached transitions may not emit the expected callback. Fixed waits and the first fullyRendered callback are insufficient. Apple's [archived guidance](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/LocationAwarenessPG/MapKit/MapKit.html) recommends Snapshotter over layer renderInContext and records foreground/network requirements; hidden-view screenshots remain an unverified fallback.

Apple's [Developer Program License Agreement, Attachment 6](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/) addresses notices (2.1), extraction/derivative/public uses (2.2–2.3) and storage (2.5). The research did not establish an express permission covering retained, user-shared MP4 sequences. This is an unresolved API/video-permission question, not a legal prohibition or a rights grant. Confirm the applicable account agreement and Apple's clarification for this precise use before release. Preserve legible Apple/supplier notices in every frame; attribution alone does not settle permission.

Mapbox is a conditional alternative for controllable terrain and extruded-city rendering. Its [iOS overview](https://docs.mapbox.com/ios/), [Snapshotter-compatible declarative styling](https://docs.mapbox.com/ios/maps/guides/styles/declarative-map-styling/) and [terrain example](https://docs.mapbox.com/ios/maps/examples/3D-terrain/) support the technical candidate. They do not prove universal photogrammetric facades or production export speed. Satellite terrain plus extruded buildings must not be presented as universal photorealistic Flyover.

The [official legal portal](https://www.mapbox.com/legal/product-terms) linked the [20 October 2026 Product Terms](https://cdn.prod.website-files.com/609ed46055e27a02ffc0749b/6ad79764a359d21b46049ea4_Mapbox%20Product%20Terms%20%28October%2020%2C%202026%29.pdf): section 1.7 distinguishes incidental promotion from additional video rights through an active Order (1.7.4). Do not assume route-focused user shares qualify as incidental promotion. The [pricing page](https://www.mapbox.com/pricing) describes commercial print/video rights; no such rights are established for MURY. [Attribution guidance](https://docs.mapbox.com/help/dive-deeper/attribution/) requires logo, OpenStreetMap and relevant supplier credits, including satellite sources. Agree the non-clickable video format and bake readable credits into each frame, rather than an end card. A new SDK/account/token, applicable permission, billing and device validation are separate prerequisites; none were added here.

## Measured versus unmeasured

Source/documentation inspection establishes the baseline and candidate APIs only. No physical-device renderer or export was run. Actual 3D snapshot fidelity, coverage continuity, texture readiness, camera clearance, frame latency, total export time, peak memory, thermal behavior and interruption recovery are all unmeasured. No provider is yet verified both technically and for MURY's reusable user-exported 3D MP4 use.

## Exact next physical iPhone experiment

1. Use short synthetic routes in a known Flyover city, a hilly area and an uncovered location. Record physical iPhone model, OS, SDK, coordinates, network and map configuration. Compare three poses per route with a visible MapKit map at 55-degree pitch and distance 700.
2. Generate serial snapshots with equivalent camera/configuration and intact attribution. Compare walls, roof occlusion, terrain silhouette and parallax across poses. A rotated or tilted plane fails. If the visible reference has geometry but snapshots do not, record API/OS/coverage and stop before scaling requests.
3. Only after geometry passes, generate a six-second experimental sequence at explicit output timestamps using ReplayTimeline samples and discontinuous gaps. Use the final canvas dimensions at the experiment revision. Test 30 fps first; try the inspected baseline's 60 fps only if useful. These are experiment settings, not product promises. Snapshot completion controls rendering; AVAssetWriter timestamps control playback, so real-time export is unnecessary.
4. Request one frame at a time, respect writer backpressure and release each image/buffer. With Instruments, measure per-frame latency, total time, peak resident memory, thermal state and cancellation cleanup. Record cold/warm and degraded/offline-network runs. Bound waits and fail clearly for missing imagery; never silently substitute flat frames labelled 3D or retain a full image sequence in RAM.
5. Inspect start/middle/end, fast turns, tall buildings, steep slopes, coverage boundaries and gap transitions. Compare route overlays on/off for flattening and alignment. Try greater camera distance when clipping occurs; this does not establish collision avoidance. Record an unsupported-route outcome when clearance cannot be made acceptable.
6. Validate encoded duration, dimensions and cadence; actual scene motion; no blank, stale or low-resolution frames; uncropped readable attribution; foreground/background interruption; cancellation and temporary-file cleanup. Save measurements against the exact build revision.

## Acceptance gates

- Geometry: visible-reference comparison proves actual terrain/building changes across poses; a tilted still fails.
- Reliability: device evidence covers imagery readiness, route alignment, coverage edges, clearance, interruptions, cancellation and cleanup, with explicit unsupported cases.
- Resource budget: measured timing/memory/thermal results support an agreed export budget; no acceptable numerical budget is established here.
- Output: encoded file checks and visual review pass for duration, dimensions, cadence, scene motion and every-frame attribution.
- Permission: applicable provider/API/video permission is confirmed separately. A successful local capture cannot satisfy this gate.

Until all gates have evidence, retain the existing non-3D export behavior. No selector, dependency, account, upload or release action follows from this study alone.
