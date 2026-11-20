# Phase 1: Health and profile — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** MURY reads Apple Health broadly (workouts, routes, heart rate, profile characteristics), backfills 90 days of workouts with routes, keeps importing new ones, and opens with a first-launch flow that confirms the profile and asks three interest questions.

**Architecture:** Decision logic (which Health workouts to import, how Health and hand-typed profile values merge, profile validation) lives in Foundation-only `nonisolated` files so it is tested on Linux (`scripts/test-core-logic.sh`) and in macOS CI. HealthKit calls stay in `HealthKitService` and a new `HealthSync`; screens stay thin. Foreground sync is the guaranteed path; background delivery is an add-on.

**Tech Stack:** SwiftUI, SwiftData, HealthKit, XCTest. No new dependencies, no networking.

**Spec:** `docs/superpowers/specs/2026-11-20-mury-health-profile-home-design.md` (Slice 1 and "How the phases run").

## Global Constraints

- Everything stays on the device; no networking is added.
- `MainActor` is the default isolation; Foundation-only types are `nonisolated` (follow `Core/Models/Activity.swift`).
- New files under `larping/` are picked up automatically (synchronized groups). Pure files must also be added to the file list in `scripts/test-core-logic.sh` (and their tests to its test list).
- Per `CLAUDE.md`, update README, `docs/ARCHITECTURE.md`, `docs/STATUS.md`, `docs/KNOWN_ISSUES.md` in the same change.
- Verification is CI only (no Mac). TestFlight only with Ricardo's explicit yes, from a green `main` commit. Build number goes to 31.
- Nothing may look finished without working. Say plainly what was not testable on a device.
- MURY writes its own finished activities to Health with metadata `larping.activityID`; those must never be imported back.
- Merge rule for profile values: the newest value wins, and the profile records where each value came from (`health` or `manual`).
- Backfill window: 90 days.

## Review Focus

- Running the backfill twice imports nothing the second time (Task 1, Task 2).
- MURY's own workouts that were written to Health are not imported back (Task 1).
- A workout without a route imports without a map instead of failing (Task 4).
- Workouts older than 90 days, or with zero duration, are skipped (Task 1).
- Health denied or empty: onboarding still finishes with manual height, weight, birth date and sex (Task 3, Task 5).
- Birth date in the future, height or weight of zero or absurd size are rejected (Task 3).
- Hundreds of workouts in Health: imports run one at a time so memory stays flat (Task 4).

---

### Task 1: Which Health workouts to import (pure rules)

**Files:**
- Create: `larping/Core/Health/HealthImportRules.swift`
- Create: `larpingTests/HealthImportRulesTests.swift`
- Modify: `scripts/test-core-logic.sh` (add the source file and `HealthImportRulesTests` to the lists)

**Interfaces:**
- Produces:
  - `nonisolated struct HealthWorkoutRecord: Equatable { let externalID: String; let startedAt: Date; let endedAt: Date; let durationSeconds: Int; let writtenByMury: Bool }`
  - `nonisolated struct ExistingImport: Equatable { let externalID: String?; let startedAt: Date }`
  - `nonisolated enum HealthImportRules { static let backfillDays = 90; static func select(_ records: [HealthWorkoutRecord], existing: [ExistingImport], now: Date, days: Int = backfillDays) -> [HealthWorkoutRecord] }`

- [ ] **Step 1: Write the failing tests** in `HealthImportRulesTests` (same style as `WatchImportTests`, fixed `now`):
  - `testKeepsRecentNewWorkout`: one record 3 days old, no existing → returned.
  - `testSkipsOlderThanNinetyDays`: record 91 days old → empty; record 89 days old → kept.
  - `testSkipsMuryOwnWorkouts`: `writtenByMury == true` → empty.
  - `testSkipsZeroDuration`: `durationSeconds == 0` → empty.
  - `testSkipsSameExternalID`: existing with equal `externalID` → empty.
  - `testSkipsEarlierManualImportByStartTime`: existing with `externalID == nil` and start within 60 s of the record's start → empty; 61 s apart → kept.
  - `testSecondRunImportsNothing`: select once, turn the result into `ExistingImport`s, select again → empty.
  - `testResultIsOldestFirst`: three records in any order come back sorted by `startedAt` ascending.
- [ ] **Step 2: Run** `bash scripts/test-core-logic.sh` after adding the names to the script. Expected: FAIL (type not defined).
- [ ] **Step 3: Implement** the three types in `HealthImportRules.swift`. Filter, then sort ascending.
- [ ] **Step 4: Run** the same command. Expected: all tests PASS.
- [ ] **Step 5: Commit** `feat: pure rules for which Health workouts to import`.

