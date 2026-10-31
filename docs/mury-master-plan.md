# MURY 1.1 Master Completion Plan

> Execution: subagent-driven-development, one implementer at a time with task review; independent read-only QA may run in parallel. User authorization overrides skill commit steps: NO commits, pushes, merges or distribution.

**Goal:** Finish the existing local MURY implementation with an intentional Home journey, theme/settings flow and explicit native Files exports while preserving LARPING data and recording behavior.
**Architecture:** Reuse BrandTheme, ActivitiesStore, LocationTracker and existing image/video composers. Add only the missing dashboard and Files export boundary. Profile remains the entry point for Settings. No new service or dependency.
**Stack:** SwiftUI, SwiftData, MapKit, UIKit, AVFoundation, UniformTypeIdentifiers; Windows Swift syntax parser and native Node/PowerShell asset checks. iOS SDK/XCTest requires macOS.
**Spec:** User master brief dated 2026-10-30 and scope form: private ferbogar-uk/mury-ios, dedicated Home tab, Save to Files. Previous record: mury-1.1-plan.md.

## Global constraints
- Branch feature/mury-branding; HEAD base 7b7015b96e8c65e47cb334d3a2f7a94abba346fc. Preserve ALL existing uncommitted work.
- Original source ferbogar-uk/larping remains untouched. origin points to mury-ios; source push is DISABLED.
- Preserve rdyy.larping, signing, old workflows, SwiftData schemas, backup discriminator, seed flag, GPS algorithms/background behavior and HealthKit service.
- No new Photos permissions: explicit Save uses Files. Native sharing is not direct Instagram publishing.
- Pink light Canvas #FFF0F6 supersedes prior #FFE9F2. Dark Surface #4A2C3A (Pink) and #0B3D4A (Tiffany); main accents remain #FF4F98/#00C2CC. Derived accessible foreground/tint tokens are allowed and must be checked.
- Flow raster reference is present at design/branding/reference-board.png; traced vectors are derivative drafts, not original exact vector masters. Do not claim brand identity finalized.
- Do not commit/push or trigger Actions. No additional skills, dependencies, networking service or data migration.
- At most two repair cycles per demonstrated gap, as requested by user.

## Expected journey and acceptance
1. Fresh/invalid theme preference: explain MURY, show both visual theme previews (Tiffany first), require an explicit selection, persist it. Existing data/profile/appearance must not reset.
2. Home opens first. Show only recorded/imported real activities in personal summaries (source sample excluded), last-seven-days metrics and up to three recent activities. No real activity means an honest empty state and a recording CTA. Sport shortcuts open Record with that sport only while idle; ongoing recording must retain sport/event/state.
3. Profile -> Settings exposes theme and independent System/Light/Dark. Keep all existing backup/HealthKit/profile functionality. Change tokens without recreating store/recorder.
4. Share existing classic/map/video output; Save to Files exports the actual rendered PNG/MP4 via fileExporter. Disabled-before-ready, encoding/read/write errors and user cancellation receive correct feedback. Transparent PNG stays transparent; video temporary-file cleanup remains safe.
5. Verification evidence must distinguish source parsing, binary/contrast checks, web proof browser checks, iOS build/XCTest and real-device tests. No iOS execution is claimed unless actually performed.

## Review focus
- Samples/future dates/missing metrics must not appear as invented personal progress; deterministic summary tests.
- Home shortcuts or theme changes during recording must not change the current recording's sport, event title, timer or coordinates.
- First-launch onboarding/settings at large Dynamic Type must remain usable and announce selection; UI checks prepared, device runtime pending.
- File export cancelled/failed/unfinished must never show a successful save; PNG and MP4 data must survive source cleanup once export starts.
- A browser preview is not the native app; no native PASS may be inferred from it.

### Task 1: Brand alignment, onboarding and Settings
**Owner files:** Core/BrandTheme.swift; Features/Root/ThemeSelectionView.swift; Features/Profile/ProfileView.swift; new Features/Profile/SettingsView.swift; PinkCanvas/PinkSurface/TiffanySurface colour assets; larpingTests/BrandThemeTests.swift; existing larpingUITests/larpingUITests.swift and ScreenshotTests.swift; design/branding/branding-preview.html only if updating displayed tokens.
**Behavior:** Tiffany first, master palette values, explicit dual visual previews, explanatory onboarding, Profile entry to dedicated Settings. Keep storage keys and choices independent; no profile data rewrite. Reuse tokens rather than additional theme managers.
**Interfaces:** BrandTheme and ShareStyle APIs remain unchanged; Settings identifiers profile-theme, appearance-system/light/dark remain available after navigating Settings.
**Checks:** node scripts/check-branding.mjs; Swift parser on affected files; XCTest/UI tests written for navigation/persistence/invalid key. No iOS runtime claim.

