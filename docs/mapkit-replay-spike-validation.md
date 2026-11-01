# MapKit replay prototype — build, CI and TestFlight status

Updated: 1 November 2026. This is a development prototype; it has not been uploaded to TestFlight.

## Repository and authorization
- Owner approved “Full MURY main”: remote mury-ios/main was created at ac9ab42 and made the default branch. No merge commit, force push or history rewrite was needed.
- Both existing GitHub workflows now register as active. No workflow file was changed.
- Subsequent CI fixes were committed/pushed on feature/mury-branding. They have not been merged into main.
- Original ferbogar-uk/larping repository, Bundle ID rdyy.larping, GPS tracking algorithms, persistence schema, signing settings and original repository secrets were not modified. RecordView now adds keyboard focus dismissal only.
- Latest owner instruction requires simulator CI before the TestFlight workflow and explicit approval before every upload.

The default branch was previously feature/mury-branding, which already contained both YAML files. GitHub generally requires the default branch, not specifically the name main. Registration became functional after the approved main/default change; the exact underlying registration defect was not independently established.

## Actual native CI evidence
| Run | Revision | Result |
|---|---|---|
| [41297286277](https://github.com/ferbogar-uk/mury-ios/actions/runs/41297286277) | ac9ab42, main | App BUILD SUCCEEDED. Test compilation failed: missing SwiftUI import for ColorScheme.light in ShareVideoComposerTests. |
| [41297652546](https://github.com/ferbogar-uk/mury-ios/actions/runs/41297652546) | e883734, feature | App/tests compiled; all 65 unit tests and Replay UI test passed. Three other UI tests failed; one first-launch test skipped. |
| [41299169898](https://github.com/ferbogar-uk/mury-ios/actions/runs/41299169898) | 584799c, feature | Build succeeded; all 65 unit tests and Replay UI test passed. UI suite: 11 tests, 3 failures and 1 skip. Overall TEST FAILED. |
| [41306446344](https://github.com/ferbogar-uk/mury-ios/actions/runs/41306446344) | 8e3c2f6, feature | BUILD SUCCEEDED and TEST SUCCEEDED. 65 unit tests passed; UI suite: 10 passed, 1 skipped, zero failures. All three previously failing UI journeys passed. |

Earlier repair cycles (historical):
1. Added the defining SwiftUI import to the existing video cancellation test (e883734). Native CI confirmed that test passed.
2. Handled the simulator location prompt before the Home title edit; attempted to move appearance accessibility metadata onto the Button (584799c). Title editing progressed, but keyboard obstructed tab navigation. Appearance identifiers remained unavailable. The unsuccessful product accessibility change was then rolled back to its previous implementation; no third repair run was started.

Failures in the earlier runs, now resolved:
- HomeDashboardTests.testRideShortcutRepeatsAndPreservesEditedIdleTitle: Home tab hit point was {-1,-1} with keyboard visible; app remained on Record, so home-record-ride was absent.
- ScreenshotTests.testCaptureScreens: expected appearance-light Button identifier unavailable.
- larpingUITests.testThemeAndAppearanceAreIndependentAndPersist: expected appearance-dark Button identifier unavailable.
- In the first UI run, appearance identifiers were doubled by the accessibility hierarchy; after the attempted metadata change, buttons appeared only by visible labels. The attempted fix did not solve the failure.
- The clean-first-launch test skipped because an earlier test had already completed onboarding; no owner data was deleted/reset.

The last log contains CoreData directory/recovery diagnostics followed by successful recovery and 65 passing unit tests. No data loss was demonstrated. Do not diagnose a production persistence failure from those diagnostics alone.

Saved full test logs are in the ignored local coordination workspace under .superpowers/sdd/mapkit-replay-spike/ci-<run>/test.log.

## Other checks
PASS: actual production Swift timeline/playback compiled, linked and executed on Windows.
PASS: 50 app/unit/UI Swift files passed syntax parsing before native CI; changed files were subsequently parsed.
PASS: branding contrast/assets and protected SHA-256 checker; git diff --check.
NOT RUN: final independent AI code review (child account usage limit), physical iPhone GPS/background/HealthKit regression, installation upgrade, signed archive/export, city coverage/low-camera visual QA and TestFlight upload.
The full simulator CI suite is now green at 8e3c2f6 (75 passed, 1 skipped). This establishes simulator behavior, not physical-device or release readiness.

## Verified UI repair — 1 November 2026
Owner requested another scoped repair. Settings now uses a native segmented appearance Picker, following the existing theme Picker pattern and preserving the same AppStorage key and all three options. RecordView gives event-name editing an explicit Done submission that clears focus. UI tests retain title preservation, independent theme/appearance selection and persistence assertions, and wait for keyboard dismissal before Home navigation.

CI 41306446344 confirms HomeDashboardTests.testRideShortcutRepeatsAndPreservesEditedIdleTitle, ScreenshotTests.testCaptureScreens and larpingUITests.testThemeAndAppearanceAreIndependentAndPersist all passed. Replay UI and all 65 unit tests also passed. The first-launch test skipped because earlier tests completed onboarding; no owner data was deleted to force a clean install. Five changed Swift files passed local syntax parsing; check-branding and git diff --check passed.

## Signing comparison and recommendation
Current MURY/larping signing installs an existing .p12 and provisioning profile, archives with manual signing, exports an IPA, then optionally uploads via altool. Team ID/profile name/Bundle ID stay as in the existing workflow. This is the smallest immediate path if the owner has the valid existing signing files, including a profile compatible with HealthKit.

FORMETRA's [successful run 41224616219](https://github.com/ferbogar-uk/formetra/actions/runs/41224616219) uses ASC_KEY_P8, ASC_KEY_ID, ASC_ISSUER_ID and APPLE_TEAM_ID. Its workflow archives without signing and authorizes automatic provisioning/cloud signing at export using -allowProvisioningUpdates and -authenticationKeyPath/ID/IssuerID, then uploads with altool.

Recommendation: keep the current manual path for this build to avoid combining CI repair with a signing migration. FORMETRA's approach reduces credential maintenance, but adapting it requires workflow/signing approval, matching team/app access and HealthKit capability validation. Its success for FORMETRA does not prove eligibility for rdyy.larping. Neither path requires changing the Bundle ID or creating a replacement App Store Connect app.

Apple describes API-key export/cloud signing in [Distribute apps in Xcode with cloud signing](https://developer.apple.com/videos/play/wwdc2021/10204/).

## Required secure setup — no values in chat
All six MURY repository secrets were created and their names verified on 1 November 2026. See [credential setup evidence](mury-secrets-setup.md). Existing larping secrets were not read or modified.

They are stored in [MURY Actions secrets settings](https://github.com/ferbogar-uk/mury-ios/settings/secrets/actions):
| Exact name | Current workflow expects |
|---|---|
| APP_STORE_CONNECT_API_KEY | Raw .p8 PEM text, including its header/footer |
| APP_STORE_CONNECT_ISSUER_ID | Apple issuer ID |
| APP_STORE_CONNECT_KEY_ID | Apple key ID |
| IOS_DISTRIBUTION_P12 | Base64 of the existing distribution .p12 including private key |
| IOS_DISTRIBUTION_PASSWORD | Password protecting that .p12 |
| IOS_PROVISIONING_PROFILE | Base64 of the existing App Store provisioning profile |

Owner explicitly approved a separate MURY-GitHub-CI Apple Developer API key, including Apple team-wide app scope. Its one-time download was saved outside the repository and transferred directly into GitHub secrets; no private values were printed or committed. A read-only Apple API request returned HTTP 200 for rdyy.larping. Existing local certificate and password were reused: password accepted, private key present, certificate/profile match confirmed, expiry 30 October 2027. Selected profile includes HealthKit. No certificate/profile was issued or revoked, and no workflow/signing configuration was changed. Simulator CI uses none of these secrets.

## Costs and boundaries
No TestFlight credit purchase is needed; the ChatGPT child-agent usage limit is unrelated. GitHub Actions uses the account's included allowance, and macOS consumes it faster than baseline Linux. Current [GitHub billing documentation](https://docs.github.com/en/billing/concepts/product-billing/github-actions) describes included compute accounting; do not infer the account's remaining balance from a fixed multiplier. The current token cannot read the billing balance with its existing scope; the owner can check Settings → Billing and plans.

## Next actions
Simulator CI and credential setup are verified. A read-only Apple build listing on 1 November 2026 returned only version 1.0, build 1, processing state VALID. The project currently specifies MURY version 1.1, build 1, Bundle ID rdyy.larping. The next action is explicit owner approval for the existing signed build/upload workflow on feature/mury-branding. No TestFlight upload is authorized by a CI result alone.

Physical-device checks still need a disposable/test activity set: playback controls, gaps, coverage in London and a reference city, VoiceOver/Dynamic Type/Reduce Motion, real recording/pause/background, HealthKit and existing-data preservation. Native UI test success does not establish urban visual quality or map-video distribution rights.