### Task 2: Remember where an activity came from

**Files:**
- Modify: `larping/Core/Models/CDActivity.swift` (add `var externalID: String?`)
- Modify: `larping/Core/BackupFormat.swift` (add `let externalID: String?` to `BackupActivity`)
- Modify: `larping/Core/BackupService.swift` (write and read the field)
- Modify: `larping/Features/Activities/ActivitiesStore.swift` (`create(... externalID: String? = nil ...)` and a method `existingImports() -> [ExistingImport]` for activities whose `source == "healthkit_import"`)
- Test: `larpingTests/BackupFormatTests.swift`, `larpingTests/ActivitiesStoreTests.swift`

**Interfaces:**
- Consumes: `ExistingImport` (Task 1).
- Produces: `ActivitiesStore.create(..., externalID: String? = nil, ...)`; `ActivitiesStore.existingImports() -> [ExistingImport]`.

- [ ] **Step 1: Write the failing tests:**
  - `testBackupRoundTripKeepsExternalID` (BackupFormatTests): encode and decode an activity with `externalID == "ABC"` → equal.
  - `testOldBackupWithoutExternalIDStillDecodes`: JSON without the key decodes with `externalID == nil`.
  - `testCreateStoresExternalID` and `testExistingImportsListsOnlyHealthImports` (ActivitiesStoreTests, in-memory store as the existing tests do).
- [ ] **Step 2: Run** `bash scripts/test-core-logic.sh` (backup tests). Expected: FAIL.
- [ ] **Step 3: Implement** the field and methods. The field is optional so SwiftData migrates lightly and old backups decode.
- [ ] **Step 4: Run** the same command. Expected: PASS. The store tests run in macOS CI.
- [ ] **Step 5: Commit** `feat: remember the Health id of imported activities`.

### Task 3: Profile model, merge rule and storage (pure)

**Files:**
- Create: `larping/Core/UserProfile.swift`
- Create: `larpingTests/UserProfileTests.swift`
- Modify: `scripts/test-core-logic.sh`

**Interfaces:**
- Produces:
  - `nonisolated enum BiologicalSex: String, Codable, CaseIterable { case female, male, other }`
  - `nonisolated enum ProfileSource: String, Codable { case health, manual }`
  - `nonisolated enum FitnessLevel: String, Codable, CaseIterable { case beginner, intermediate, advanced, pro }`
  - `nonisolated enum UsageGoal: String, Codable, CaseIterable { case buildHabit, trainForEvent, stayHealthy, loseWeight, buildMuscle }`
  - `nonisolated struct ProfileValue<T: Codable & Equatable>: Codable, Equatable { let value: T; let source: ProfileSource; let updatedAt: Date }`
  - `nonisolated struct UserProfile: Codable, Equatable` with optional `birthDate`, `sex`, `heightCm: ProfileValue<Double>?`, `weightKg: ProfileValue<Double>?`, plus `sports: [SportType]`, `goal: UsageGoal?`, `level: FitnessLevel?`
  - `UserProfile.merging(health: HealthProfileSnapshot) -> UserProfile` where `HealthProfileSnapshot` carries the optional Health values and their sample dates; newest `updatedAt` wins per field.
  - `UserProfile.validationIssues(now: Date) -> [String]`; `age(now:) -> Int?`
  - `nonisolated enum ProfileStorage { static func load(_ defaults: UserDefaults) -> UserProfile; static func save(_ profile: UserProfile, to defaults: UserDefaults) }`

- [ ] **Step 1: Write the failing tests:**
  - `testNewerHealthWeightBeatsOlderManual` and `testNewerManualWeightBeatsOlderHealth` (assert value and `source`).
  - `testHealthFillsOnlyMissingFields`: manual height stays when Health has none.
  - `testFutureBirthDateIsInvalid`, `testBirthDateOverOneHundredFiftyYearsIsInvalid`.
  - `testHeightZeroOrOver300cmIsInvalid`, `testWeightUnder20kgOrOver400kgIsInvalid`.
  - `testAgeOnBirthdayAndDayBefore` (fixed dates).
  - `testStorageRoundTripAndEmptyDefaultsLoadEmptyProfile`, using `UserDefaults(suiteName:)` that the test clears.
