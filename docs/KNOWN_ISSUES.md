# iOS App — Known Issues / Non-issues

Things that look like bugs but aren't, plus real open gaps. Check here before
re-diagnosing from scratch.

## "Elevation gain always shows 0 / missing" — not a bug

`ActivityDetailView` and the record screen hide the elevation stat when
`elevationGainMeters <= 0`. On the iOS Simulator, a manually-set "Custom
Location" provides no altitude (`location.verticalAccuracy < 0`), so the
recorder never accumulates elevation — the stat is correctly hidden because
it's genuinely zero. Confirm on a real device, or via GPX import (GPX
elevation parses and threads through correctly).

## Simulator-only location debugging

Debug > Location > Custom Location in the simulator only sets a fixed point
(no movement, no altitude, no speed). Use a GPX-based simulated route in
Xcode's scheme location settings for realistic recording tests.

## Sample data only appears on a fresh install

The one-time seed (`SeedData`, flag `seedSampleDataV1`) fires only when the
database is empty AND the flag is unset. Use a separate fresh simulator install when testing seeds. Do not uninstall a data-bearing installation to obtain samples — deleting everything yourself never brings them back (by design).

## Upgrade validation must preserve installed data

MURY changes no SwiftData model or persistent schema. Validate an in-place upgrade over LARPING Build 1 after exporting a backup; do not uninstall or reset the data-bearing app. Historical schema experiments belong on disposable simulator installs. A failing migration must be investigated rather than concealed by deleting the store.

## Route map in detail needs a network

The map panels (activity detail + record) use Apple Maps, which needs a
network connection to render tiles. The **recorded data (activities, points,
stats) is always local and works offline**; only map imagery needs
connectivity. Offline the polyline renders over an empty gray basemap — data
is fine.

## Track points never duplicate on backup re-import — not a bug

Restore idempotency is keyed on the **activity** id: re-importing a backup
skips whole activities that already exist, so track points can't pile up
beneath them. If the activity was deleted in the meantime (the cascade removes
its points), re-importing revives the activity *and* its original points
exactly once. The only path that "regenerates" ids is `ActivitiesStore.create`
(live recording, GPX/HealthKit import), which is off the restore path
entirely and always allocates fresh points — so there is no scenario where a
re-import produces real duplicate track points.

## No true background iCloud sync (paid entitlement)

The app is fully offline and stores everything in SwiftData; it does NOT
auto-sync across devices. True CloudKit sync needs the iCloud capability —
**Apple Developer Program membership ($99/y)** + a container in signing
entitlements — not just code.

**What works today:** Profile → "Export all activities" (system file picker) →
save into **iCloud Drive** or Files; **Import backup** brings it back.

## Backup/restore is manual, not scheduled

Export/import both exist and restore is idempotent (skips existing ids, never
duplicates/deletes, rejects junk). Missing: scheduled/automatic backup, plus a
migration story for `BackupContainer.version` if the schema ever changes.

## Live-record notification is NOT built

No Dynamic Island / Lock Screen activity during recording, and no
Pause/Finish actions from a notification. ActivityKit Live Activities require
a **Widget Extension target** to define the presentation UI — the main app
can only start/update/end an activity. Adding it = a new Xcode target (not
just Swift files). Deferred by design; see `docs/STATUS.md` "Next".

## "Double location button on Record map" — gone

A default `MapUserLocationButton` was duplicating the custom toolbar button;
the default one was removed. Re-add the default (`mapControls`) and you'll
see the double again.

## Share: plain classic card is a transparent PNG; map cards are opaque

The classic template with **no photo** exports a transparent-background PNG
(white content with dark shadows) so it can be pasted on any backdrop. With a
photo, the card is photo + black dim, fully opaque. The map template + video
have their own opaque map background. So "the share image is always space
dark" is no longer true — only the map fallback (no network tiles) and the
photo-less classic video-era path use `spaceBlack`. Not a bug.

The **preview thumbnail** for that transparent card sits on a black backing
in `ShareActivityView` (`classicPreview`) purely so the white content is
visible in light mode — that backing is UI chrome only, not part of the
composed image. If the exported/shared/saved file ever looks like it has a
black background, that's a real regression (check `ShareImageComposer.compose`
still leaves the canvas untouched when `photo == nil`); the on-screen preview
having one is expected.

