# MURY 1.1 — validation and handover

2026-10-31. Local development on feature/mury-branding. Source implementation is written; native acceptance is outstanding. No release readiness or TestFlight upload is claimed.

## Implemented behavior

- Explicit first-launch Tiffany Blue/Pink choice with both previews; persisted theme independent of appearance. Profile → Settings changes theme and System/Light/Dark. Existing profile values and SwiftData schema retain their keys.
- Home refreshes its local date on foreground activation and calendar-day change. Home is the first of five tabs. Personal seven-day totals and newest-three cards exclude samples/future activities; imports are included and history is untouched. Recording shortcuts are consumed once and only applied while idle.
- Existing classic/map/video sharing captures selected theme tokens. Save to Files prepares immutable ready PNG/MP4 bytes, preserves transparent PNG output and offers quiet cancellation/retryable failure feedback. Native sharing remains available; no direct Instagram posting or new Photos permission.
- Flow wordmark/symbol SVGs and PNG/icon assets are traced derivative drafts from the supplied board. Final visual identity requires owner review. In-app theme does not change the fixed home-screen icon.

## Executed checks

| Check | Result | Evidence / scope |
|---|---|---|
| Swift frontend syntax | PASS | swiftc -frontend -parse across all 46 Swift app/unit/UI files, exit 0. Does not typecheck SDK APIs, build or run tests. |
| Asset/contrast/protection | PASS | node scripts/check-branding.mjs, exit 0: all four palettes meet tested text contrast; 1024px RGB app icons, transparent wordmark; 15 protected service/model/plist/entitlement/workflow hashes unchanged. |
| Whitespace | PASS | git diff --check under existing repository normalization, exit 0; LF-to-CRLF advisories remain. It covers tracked diff; untracked Swift files were included in syntax parsing. |
| Repository baseline | PASS | feature/mury-branding; HEAD and local main both 7b7015b96e8c65e47cb334d3a2f7a94abba346fc. origin=mury-ios; source push DISABLED. No commits/pushes performed. |
| Independent task source reviews | PASS | Brand/Settings, Home/Record, Files export each approved for source integration. These are AI source reviews, not execution evidence. |
| Static HTML proof | PASS | Installed Vercel agent-browser at 1440×1000 and 390×844: no horizontal overflow, no page errors, no external resource requests; screenshots inspected. This is a static palette proof, not SwiftUI. |
| Combined final review | PASS (source only) | Whole-branch review found Home date staleness and missing Home screenshots; both corrected and independently re-reviewed with no new breakage. Native acceptance remains pending. |

Button foreground/fill contrast from actual assets: Pink light 5.36:1, Pink dark 7.02:1, Tiffany light 5.39:1, Tiffany dark 6.83:1. Composited photos/maps and native rendering still need visual inspection.

One lead whitespace invocation overriding core.autocrlf=false reported CRLF bytes in RootView as trailing whitespace (exit 2). The normal repository-aware check passed without changing source or repository configuration.

## Native acceptance

| Acceptance criterion | Status | Required evidence |
|---|---|---|
| iOS framework typecheck, build/link and target membership | NOT RUN | Xcode/macOS build. xcodebuild is unavailable on this Windows host. |
| Theme choice/persistence, profile retention, independent appearance | NOT RUN | XCTest/UI tests plus fresh simulator and data-bearing upgrade checks. |
| Home summary/request tests | NOT RUN | HomeSummaryTests and HomeDashboardTests. Source includes calendar/DST, sample/future, nil/import and request lifecycle cases. |
| Active/paused tracker identity and background GPS | NOT RUN | Real iPhone Home shortcut/theme-return and locked-screen recording sequence. |
| Build 1 upgrade/history/backup compatibility | NOT RUN | In-place upgrade without uninstall; compare backup IDs, fields and track points. |
| HealthKit import/write and denial paths | NOT RUN | iPhone with known Health fixtures and permission cases. |
| PNG alpha, MP4 playback, Files success/cancel/failure/retry | NOT RUN | XCTest plus native Files provider and real exported media checks. Arbitrary Data fixture proves byte ownership only. |
| Dynamic Type, VoiceOver, four native theme/appearance combinations | NOT RUN | Simulator/device rendered inspection and accessibility journeys. |

The optional portable Windows summary harness was NOT RUN: automatic approval review rejected its scratch-file write outside the limited ownership list. It was skipped without a workaround. No passing XCTest or regression runtime result is inferred from parser success.

## Material limits

- Existing Finish stops the in-memory tracker before persistence; a failed save is reported/rolled back but no unsaved-route retry or force-quit recovery is implemented.
- Existing HealthKit heart-rate authorization and final-route-batch handling are reproduction candidates from source review, not demonstrated MURY regressions. Protected service code remains unchanged.
- Samples remain in existing Activities/Stats/history; Home alone filters them from personal summaries.
- No new backend, cloud sync, Watch app, automatic backups, Explore/login/social feed or direct Instagram integration was added.

## Where to review and next step

Open [the palette/asset proof](../design/branding/branding-preview.html), [master plan](mury-master-plan.md), [progress record](mury-master-progress.md) and [iPhone checklist](mury-device-qa.md). The native app must be opened with Xcode on macOS.

Keep the branch and uncommitted work in place. Owner visual review and explicit authorization for commit/push and a non-distribution macOS validation run are needed before remote CI can supply native evidence. The existing CI workflow has a manual simulator build/test entry; it has not been dispatched. Signing, secrets and the TestFlight workflow remain unchanged. A TestFlight upload requires separate explicit authorization.

## Remote build readiness check

Git ls-remote origin succeeded with prompts disabled (exit 0, no refs returned), confirming read access to the currently empty private origin through existing Git credentials. This does not prove push rights. The GitHub connector returned 404 for mury-ios, so connector access is not confirmed; existing Git/authenticated browser are the fallback for authorized publication/Actions work. Signing credentials and Actions quota in the new repository have not been verified. No secrets or workflow settings were changed.

## Publication authorization — 2026-10-31

Owner explicitly selected “Approve commit, push and CI” in Nimbalyst: a reviewed commit of these MURY changes, push only feature/mury-branding to ferbogar-uk/mury-ios, then the existing macOS simulator build/tests using available Actions quota. Stop if extra spending or credential/security changes are needed. No main changes, signing changes or TestFlight upload. This supersedes earlier default no-commit/no-push constraints for this specific publication; all other boundaries remain. Commit review/push/CI are pending at this checkpoint.