### Task 2: Home and safe recording shortcuts
**Owner files:** new Features/Home/HomeDashboardView.swift and HomeSummary.swift; Features/Root/RootView.swift; Features/Record/RecordView.swift; new larpingTests/HomeSummaryTests.swift and larpingUITests/HomeDashboardTests.swift.
**Behavior:** Five tabs Home, Activities, Record, Stats, Profile. Home is data-backed; sample activities are excluded from personal summaries and recent activities. Last seven days means startOfDay(now)-6 days through now, inclusive. Recent real activities sorted newest, maximum three. Sport shortcuts select the Record tab and request a sport without changing an active recording. Existing Record callers retain a default initial sport. Preserve idle user-edited event names unless the sport changes; never reset the active event title when returning from Home.
**Interfaces:** Root owns tab selection and requested initial sport; RecordView(initialSport: SportType = .run) accepts an idle-only request. HomeDashboardView(onRecord: (SportType)->Void) uses ActivitiesStore environment. HomeSummary(activities:[CDActivity], now:Date, calendar:Calendar) produces weekly distance, duration, count and recent activities without persistence mutations.
**Checks:** deterministic unit cases for no data, samples, lower/upper date bounds, imports, nil metrics and newest-three order; UI cases for Home navigation and shortcut; parser and protected-file check.

### Task 3: Explicit Files exports
**Owner files:** Features/Activities/ShareActivityView.swift; new Core/ShareExportDocument.swift; new larpingTests/ShareExportDocumentTests.swift. Do not change composer interfaces unless a concrete export defect requires it.
**Behavior:** Save image/video for the selected ready template using fileExporter, PNG/MP4 types, sensible MURY filename. Encode/read data before presentation so video dismissal cleanup cannot invalidate export. Disabled until ready; successful save only on exporter success; user cancellation is quiet; failures show an error and permit retry. No photo-library permission or direct social posting.
**Interfaces:** ShareExportDocument conforms to FileDocument, offers init(image:UIImage) throws and init(videoURL:URL) throws, exposes contentType and immutable payload for export. Follow BackupFile's project pattern without changing BackupService.
**Checks:** PNG round-trip retains transparency/dimensions, video bytes preserved after original source file deletion, missing source throws, encoding/empty invalid content handled as appropriate. Swift syntax and existing share checks. XCTest runtime remains pending.

### Task 4: Consolidated validation and handover
**Owner:** Lead; read-only specialist reviews. Update docs/mury-master-progress.md, README.md, docs/ARCHITECTURE.md, docs/STATUS.md, docs/KNOWN_ISSUES.md and manual QA checklist as needed. No release workflow changes.
**Checks:** current branch/HEAD/remotes; full Swift source parse; actual asset contrast/icon format/protected hashes; git diff --check; independent task and combined review. Inspect local HTML proof with installed Vercel agent-browser after reading its core guide; small/desktop viewport, overflow, accessibility labels, console/network errors. Native iOS compilation, XCTest, simulator screenshot and real-iPhone upgrade/background GPS/HealthKit are NOT RUN/BLOCKED by missing local iOS SDK and lack of remote publication authorization. Provide a minimal manual test sequence.

## Integration order and ownership
Task 1 -> Task 2 -> Task 3 -> combined validation. No two implementation agents run simultaneously. Reviewers are read-only. Tasks 1 and 2 share only BrandTheme's unchanged interface; Task 2 Root imports new Home/Record; Task 3 shares unchanged BrandTheme/ShareStyle. All task file ownership is disjoint, except lead documentation after implementation.

## Release/rollback
No schema or permission migration. Revert only this session's local changes if requested; preserve prior work. Release consideration requires owner's visual approval, actual iOS build/XCTest and upgrade/device checks. Commit/push, CI dispatch and distribution need their own explicit authorization.

## Publication authorization — 2026-10-31

Owner explicitly selected “Approve commit, push and CI” in Nimbalyst: a reviewed commit of these MURY changes, push only feature/mury-branding to ferbogar-uk/mury-ios, then the existing macOS simulator build/tests using available Actions quota. Stop if extra spending or credential/security changes are needed. No main changes, signing changes or TestFlight upload. This supersedes earlier default no-commit/no-push constraints for this specific publication; all other boundaries remain. Commit review/push/CI are pending at this checkpoint.
