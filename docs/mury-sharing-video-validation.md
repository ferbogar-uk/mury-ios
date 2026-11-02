# MURY sharing video — validation record

Status: implementation and scoped source reviews passed; final native validation is blocked because GitHub did not start the job. No new TestFlight upload authorized or performed. Last delivered build remains 1.1 (3).

## Scope

The owner approved export reliability, requested Classic composition, reference-derived transparent layouts, whole-route clips of 15/30/60 seconds (default 30, 30 fps, 1080×1920 H.264), feature-branch commits/push/CI and a genuine-3D technical study. The 60-second ceiling is a MURY product target, not a universal Instagram maximum. Reported devices: iPhone 14 Pro Max and iPhone 17 Pro Max; OS versions unspecified.

## Native evidence

- Baseline commit `6082987`, [CI 41420782558](https://github.com/ferbogar-uk/mury-ios/actions/runs/41420782558): app build passed; test compilation stopped on two missing try keywords in new image assertions. No export ran. Test-only fix `abcca3c` preserved assertions.
- Corrected baseline `abcca3c`, [CI 41422637418](https://github.com/ferbogar-uk/mury-ios/actions/runs/41422637418): 13 UI tests passed; 79 unit tests ran with 10 expected assertions in 4 newly added artwork tests. Complete real MP4 generation and decoding passed: 1080×1920 H.264,6 seconds,60 fps,360 frames. No simulator crash reproduced.
- Hardened writer/artwork commit `fcd92a4`, [CI 41428577033](https://github.com/ferbogar-uk/mury-ios/actions/runs/41428577033): 84 unit + 13 UI = 97 tests passed, 0 failures. All 18 image-compositor tests and the unchanged complete 6-second video regression passed. This candidate precedes the new duration/UI integration.
- Full-feature commit `9b834c4`, [CI 41434548911](https://github.com/ferbogar-uk/mury-ios/actions/runs/41434548911): app compilation stopped at the duration Picker because SwiftUI could not type-check the large expression in reasonable time. No new XCTest/export ran. A scoped repair separates typed duration/progress view expressions; native rerun pending.
- First compiler repair `945d460`, [CI 41436175067](https://github.com/ferbogar-uk/mury-ios/actions/runs/41436175067): compilation passed the duration control but stopped at the final video-alert expression in the same long SwiftUI modifier chain. No tests ran. A second scoped repair introduces computed view boundaries with identical containers, state and modifier order; native rerun pending.
- Second compiler repair `71ed618`, [CI 41437321194](https://github.com/ferbogar-uk/mury-ios/actions/runs/41437321194): GitHub rejected the job before any steps started (11:30:07–11:30:09 UTC). Check-run annotation: “The job was not started because recent account payments have failed or your spending limit needs to be increased. Please check the 'Billing & plans' section in your settings”. No compiler or test result exists for this candidate. The annotation gives alternative causes; account billing details and remaining allowance were not accessible or verified. No billing, runner or workflow settings were changed.
- Final 15/30/60-second export and new sharing UI: native validation blocked; do not infer a pass from earlier candidates.

Runs that reached tests retain complete test logs in their larping-test-logs artifact. Build-only failures retain failed-job logs; the pre-start billing rejection has no job log or test artifact. AppIntents metadata extraction warnings are not skipped XCTest cases. The successful comparison run logged an initial missing simulator store directory followed by successful recovery; no storage code was changed.

## Resource observation limits

Baseline encoding observation: 11.904 seconds, 565 main-actor heartbeat samples, largest observed gap 0.418 seconds, process-lifetime peak RSS before/after 423886848/825376768 bytes. Hardened candidate: 30.866 seconds, 1311 samples, largest gap 13.775 seconds, lifetime peak 473497600/638812160 bytes. The lower observed process peak does not establish isolated export allocation or device memory improvement; runtime and worst gap were worse in this run. No speed/responsiveness improvement is claimed. GitHub reported macOS runner capacity constraints. These observations have no arbitrary pass threshold and do not prove the reported iPhone crash cause.

Read-only Apple crash-feedback metadata returned HTTP 200 with zero submissions on the available checks. No device crash stack was available. Memory pressure/main-thread work remain hypotheses; passing simulator exports cannot establish the closure is fixed on either physical iPhone.

## Source and host checks

Branding/protected-file checker and whitespace checks passed on reviewed changes. Windows Swift frontend parsing confirms syntax only, not Apple SDK types. Task 3's compiled host harness exercised the actual reveal method with fixture edge lengths; it did not exercise CoreLocation initialization or Apple rendering. Task 4 compiled the actual Foundation file-copy owner and verified copied bytes survive source deletion and are removed on owner release; UIKit consumer timing remains a native/device gate.

Source review passed the writer hardening, requested artwork after a bounded Chips-title correction, and segmented route/duration API. Sharing-control source review also passed. Final broad review found the inherited Classic title omission; a bounded caption/date adjustment and focused image regression passed scoped source/spec and quality rereview. Real error Retry injection, background/dismiss races and physical-device sharing are not established by host checks.

## 3D decision

No 3D export selector or renderer was added. Existing route video animates over a static scene. The [feasibility handoff](mury-3d-video-export-feasibility.md) defines a physical-iPhone geometry experiment and separate provider permission/attribution gates. A tilted still is not accepted as moving 3D.

## Coordination decisions

- Reused the approved feature/mury-branding checkout instead of creating another worktree. Preflight found no unrelated tracked changes; if this assumption were wrong, unrelated work would need separation.
- Continued the approved plan without another execution-method approval. Scope stayed reversible and excluded release actions; a mistaken interpretation would cost implementation rework.
- Kept Git/CI with the parent and serialized implementation ownership, preserving baseline logs before repair. This costs additional baseline CI time, without changing user data.

- Enforced the approved Classic selected-title requirement despite its inherited omission. The bounded caption is reversible if unwanted; stored activity data is unchanged.

## Remaining acceptance

The owner must review the actual GitHub account notice in [Billing & plans](https://github.com/settings/billing); this is a GitHub Actions account restriction, not a TestFlight fee. Once the restriction is resolved, rerun the existing simulator workflow on exact source candidate `71ed618` (or a source-identical documentation successor), then inspect the full native results. Do not change signing/workflows or weaken tests to bypass this gate. Then recheck Generate video and sharing on both reported iPhones, including 15/30/60, cancellation, backgrounding and file cleanup. Native error Retry and real-device responsiveness remain explicit gaps until exercised. Keep workflows, signing, secrets, bundle ID, recording, storage, HealthKit and backup compatibility unchanged. A new TestFlight upload requires approval of the final candidate.
