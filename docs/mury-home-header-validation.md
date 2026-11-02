# Home header logo — validation

Date: 2026-11-02
Branch: feature/mury-branding
Application source: 9e6bf8afe0725437bf1aab2f2ee962007049fc29
Native CI tested commit: 3d0dc11f8fee9da4405655abf4ff2d29a70c0770 (documentation-only changes after application source)

## Changes

Home uses the existing adaptive LogoHorizontal asset in a centered native navigation header, rendered in its original colours at 32 pt high. The Home navigation title remains available for back navigation. HomeDashboardTests now checks that home-brand-logo exists.

The same commit includes the proposed staged roadmap. That document does not approve implementation of later stages.

## Actual verification

| Check | Result | Evidence |
|---|---|---|
| Existing branding/protected-content checker | PASS | node scripts/check-branding.mjs, exit 0 |
| Swift syntax for changed Home view and UI test | PASS | Swift frontend parse through hidden owner PowerShell, exit 0 |
| Whitespace check | PASS | git diff --check, exit 0 |
| Commit and push | PASS | 9e6bf8a pushed to origin feature/mury-branding |
| New native iOS build / XCTest | PASS | CI 41366450017: native Build and Test succeeded; 74 unit + 13 UI = 87 passed, zero failed or skipped |
| Real iPhone rendering / accessibility layout | NOT RUN | Requires a future validated candidate on a device |
| New TestFlight upload | NOT RUN | Not authorized or triggered by this work |

The initial sandbox compiler launch could not start the executable; the owner-context hidden PowerShell fallback parsed both changed files successfully. This is syntax validation, not iOS SDK compilation.

## CI attempts

1. Approved push succeeded. Workflow lookup GET to https://api.github.com/repos/ferbogar-uk/mury-ios/actions/workflows/ci.yml failed with net/http: TLS handshake timeout before dispatch. A separate read-only workflow-list query failed at the same lookup.
2. One hidden retry was bounded to 60 seconds. It returned CI_RETRY_TIMEOUT_60_SECONDS with no confirmed run ID. Do not assume either a successful dispatch or completed tests from this timeout.
3. An independent public API HTTP probe eventually returned 200. This does not establish that authenticated CLI dispatch recovered or prove a global GitHub outage.

4. On 2026-11-02, authenticated Actions listing succeeded and showed no run for the Home-header candidate. Dispatch then succeeded: [CI 41366450017](https://github.com/ferbogar-uk/mury-ios/actions/runs/41366450017), head 3d0dc11f8fee9da4405655abf4ff2d29a70c0770. Build, simulator preparation, Test and log upload all passed in 16m49s.

The complete 1,964-line test.log was downloaded and inspected. It contains 87 individually passed test cases, no failed/skipped test cases, and **TEST SUCCEEDED**. Suite totals are 74 unit and 13 UI tests, both with zero failures. Both HomeDashboardTests passed and each checked the existence of the home-brand-logo image. Full log retained locally at .superpowers/sdd/mury-home-header/ci-41366450017/test.log.

This run supplies native evidence for the Home-header assertion as well as the existing transparent-sharing tests. It does not verify real-device appearance or another app receiving a transparent image.

## Next action and boundaries

Native CI is complete. Next acceptance step is real-iPhone rendering, accessibility layout and receiving-app transparency checks on a future approved device candidate. No further CI rerun is needed for this documentation-only evidence update.

Owner approved commit/push plus simulator CI only. Do not run ios-testflight.yml without separate explicit upload approval. No changes to main, Bundle ID, signing, secrets, workflows, activity storage, GPS or HealthKit were made here.