- [ ] **Step 2: Run** `bash scripts/test-core-logic.sh`. Expected: FAIL.
- [ ] **Step 3: Implement.** `ProfileStorage` stores JSON under key `"userProfile"`; a corrupt value loads as an empty profile.
- [ ] **Step 4: Run** the same command. Expected: PASS.
- [ ] **Step 5: Commit** `feat: on-device profile with newest-value-wins merge`.

### Task 4: Read Health broadly and import in one pass

**Files:**
- Modify: `larping/Core/Health/HealthKitService.swift`
- Create: `larping/Core/Health/HealthSync.swift`
- Modify: `larping/Features/Activities/ImportHealthKitView.swift` (use the shared importer; drop the write-status gate)
- Modify: `larping.xcodeproj/project.pbxproj` (`INFOPLIST_KEY_NSHealthShareUsageDescription` for the main app target, both configurations, so it says MURY also reads workouts, routes, heart rate, calories and your body details; the watch target keeps its own text)

**Interfaces:**
- Consumes: `HealthImportRules.select`, `ActivitiesStore.create(externalID:)`, `ActivitiesStore.existingImports()`, `UserProfile.merging`.
- Produces:
  - `HealthKitService.requestAuthorization()` now reads: workouts, routes, heart rate, active energy, height, body mass, date of birth, biological sex (writing stays workouts and routes).
  - `HealthKitService.fetchWorkouts(since: Date) async throws -> [HKWorkout]` (no limit).
  - `HealthKitService.readProfileSnapshot() async -> HealthProfileSnapshot`.
  - `@MainActor enum HealthSync { static func run(store: ActivitiesStore, since days: Int = 90) async -> HealthSyncResult }` with `struct HealthSyncResult { let imported: Int; let skipped: Int; let failed: Int }`.
  - `HealthSync.importOne(_ workout: HKWorkout, sport: SportType, store: ActivitiesStore) async throws` (the body moved out of `ImportHealthKitView.importWorkout`; sets `source: "healthkit_import"` and `externalID: workout.uuid.uuidString`).

- [ ] **Step 1: Implement** the new read set and the two fetch functions. A record's `writtenByMury` is true when `workout.metadata?["larping.activityID"]` exists.
- [ ] **Step 2: Implement `HealthSync.run`:** fetch since the window start, map to `HealthWorkoutRecord`, run `HealthImportRules.select` against `store.existingImports()`, then import the selected workouts one at a time (await each before the next). A route that comes back empty imports without track points; a failure on one workout counts as `failed` and the loop continues.
- [ ] **Step 3: Refactor `ImportHealthKitView`** to call `HealthSync.importOne`, and show the workout list whenever Health is available, whatever the write status. Remove the `status == .sharingAuthorized` early return in `refresh()`.
- [ ] **Step 4: Update the usage-description text** in `project.pbxproj`.
- [ ] **Step 5: Verify** with the command in `CLAUDE.md` (`xcodebuild ... build`) through CI. Expected: `BUILD SUCCEEDED`, no new warnings. There is no unit test here on purpose: HealthKit cannot run in CI. The device check is in Task 8.
- [ ] **Step 6: Commit** `feat: read Health broadly and backfill 90 days of workouts`.

### Task 5: Sync on every foreground, background delivery as an extra

**Files:**
- Modify: `larping/larpingApp.swift` (run `HealthSync.run` when the app becomes active and onboarding is done; throttle to once per 10 minutes)
- Create: `larping/Core/Health/HealthBackgroundDelivery.swift`
- Modify: `larping/larping.entitlements` (add `com.apple.developer.healthkit.background-delivery` = true)

**Interfaces:**
- Consumes: `HealthSync.run`.
- Produces: `HealthBackgroundDelivery.start(store: ActivitiesStore)`, which registers an `HKObserverQuery` on workouts and calls `enableBackgroundDelivery(for: .workoutType(), frequency: .immediate)`; its handler runs `HealthSync.run` and always calls the completion handler.

- [ ] **Step 1: Implement the foreground sync** with a stored `lastHealthSync` date and the 10-minute throttle (a pure helper `shouldSync(last: Date?, now: Date) -> Bool` in `HealthImportRules`, with tests `testSyncsWhenNeverSynced`, `testSkipsWithinTenMinutes`, `testSyncsAfterTenMinutes`).
- [ ] **Step 2: Implement background delivery** and the entitlement.
- [ ] **Step 3: Verify** the build through CI. If code signing rejects the new entitlement (the App ID lacks the capability), remove only the entitlement line and `HealthBackgroundDelivery.start` call, keep foreground sync, and record in `KNOWN_ISSUES.md` that new workouts appear when MURY is opened. Do not tell Ricardo that background import works unless he has seen it work on his phone.
- [ ] **Step 4: Commit** `feat: sync Health on foreground; background delivery when allowed`.