## Bundling fonts via the synchronized group silently fails

Xcode's `PBXFileSystemSynchronizedRootGroup` does **not** copy `.ttf` files
into the app bundle (hit with Domine). A future custom font would need either
a real `Copy Bundle Resources` entry plus an exception, or in-memory embed.
Don't drop a font into `larping/` and assume it ships.

## Route flyover video: recorded from the screen, permission question open

The flyover video is a screen recording of the live MapKit view (`RPScreenRecorder`), not rendered offline: it takes the real clip length, only works on a physical iPhone (the simulator usually reports recording as unavailable), and the first use shows a system permission prompt. Hold the phone still and do not leave the app while it records. Apple's licence wording for retained, user-shared videos of MapKit imagery has not been confirmed (see `docs/mury-3d-video-export-feasibility.md`); the recording keeps Apple's attribution visible in every frame, but confirm before a public release. Camera smoothness at ~30 updates/s and Apple Maps 3D coverage along a route are unmeasured until tested on a device.

## Apple Maps attribution/logo cannot be hidden

MapKit's terms of service require the Apple logo and legal attribution
overlay to remain visible on any map view — there's no public, compliant API
to remove or hide it. Clipping/cropping it out would violate Apple's usage
terms and risks App Store rejection, so Record and Activity Detail's map
views intentionally leave it as-is. Not a bug, not fixable within the rules.

## MURY button and link contrast

Use theme.accent + theme.onAccent for prominent branded buttons. Use theme.tint for normal-size text and links. The reference accents alone are not readable enough for white body-size labels. Destructive buttons retain native red/white styling. The checked palette pairs meet 4.5:1 in all four theme/appearance combinations; composited maps/photos and device rendering still require visual review.

## MURY validation is pending on iOS

Windows Swift parser and asset checks do not prove an iOS build. Run XCTest and simulator captures through an authorized macOS build after publication is separately approved, then verify in-place upgrade from 1.0 Build 1, recording while changing theme, locked-screen GPS and HealthKit on an iPhone. Do not uninstall the user's app or reset data for this check. First-launch UI coverage requires a separate fresh simulator install and skips on an existing installation.

## Flow source resolution

The editable SVG outlines were traced from the supplied raster board, rather than supplied as original designer vector masters. Review fine strokes at device scale before distribution. The fixed app icon has system light/dark/tinted variants; the in-app theme picker does not change the home-screen icon.

## Heart-rate / cadence fields: live recordings stay nil

`CDTrackPoint.heartRateBpm` / `cadenceRpm` are optional. Live recordings run
on iPhone GPS only, so they stay `nil` for everything recorded in-app. They
get populated only via **HealthKit import**: heart-rate samples are matched to
the imported workout's track points (nearest HR sample at-or-before each
point's timestamp). Cadence (`cadenceRpm`) remains always-nil — Apple Watch
exposes *step cadence*, not RPM, and we deliberately don't rename the field or
map it. Display code hides heart-rate UI when nil — an invisible gap, not a
bug.

## Heart-rate zones use the highest recorded heart rate

The zones in the activity detail are 60/70/80/90% of the highest heart rate
found in any real activity (`HeartRateZones.measuredMaxBpm`; sample activities
never count). There is no setting for it yet, so it is only as good as the
hardest effort recorded so far: it sits low if you have never gone all-out, and
every zone edge moves up when you set a new high. If no real activity has a
reading, the zones fall back to the open activity's own highest value and the
caption says so. A birth-year or manual max-heart-rate field is the natural
next step if this feels wrong. The section appears only with at least 10
readings, and opening the detail reads the heart rates of every activity once
(like the Stats screen), so it is built once on appear, not on every touch.

## HealthKit write is best-effort and silent

`HealthKitService.saveWorkout(from:)` guards on availability + authorization
and swallows errors — a failed/denied write never surfaces UI and never
blocks the local save. It also uses the iOS-17-deprecated
`HKWorkout(activityType:start:end:...)` initializer by design (the
`HKWorkoutBuilder` replacement targets live workout session collection,
overkill for a post-hoc mirror); expect the deprecation warning in builds.
The route's reported accuracy is re-claimed at the 50m ceiling the recorder
accepted, so HealthKit consumers never see accuracy better than what was
guaranteed.
## Existing recording save recovery limit

