# MURY 1.1 — implementation record

Base: 7b7015b96e8c65e47cb334d3a2f7a94abba346fc. Branch: feature/mury-branding. Destination: ferbogar-uk/mury-ios (private, empty remotely).

Approved: two independent Pink/Tiffany themes, mandatory first-launch selection, persistence, System/Light/Dark, Flow wordmark, consistent existing screens and share image/map/video. No new Explore, login, splits, backend or social integration. No commit, push, distribution build, signing changes or release.

## Tasks
- [x] Theme tokens and mandatory selection; retain stable tab/store identity during later theme changes.
- [x] Flow vector sources, icon/wordmark exports and palette review sheet.
- [x] Apply tokens to existing navigation, lists, profile, recorder, charts and import screens.
- [x] Pass resolved palette explicitly to UIKit image and video renderers; refresh previews on appearance changes.
- [ ] XCTest/UI coverage, static syntax/assets checks and protected-file diff review.
- [x] Update README/architecture/status/known limits.

## Validation and limits
Windows has Swift 6.4 for syntax parsing, but no iOS SDK/Xcode. XCTest, SwiftUI type checking, simulator visual checks, iPhone GPS/HealthKit and TestFlight upgrade remain pending. No runner will be dispatched without the required remote publication authorization.

Ruling: keep the backup app discriminator Larping, bundle rdyy.larping, HealthKit metadata, seed flag and SwiftData schema unchanged. A display rename is not a data migration.
Ruling: light-mode text/link tints are darker than the reference accent; button foregrounds are dark. Dark surfaces and accessible tints are derived tokens, not colors supplied in the reference.
Ruling: prepare code and tests locally despite lack of iOS test execution; do not claim a passing iOS build.

## Independent review
A fresh read-only reviewer checked the SwiftUI/storage/share integrations. Findings: P2 AppIcon alpha channel (regression check reproduced failure; export changed to RGB); P3 Photos permission copy still used the old display name (both configurations corrected). No additional concrete compile or state-management defect identified. Review is not an iOS typecheck or runtime test.

Ruling: existing recorder event-name behavior on tab reappearance and existing map projection/rendering remain unchanged; these precede this branding change, and broad fixes would expand scope. Their pre-existing limitations remain. New product features shown in the concept images remain excluded.

Implementation and test files are written locally. iOS execution and device/upgrade validation remain open. No commit or push.

## Final local verification
- node scripts/check-branding.mjs: PASS, all four text/foreground contrast combinations, RGB 1024px AppIcon variants, transparent wordmark format and 15 protected-file hashes. Icon regression was first observed failing (RGBA type 6 vs required RGB type 2), then passed after export correction.
- swiftc -frontend -parse over all tracked/untracked Swift source: PASS, 39 files. This checks syntax only.
- Native vector-export self-checks: PASS, single contour and contour-with-hole fixtures. PNG exports were visually inspected locally.
- git diff --check: PASS, with Windows LF/CRLF normalization warnings only. HEAD remains 7b7015b; branch feature/mury-branding; source push URL disabled.
- XCTest/unit/UI suites: WRITTEN, NOT RUN. No iOS SDK/typechecking/simulator/device/upgrade validation.

No deferred reviewer findings: the alpha packaging issue and Photos copy were corrected. No independent re-review of the corrections was requested; the asset regression check passed after the fix.
