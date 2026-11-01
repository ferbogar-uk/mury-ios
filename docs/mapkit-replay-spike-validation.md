# MapKit replay prototype — delivery and validation

Status: local prototype implemented; native iOS acceptance remains unverified. Owner approved a bounded MapKit prototype on 1 November 2026.
Branch: feature/mury-branding. Baseline: 58ef22d0691afb1e1d2fd71c173479604f3a882f.
Approval update: owner subsequently explicitly requested commit, GitHub push and TestFlight connection/upload. No signing, secret, workflow or paid-provider changes are included.

## Expected local behavior
Activity details exposes a separate Replay route entry. The prototype opens paused, samples existing saved points by timestamp, offers play/pause/scrub at 1×/2×/4× and higher aerial/top-down/free camera choices. Pink/Tiffany and the existing sharing path stay intact. GPS discontinuities are explicitly unknown positions. Map imagery availability and quality remain provider/device dependent.

The prototype does not implement low-altitude collision avoidance, cinematic video export, a red/blue rebrand or exact historical pause reconstruction.

## Evidence
- Baseline branding/protection checker: PASS — four palettes, icon formats and protected SHA-256 values.
- Portable Swift timeline/playback checks: PASS — actual production source compiled/linked and executed with scripts/replay-smoke.swift on Windows. Command: swiftc larping/Features/Activities/ReplayTimeline.swift scripts/replay-smoke.swift -o <temporary executable>, then execute it. Final combined process PID59464 exit0.
- Regression: a new missing-tail-position assertion failed before the fix (PID46884 exit3221225501), then passed with the fix; marker/current metrics become unavailable beyond the final saved GPS sample.
- Whole-project Swift syntax parsing: PASS — swiftc -frontend -parse on all 50 app/unit/UI Swift files, PID59464 exit0. This is not Apple SDK type-checking.
- git diff --check: PASS, exit0; normal LF/CRLF advisory only.
- Native build/XCTest/UI/device checks: NOT RUN. This Windows environment has no Xcode/iOS SDK. Release preflight currently reports no registered workflows and no repository secrets in mury-ios; no native job has run.
- Independent final code review: NOT RUN. Timeline child hit account usage limit after executable checks; map child was interrupted at pending_init after syntax checks. Parent completed source/integration self-review; this does not replace independent review.

## Native verification still required
Use a disposable test simulator/device and existing test data. Do not clear owner activities. Project configuration currently targets iOS 26.5; select a matching installed SDK/runtime rather than silently lowering deployment settings.

1. On an authorized Mac, list available destinations:
   `xcodebuild -project larping.xcodeproj -scheme larping -showdestinations`
2. Choose a compatible simulator destination ID and run the new unit/UI cases:
   `xcodebuild -project larping.xcodeproj -scheme larping -destination 'platform=iOS Simulator,id=<ID>' -only-testing:larpingTests/ReplayTimelineTests -only-testing:larpingUITests/ReplayTests test`
3. Run the existing app test suite and confirm current share image/video/save flows remain usable.
4. On an iPhone, open saved city-centre/residential/bridge/tunnel/hilly routes in London plus a reference city. Record actual geometry/terrain, camera height/distance, occlusion, tile readiness and fallback. Setting realistic elevation is not proof of visible urban 3D; route overlays may affect terrain rendering.
5. Check play/pause/speed/seek, gestures/Free and Return to Follow, background and dismiss/reopen. Confirm labels never present a GPS gap as recorded pause history.
6. Check VoiceOver, Dynamic Type, Reduce Motion, both themes/appearances; inspect map attribution.
7. Try offline/cold tiles, long/sparse routes and low-memory conditions; measure thermal/memory behavior. Confirm no saved activity changes and live GPS/background/HealthKit still work.

These instructions are future manual checks, not evidence that they passed. Latest owner authorization covers a commit, push and existing TestFlight path, but does not supply missing signing/API credentials.

## Release preflight
GitHub CLI returned workflows total_count=0 for ferbogar-uk/mury-ios despite the existing YAML files. Repository secret listing returned no entries. Existing upload workflow requires IOS_DISTRIBUTION_P12, IOS_DISTRIBUTION_PASSWORD, IOS_PROVISIONING_PROFILE, APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID and APP_STORE_CONNECT_API_KEY. No secret values were read, changed or requested in chat. Workflow activation and secure signing/API setup must be resolved before a signed upload can succeed.