Finish stops the in-memory tracker before attempting the local database save. A persistence error is reported and rolled back, but automatic retry/crash recovery is not implemented; starting another recording clears the previous tracker route. This is a pre-existing limitation, not a verified new Home regression.

## HealthKit import reproduction candidates

Read-only QA identified two existing paths needing device verification: heart-rate reads gate on write authorization status, and route import handles completion before the final location batch. Missing heart rate or final route points are reproduction candidates, not demonstrated MURY regressions. The protected HealthKit service remains unchanged.

### Flyover polish (build 7 candidate): unverified on a device

Marker drop height (360 pt offset), the 450 m / 65 degree follow camera (MapKit may clamp the pitch, so it may look less tilted than asked), the 10 s route smoothing, the map pre-load sweep (reduces tile gaps, does not remove them) and the Share template carousel fix (one uniform `ForEach` over `ShareTemplate.allCases`; the half-way stop was only diagnosed from the layout, not reproduced) all need a check on a physical iPhone. The screen-recording permission prompt still appears every time; the planned fix is an in-app rendered video, which is unproven (see `docs/mury-3d-video-export-feasibility.md`).

Round 2 (build 8 candidate): the carousel is now `ScrollView` + `.scrollTargetBehavior(.paging)` + `.scrollPosition(id:)`; the earlier `TabView(.page)` fix did not cure the half-way stop. Still needs a device check. MapKit tile cache cannot be cleared or made offline by the app, so the invisible warm-up may or may not reduce gaps.

### Render in app (experimental, build 9 candidate)

Nothing about `FlyoverRenderer` has run on a device yet. Unknown until tested: whether snapshots at 60-65 degrees show real 3D terrain/buildings (the feasibility doc geometry gate), whether `snapshot.point(for:)` keeps the route aligned at high pitch, seconds per frame (a 15 s clip is 300 snapshots), memory and heat, and whether missing imagery shows as blank frames (MapKit does not report tile readiness, so a blank frame cannot be detected). The credit is plain text "Apple Maps", not Apple's logo and legal link. Whether Apple's terms allow keeping and sharing such videos is unresolved (see `docs/mury-3d-video-export-feasibility.md`); the button is labelled experimental on purpose and should not be promoted until that is settled. Screen recording stays as the alternative.

Linux core-logic CI is pinned to `ubuntu-24.04`: `ubuntu-latest` became Ubuntu 26.04 (Nov 2026) and `swift-actions/setup-swift@v2` does not support it ("Version 26.04 of Ubuntu is not supported"). Move back to `ubuntu-latest` only when the action supports it.

Build 9 device test of Render in app: the scenery looked good, but (1) the progress card looked frozen until the first frame, (2) the route line jumped around the frame (`Snapshot.point(for:)` is not usable at high pitch), (3) the start of the video sat still. Build 10 candidate: live preview and elapsed clock, own projection (`FlyoverProjection`, field of view 30 degrees is an assumption: if the line is consistently off, that constant is the fix), 3 requests in flight, and the still overview shortened from 12 to 5 percent of the clip (orbit 20 to 27). Not yet checked on a device.


## Watch standalone recording: unverified on a device

Written and unit-tested for the logic only; CI cannot run GPS, the heart sensor or the battery. Open points: background location relies on the workout session (no `allowsBackgroundLocationUpdates` set, to avoid a crash if the mode is missing); the watch recording is saved only on the watch until Stage 2; its workout is still discarded in Health, so it does not count for the Apple rings yet (decision pending).

## Place in the automatic title needs the network and sends one coordinate to Apple