### Task 6: First-launch flow

**Files:**
- Create: `larping/Features/Onboarding/OnboardingView.swift`
- Create: `larping/Features/Onboarding/ProfileFormView.swift`
- Modify: `larping/larpingApp.swift` (after the theme choice, show `OnboardingView` until `@AppStorage("onboardingDone")` is true)

**Interfaces:**
- Consumes: `HealthKitService.requestAuthorization`, `readProfileSnapshot`, `HealthSync.run`, `UserProfile`, `ProfileStorage`.
- Produces: `OnboardingView(onFinished: () -> Void)`; `ProfileFormView(profile: Binding<UserProfile>)` (birth date, sex, height, weight, with inline messages from `validationIssues`).

- [ ] **Step 1: Build three steps:** (1) Health: a "Connect Apple Health" button and a "Not now" button; after connecting it reads the profile snapshot, then runs the 90-day backfill with a visible count; (2) profile form, pre-filled from Health when present, manual otherwise, "Continue" disabled only while `validationIssues` is non-empty; (3) interests: sports (multi-select from `SportType`), goal, level.
- [ ] **Step 2: Save** with `ProfileStorage.save` at the end of step 2 and step 3, and set `onboardingDone`.
- [ ] **Step 3: Add UI tests** in `larpingUITests`: launch with the theme seeded, skip Health, fill the form with valid values, pick interests, and land on the tab bar. Add `testFutureBirthDateBlocksContinue`. The existing seeded-theme launch argument must also skip onboarding for older UI tests (new env var `MURY_UI_TEST_SKIP_ONBOARDING`).
- [ ] **Step 4: Verify** through CI (unit and UI tests). Expected: green.
- [ ] **Step 5: Commit** `feat: first-launch flow with Health, profile and interests`.

### Task 7: Profile screen shows the real Health state

**Files:**
- Modify: `larping/Features/Profile/ProfileView.swift` (the Health section)

- [ ] **Step 1: Replace** the "HealthKit connected" logic (which reads write status) with: a "Sync Health now" button that runs `HealthSync.run` and shows "Imported N, skipped M"; keep the existing note about writing activities.
- [ ] **Step 2: Verify** the build through CI.
- [ ] **Step 3: Commit** `fix: Profile Health section reflects reading, with a sync button`.

### Task 8: Docs, version and device checklist

**Files:**
- Modify: `README.md`, `docs/ARCHITECTURE.md`, `docs/STATUS.md`, `docs/KNOWN_ISSUES.md`, `larping.xcodeproj/project.pbxproj` (`CURRENT_PROJECT_VERSION` 31)

- [ ] **Step 1: Update docs:** Health section in README (what is read, 90-day backfill, foreground sync), ARCHITECTURE (new files and the merge rule), STATUS (build 31 entry), KNOWN_ISSUES (HealthKit cannot say whether read was denied, so an empty Health looks like "no workouts"; background delivery status; a single imported walk without a route has no map).
- [ ] **Step 2: Open a pull request** from the phase branch and wait for green CI (build-and-test and core-logic). Do not merge or upload without Ricardo's yes.
- [ ] **Step 3: Hand Ricardo this device checklist** for TestFlight build 31: (a) fresh install shows the Health step, then the profile with values from Health, then interests; (b) last week's walks recorded on the Watch appear with routes; (c) opening the app a second time adds no duplicates; (d) MURY's own recorded activities do not appear twice; (e) refusing Health still reaches the Home with manual values; (f) record a walk in the Apple Exercise app, open MURY, and it appears.
- [ ] **Step 4: Commit** `docs: phase 1 Health and profile, build 31`.

---

## Self-review

- Spec coverage: broad Health read (Task 4), 90-day backfill with routes (Tasks 1, 4), automatic new workouts (Task 5), profile with newest-wins merge (Task 3), first-launch flow with manual fallback and interests (Task 6), phase completion rule (Task 8 checklist).
- Not in this phase on purpose: editable profile in Settings (phase 2), Home (phase 3), weather (phase 4).
- Types match across tasks: `ExistingImport` and `HealthWorkoutRecord` (Tasks 1, 2, 4), `UserProfile.merging(health:)` and `HealthProfileSnapshot` (Tasks 3, 4, 6).
