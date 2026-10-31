# SDD ledger — plan: docs/mury-master-plan.md

## Baseline 2026-10-30
- Current branch feature/mury-branding; HEAD 7b7015b96e8c65e47cb334d3a2f7a94abba346fc. Previous MURY implementation is uncommitted and must be preserved.
- Actual asset checker rerun: PASS for four palettes, icon formats and 15 protected files.
- New scope confirmed in structured form: origin mury-ios, dedicated Home, Save to Files.
- Installed Vercel agent-browser detected; help read. iOS SDK/Xcode are unavailable on Windows.

## Pre-flight scan
| Task/pair | Shared interface or internal contract | Result |
|---|---|---|
| 1 | Settings retains existing AppStorage keys and UI identifiers | Consistent; UI tests must navigate Settings first |
| 2 | HomeSummary excludes sample/future data; shortcut respects active recording | Explicit tests and idle guard required |
| 3 | FileDocument snapshot survives video source cleanup | Read immutable payload before export |
| 4 | Browser proof vs native app claims | Report separately |
| 1 -> 2 | Existing BrandTheme API | Unchanged; no shared-file edits |
| 1 -> 3 | Existing BrandTheme/ShareStyle | Unchanged; no shared-file edits |
| 2 -> 4 | Root has five tabs | QA checklist/test navigation updated |
| 3 -> 4 | PNG/MP4 save success/cancel/error | Native checks prepared, execution pending |

Ruling: no automatic commits despite skill examples; user forbids them. Progress is preserved in files and diffs.
Ruling: retain the already-approved private mury-ios destination; clarified by user, not inferred from the stale repository line.
Ruling: adopt the new master palette values and keep derived text/tint tokens; final brand fidelity remains subject to owner review.

## Task 1
Task 1: complete (no commits; snapshot diff task-1.diff; independent review spec compliant / quality approved).
- Asset/contrast/icon/protected hashes PASS; eight Swift syntax parses PASS. Native iOS build/XCTest/accessibility NOT RUN.
- Task 1 minor (deferred): profile-preservation unit assertions prove storage-key independence, not Settings UI behavior; dedicated native profile-preservation check belongs in iPhone acceptance.
- Ownership extension: larpingApp.swift fallback .tiffany only; review confirmed onboarding gate/model container unchanged.

## Task 2
- Implementer /root/home_record dispatched, owns only Home/Root/Record and task-specific tests.
- Request lifecycle added to task brief: consume ignored active/paused requests, repeated same-sport requests work; no Record identity reset.

- Task 2 source written and six Swift syntax parses PASS; asset/protected checks PASS. Snapshot task-2.diff packaged; /root/task2_review reviewing.
- Optional portable summary harness NOT RUN: automatic approval review rejected scratch-file write outside assigned ownership; skipped without workaround. Native XCTest NOT RUN.

Task 2: complete (no commits; snapshot task-2.diff; independent review spec compliant / quality approved; no findings).
- Review confirmed unchanged store/formatter/model contracts and consume-before-idle request ordering. Native lifecycle/target compilation remain NOT RUN; covered by durable device checklist.

## Task 3
- /root/files_export implementing ready PNG/MP4 Save to Files with immutable payloads, no new Photos access; owns only ShareActivityView, ShareExportDocument and focused tests.

## Consolidation notes
- Browser palette proof checked at 1440x1000 and 390x844: no horizontal overflow, no external requests or page errors; screenshot inspections recorded in browser-report.md. This is not native UI evidence.
- README/known issues now remove unconditional no-loss/no-network claims and destructive uninstall advice for the data-bearing upgrade case. Manual device QA is docs/mury-device-qa.md.
- Existing CI workflow has manual simulator build/test entry; no workflow dispatch or release action has been run. Publishing branch and running remote validation require explicit authorization.
- Final review should assess native screenshot coverage for the newly added Home tab; current loop captures Activities/Record/Stats plus Profile/Settings.

Task 3: complete (no commits; snapshot task-3.diff; independent review spec compliant / quality approved; no blocking findings).
- Immutable PNG/MP4 Files saving and five focused XCTest cases written. Swift syntax, asset/protected hashes and scoped whitespace PASS. XCTest/Files UI/real MP4 playback NOT RUN.

## Task 4 — current verification
- 2026-10-31: full Swift frontend parse PASS, 46 source/test/UI files; no iOS typecheck.
- node scripts/check-branding.mjs PASS, all four palettes/icon formats and 15 protected hashes.
- git diff --check with existing repository normalization PASS (exit 0); LF-to-CRLF advisories remain. A lead command overriding core.autocrlf=false first flagged CRLF line endings in RootView (exit 2); rerun under actual repo settings confirmed no whitespace defects. No source/config change was made to hide a failure.
- Active feature/mury-branding; HEAD and local main both base 7b7015b96e8c65e47cb334d3a2f7a94abba346fc. origin=mury-ios; source push DISABLED. xcodebuild not available.
- Combined independent review pending; native build/XCTest/iPhone acceptance remain outstanding.

## Combined final review
- Reviewer read all 4,313 package lines plus latest evidence/checklist and selected unchanged contracts. No Critical findings.
- Important: Home date snapshot stale across midnight/background resume. Minor: Home omitted from four-combination screenshot loop. One bounded fix wave /root/final_fixes dispatched; final-fix-before snapshot and findings/brief saved.
- Attempted tiny stdin compiler launches in reviewer environment failed ENOENT; no added compilation evidence.
- Review deferrals accepted: unchanged Stats sample/future behavior remains outside Home filtering scope; existing save recovery and HealthKit candidates remain protected and documented; exact artwork needs owner visual approval; native layout/accessibility/framework/recorder/Files correctness requires execution. Costs remain inconsistent sample treatment across Home/Stats, pre-existing recovery/import limitations, possible artwork rework and required macOS/iPhone validation.

## Final source gate — 2026-10-31
Task 4: source validation complete (no commits; whole-branch review plus one bounded correction wave and scoped re-review). Native acceptance remains NOT RUN.
- Final fix: foreground activation + NSCalendarDayChanged refresh Home Date; deterministic oldest-day expiry test; Home in four-combination screenshot loop. Scoped reviewer marked both findings ADDRESSED, no new breakage.
- Fresh post-fix lead run final-validation.log: all 46 Swift files syntax parse exit 0, branding/protected-file checker exit 0, normal git diff --check exit 0 (known line-ending advisories). HEAD/main remain baseline; feature branch retained.
- Automatic review initially rejected the fix test write due to obsolete Phase1-only context. Lead supplied exact later user standing implementation authorization and resolved scope evidence; same normal tool accepted retry. No bypass.
- Git private origin read probe with prompts disabled exit 0, no refs. Connector get_repo returned 404; push rights, Actions quota and new-repo signing readiness unverified. No publication, Actions dispatch or upload.
- Keep workspace/snapshots/reports: no commits exist to preserve their evidence. Remaining native checks are in docs/mury-device-qa.md; release readiness is not claimed.

## Publication authorization — 2026-10-31

Owner explicitly selected “Approve commit, push and CI” in Nimbalyst: a reviewed commit of these MURY changes, push only feature/mury-branding to ferbogar-uk/mury-ios, then the existing macOS simulator build/tests using available Actions quota. Stop if extra spending or credential/security changes are needed. No main changes, signing changes or TestFlight upload. This supersedes earlier default no-commit/no-push constraints for this specific publication; all other boundaries remain. Commit review/push/CI are pending at this checkpoint.
