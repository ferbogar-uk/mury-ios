# MURY 1.1 build 2 — validation and delivery

Status: native build, automated tests, signed IPA upload and Apple internal-beta state VERIFIED. Real-device acceptance remains pending.

## Delivered candidate

- App: MURY 1.1 (2), existing bundle rdyy.larping and existing App Store Connect entry LARPING.
- Source commit: 918279435fddfe1eefb82ad9917f69a99414fe79 on feature/mury-branding.
- Native CI: https://github.com/ferbogar-uk/mury-ios/actions/runs/41323360486 — SUCCESS.
- Signed archive/export/upload: https://github.com/ferbogar-uk/mury-ios/actions/runs/41325110241 — SUCCESS, same source commit.
- Apple build ID: 1f60cf1d-825f-4b50-916f-9db6cd79f3c9.
- Apple build page: https://appstoreconnect.apple.com/teams/0541a5bc-ac85-486e-a70f-97b94c432520/apps/6828629415/testflight/ios/1f60cf1d-825f-4b50-916f-9db6cd79f3c9.
- Read-only Apple API HTTP200 after compliance save: processingState VALID, usesNonExemptEncryption false, internalBuildState IN_BETA_TESTING, externalBuildState READY_FOR_BETA_SUBMISSION. External review and App Store publication were not submitted; no tester/group membership was changed.

## Resulting behavior

Supplied Open Air logo, Rubik and icon assets are integrated. Owner override uses only red/white/light-blue in logo/Mury lettering; navy remains available elsewhere in the interface. The single adaptive identity replaces Pink/Tiffany selection while accepting legacy onboarding markers. System/Light/Dark preference remains independent. Designed content uses scalable Rubik with native control typography retained. Routes remain red with white casing in both appearances. Existing image and flat-map route-video exports use approved branding and accurate pace/speed labels/units.

GPS/data algorithms, SwiftData models/storage, HealthKit, permissions and backup discriminator Larping are unchanged. Cinematic street-level 3D video is outside this branding build.

## Acceptance evidence

| Check | Result | Evidence |
|---|---|---|
| Native Xcode compilation | PASS | CI41323360486 Build step succeeded. |
| Unit suite | PASS | Downloaded test.log:69tests,0failures. Includes actual font loading/scaling, legacy preference resolution/no-write checks, exact palette, image route/casing/alpha and export logic. |
| UI suite | PASS | Same log:12tests,0failures. Home, replay, single welcome/Continue, fresh/unknown-marker relaunch persistence, legacy bypass, appearance persistence, Light/Dark screenshot journeys and launch checks passed. |
| Combined automated total | PASS | 81tests,0failures,0skips; TEST SUCCEEDED. |
| Static branding/protection | PASS | Parent ran node scripts/check-branding.mjs repeatedly after final edits: exit0. Exact supplied tokens/contrast, logo provenance/palette, fonts, icon metadata, preference/export contracts and protected original content pass. |
| Swift parsing | PASS | Windows frontend parsing of changed files, including DEBUG/Release repair paths. Syntax only; native compilation is evidenced separately above. |
| Whitespace | PASS | Parent git diff --check with repository settings: exit0. |
| Signed archive/export | PASS | Actual workflow log: ARCHIVE SUCCEEDED and EXPORT SUCCEEDED. |
| Apple upload | PASS | Actual log: UPLOAD SUCCEEDED with no errors. IPA artifact retained7days by unchanged workflow. |
| Apple processing/compliance | PASS | HTTP200 build API plus UI declaration saved under explicit owner approval; states above. |
| Actual iPhone behavior | NOT RUN | GPS/background/HealthKit, outdoor readability, VoiceOver, large-text fit, installed-data upgrade and MP4 playback still require device acceptance. |

## Authorization and protection

Ricardo explicitly chose Upload to TestFlight for version1.1(2) and exact source9182794, including the same usesNonExemptEncryption=false declaration as the previous build if Apple asked. Branch SHA was checked before dispatch. Existing signing secrets/certificates/profiles and workflow definitions were used without alteration. No new API key or broader access was created. No credential values were written into repository files or logs.

Remote main remained ac9ab42af92ec41c764e16edb7c0d376fe5262b2 when checked. Original LARPING1.0(1) and earlier MURY1.1(1) were not expired or changed. The only Info.plist addition is exact Rubik UIAppFonts; protected manifest hashes remain unchanged, and static checking permits equivalent line endings while excluding only that authorized font block.

## Implementation and repair history

- fa608dd: supplied branding, source assets, safe preference resolution, screens/exports/tests. CI41320834629 compiled and prepared simulator; cancelled as superseded while tests ran. No test pass claimed from that run.
- b2c16ab: completed designed typography/navigation styling in the two maps-owned views. CI41321722698 compiled,69unitspassed;9of12UIpassed. ThreeUI failures: obsolete screenshot theme picker and two onboarding tests whose launch arguments shadowed preference writes.
- 9182794: DEBUG-only one-time theme seed for UI testing, seed removal before persistence relaunch, single-identity Light/Dark screenshot loop. Actual Foundation reproduction supported the diagnosis; no assertions were dropped. Scoped independent source review approved. Full native CI then passed81tests.

Independent source reviews covered map presentation, combined implementation and both scoped follow-ups; parent separately inspected actual diffs and reran local checks. Those reviews are distinct from the native test evidence.

## Decisions made during execution

- Reused the dedicated feature branch/shared workspace as requested; precise disjoint file ownership limited conflict risk.
- Read-only advisory sessions retained their scope; a full-capability app implementation worker handled writes.
- Map and main branding changes used disjoint files concurrently under explicit owner parallel-work instructions; shared theme/project changes stayed serialized.
- Incremented app build number to2 in Debug/Release because the unchanged upload workflow has no build-number input; kept version1.1.
- Added only a DEBUG UI-test preference seed to avoid launch-domain overrides; Release excludes that hook.

These decisions can be revised locally if owner device review identifies a gap; no history rewrite or main merge was performed.
