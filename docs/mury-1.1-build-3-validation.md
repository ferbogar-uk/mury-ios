# MURY 1.1 build 3 — validation and delivery

Date: 2026-11-02
Status: native build, automated tests, signed archive/export, Apple upload, processing and internal-beta availability VERIFIED. Real-device acceptance remains unchecked.

## Candidate and authorization

- Source: 48f42d1551367b5d2d0a8165d85b7a729b57a53b on feature/mury-branding.
- Version 1.1 (3), existing bundle rdyy.larping, App Store Connect entry LARPING (6828629415).
- Only app Debug/Release CURRENT_PROJECT_VERSION changed from 2 to 3 for this release candidate. Version 1.1, signing, workflows and app source were preserved.
- Owner explicitly approved this exact candidate's TestFlight upload and the same usesNonExemptEncryption=false answer if Apple asked. The earlier general approval was rejected by automatic approval review; no upload occurred until the exact-candidate confirmation arrived.
- Remote feature branch SHA was checked immediately before dispatch and matched the approved source.

## Included changes since build 2

- Transparent 1080x1920 sharing overlays: Statistics, Compact, Route + stats; logo-only output when no metrics are selected.
- Approved logo without a filled plaque; original red/white/light-blue identity colours.
- Available saved activity metrics only, including optional heart-rate values; route-less activities can open Share.
- PNG alpha retained through rendering, native sharing, copying and Files export contracts; receiving-app behaviour remains untested.
- Adaptive MURY logo in the Home navigation header.

## Actual evidence

| Check | Result | Evidence |
|---|---|---|
| Static branding/protected-content check | PASS | node scripts/check-branding.mjs, exit 0 after build-number change |
| Whitespace | PASS | git diff --check, exit 0 |
| Native simulator build and full tests | PASS | [CI 41370093177](https://github.com/ferbogar-uk/mury-ios/actions/runs/41370093177), exact source above, 15m16s |
| Unit tests | PASS | Complete downloaded test.log: 74 passed, zero failures |
| UI tests | PASS | Same log: 13 passed, zero failures; both Home tests checked home-brand-logo |
| Combined automated tests | PASS | 87 individual passed cases, no failed/skipped cases, TEST SUCCEEDED |
| Signed archive/export | PASS | [TestFlight run 41375815490](https://github.com/ferbogar-uk/mury-ios/actions/runs/41375815490): ARCHIVE SUCCEEDED, EXPORT SUCCEEDED |
| Apple upload | PASS | Same workflow, exact approved source, 4m49s; UPLOAD SUCCEEDED with no errors |
| Apple processing | PASS | Read-only Apple API HTTP200: build df867ce3-432b-4706-a610-475f9e63e002, version 3, pre-release version 1.1, processingState VALID |
| Export compliance / internal availability | PASS | Fresh Apple API HTTP200 after owner completion: usesNonExemptEncryption false; internalBuildState IN_BETA_TESTING; externalBuildState READY_FOR_BETA_SUBMISSION |
| Real iPhone rendering / receiving-app transparency | NOT RUN | Requires device acceptance |

Apple build: [1.1 (3)](https://appstoreconnect.apple.com/teams/0541a5bc-ac85-486e-a70f-97b94c432520/apps/6828629415/testflight/ios/df867ce3-432b-4706-a610-475f9e63e002).

## Compliance completion and remaining boundary

The API key can read build metadata but its compliance PATCH returned FORBIDDEN_ERROR. Automatic UI approval review refused to bind an Edge window titled with unrelated work. Opening a dedicated browser tab failed because the browser access host is unavailable. Owner then reported completion. A fresh Windows inventory identified App Store Connect; its build list showed build 3 in the existing Ricardo group. A fresh read-only Apple API check confirmed usesNonExemptEncryption=false, processingState=VALID and internalBuildState=IN_BETA_TESTING for the exact build ID. No additional compliance write was needed or performed after that confirmation. External state is READY_FOR_BETA_SUBMISSION; no external review was submitted.

No external beta review, App Store publication, tester/group membership change, build expiration, main merge, new credential, permission change, signing change, GPS/data/HealthKit change or schema migration was performed. Existing builds remain intact.

Evidence retained locally under .superpowers/sdd/mury-home-header: ci-41370093177/test.log and testflight-build-3.log. No credential values were stored in repository files or printed in logs.
