# Home header logo — validation

Date: 2026-11-01
Branch: feature/mury-branding
Application source: 9e6bf8afe0725437bf1aab2f2ee962007049fc29

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
| New native iOS build / XCTest | BLOCKED / UNVERIFIED | GitHub API connection failures during CI dispatch; no run ID confirmed |
| Real iPhone rendering / accessibility layout | NOT RUN | Requires a future validated candidate on a device |
| New TestFlight upload | NOT RUN | Not authorized or triggered by this work |

The initial sandbox compiler launch could not start the executable; the owner-context hidden PowerShell fallback parsed both changed files successfully. This is syntax validation, not iOS SDK compilation.

## CI attempts

1. Approved push succeeded. Workflow lookup GET to https://api.github.com/repos/ferbogar-uk/mury-ios/actions/workflows/ci.yml failed with net/http: TLS handshake timeout before dispatch. A separate read-only workflow-list query failed at the same lookup.
2. One hidden retry was bounded to 60 seconds. It returned CI_RETRY_TIMEOUT_60_SECONDS with no confirmed run ID. Do not assume either a successful dispatch or completed tests from this timeout.
3. An independent public API HTTP probe eventually returned 200. This does not establish that authenticated CLI dispatch recovered or prove a global GitHub outage.

The previous 87-test success at source 8b08004 remains evidence for the earlier sharing package, not the new Home-header assertion.

## Next action and boundaries

When the GitHub API connection is responsive, first check the Actions run list for this exact source SHA to avoid a duplicate dispatch. If none exists, run ci.yml on feature/mury-branding and verify its actual build/XCTest logs.

Owner approved commit/push plus simulator CI only. Do not run ios-testflight.yml without separate explicit upload approval. No changes to main, Bundle ID, signing, secrets, workflows, activity storage, GPS or HealthKit were made here.