`PlaceNamer` uses `CLGeocoder`. Offline, or after 6 s without an answer, the title stays without place ("Corrida da manhã"). It is not retried later. The default title is Portuguese on purpose (user's choice) while the rest of the app is English. Sync of watch recordings is unverified on a device (the CI cannot pair a watch).

## Rendered route line may drift; MapKit-based projector crashed

Build 14 positioned the line through a hidden `MKMapView` and the app crashed during rendering; it was removed (the cause is not confirmed). The line again uses the assumed-FOV `FlyoverProjection` and may slide against the map. Do not retry the hidden-map-view idea without a crash log.


### Render in app is switched off (build 22)

Device numbers (builds 19-21, iPhone, iOS 27): the memory guard stopped a 30 s render at frame 213-239 / about 2.8 GB every time. Growth per frame: snapshot 9-10 MB, draw 1-3, encode 0, screen -3 (so the full-screen preview is not the cause). Scale 1.5 pictures, a snapshotter on its own queue and `cancel()` on arrival (build 21) did not change it. The 3D map engine (`.hybridFlyover` snapshots) keeps what it loads. `FlyoverView.offersRenderInApp = false` hides the button; `FlyoverRenderer`, the crash report and the memory guard stay. Ideas not yet tried: a normal (non-3D) satellite map for the frame-by-frame render, or only 15 s clips. Screen recording (*Record video*) is the working way to make the video, as with Strava's live flyover.


### Record video: permission alert used to cancel the first recording (build 23)

Build 22 on a phone: *Record video* showed "Flyover stopped because MURY left the screen" (the system screen-recording permission alert makes the scene `.inactive`, and the scene-phase handler stopped on anything but `.active`), and the next try showed "Failed due to attempting to stop a recording that wasn't in recording state" (the earlier cancelled attempt finished starting later and its cleanup stopped the new recording). Now only `.background` stops a run, and `finishRun` checks `isRecording` first with a plain message. Unverified on a device.


## Video and Health notes (builds 26 to 36)


- **Render in app is on again, for 8 s clips only (build 26)**: see the entry "Render in app is switched off (build 22)": the cause is unchanged (MapKit keeps ~10 MB per snapshot), so longer clips would be stopped by the memory guard. The 15/30/60 s picker applies to Preview and Record video, not to Render in app. The Apple map has no sky setting.



- Render in app waiting screen plays `larping/RenderSample.mp4` (muted loop, made-up sample, not a real run) when that file is in the bundle; without it the screen is the plain black "Making your flyover video…". The file is supplied by Ricardo (generated outside the app) and bundled automatically (synchronized group). Unverified: memory use of the playing video alongside the 2800 MB render guard.

- Build 28 reopened Render in app for 15 / 30 / 60 s on purpose, to test. Expect the 2800 MB guard to stop long clips; the stop message starts with "start N MB": if N is already around 2000, the memory is taken before the render begins (the build 26 print showed 2,679 MB at frame 60 of an 8 s render), if it is a few hundred MB the growth is the snapshots themselves. Not known yet which. The old (build 9/10) renders used the same MKMapSnapshotter code; the earlier clip length they finished at is not recorded.
- HealthKit cannot tell an app whether a read was denied. An empty Health looks the same as "no workouts", so Profile points to Settings → Health → Data Access & Devices → MURY. The code never checks read status.
- Background import (Health waking MURY when a workout is saved) depends on the HealthKit background-delivery entitlement being accepted at signing and on iOS choosing to deliver; treat it as unproven until seen on a phone. New workouts always appear when MURY is opened.
- Workouts imported before build 31 have no Health id; they are matched by start time (within 60 s) so the backfill does not duplicate them.
- First launch needs all four body fields (birth date, sex, height, weight); units are metric only until the Settings phase.
- Tab bar item colours are set through `UITabBarAppearance` in `RootTabView.init`, while the bar background also comes from SwiftUI `.toolbarBackground`. If a future change makes SwiftUI rebuild the tab bar appearance, unselected icons can fall back to iOS grey; check on a phone after tab bar changes.
- Since build 33 MURY asks Health for 23 types, but only workouts, routes, heart rate, energy and body details are shown so far; the rest (VO2 max, HRV, resting heart rate, steps, cycling and running power and the like) get screens in the progress phase. App Store review expects requested data to be used, so those screens must ship before an App Store submission.

## Indoor types can't be recorded yet — not a bug

Strength, Treadmill, Yoga and the other indoor types (build 36) only arrive from Apple Health. The Record menu and Home shortcuts list just the outdoor types, because the recorder is GPS-only. Timer-only indoor recording is phase 7.
