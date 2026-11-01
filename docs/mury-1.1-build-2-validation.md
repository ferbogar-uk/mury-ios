# MURY 1.1 build 2 — validation record

Status: implemented and independently source-reviewed; awaiting exact-commit macOS CI.

## Implemented

Supplied Open Air identity, owner-approved red/white/light-blue logo palette, Rubik resources and scalable designed text, single-identity welcome with legacy pink/tiffany compatibility, independent System/Light/Dark appearance, fixed red routes with white casing, existing image/flat-map video branding and correct pace/speed labels/units. App target version remains1.1; build incremented to2.

## Evidence before CI

- Parent node scripts/check-branding.mjs: PASS, exit0, repeated after final implementation. Checks exact supplied tokens, contrast, deployed logo source bytes/palette, font names/resources, icon formats, preference gate, export labels and protected content.
- Parent Swift frontend parse:22 changed/new Swift files, zero failures. After replay-test setup/persistence edits, both edited UI test files parsed again without errors. Syntax only on Windows. Worker reports parsing all51 Swift files; native typechecking remains CI gate.
- Parent git diff --check with normal repository line-ending settings: PASS. An alternate core.autocrlf=false run flagged CRLF as whitespace; no content defect, normal repository check passes.
- Parent separately checked18 supplied icon dimensions/RGB and actual Rubik PostScript names. Imported source pack104 inventory-listed files matched SHA256, zero mismatches.
- Independent source review of maps and combined implementation: spec PASS, quality APPROVE; scoped final review of replay setup and onboarding relaunch tests also approved. No native test execution implied.

## Protection

Branch feature/mury-branding only; main, signing, secrets, workflow definitions, rdyy.larping, GPS algorithms, activity models/storage, HealthKit and backup discriminator preserved. Info.plist changes only add exact static Rubik UIAppFonts. Existing protected-content hashes remain unchanged; static checker permits line-ending equivalence and strips only that authorized font block.

## Pending

Run existing simulator CI on exact pushed commit, inspect build/unit/UI results, fix demonstrated failures. New TestFlight upload requires separate explicit per-upload approval. Real-iPhone GPS/background/HealthKit, outdoor readability, VoiceOver, large-text layout, real installed-data upgrade and MP4 playback remain device checks. Cinematic 3D video is not included.

## Native CI candidate and typography completion

First implementation commit fa608dd2e4b978a15c2beff8e7f2ed3f6b39615f was pushed to feature/mury-branding. CI run41320834629 passed its native Xcode Build and simulator preparation steps; tests were in progress when recorded. A final integration check found designed type on activity details/replay still used system fonts. The bounded follow-up applies scalable Rubik and navigation tokens in those two views, preserving SF symbols, controls, monospaced digits and behavior. Parent reran static branding, two-file Swift parse and diff checks: pass. Final-candidate CI must run on the follow-up commit; the first build is not final acceptance. Main remains ac9ab42af92ec41c764e16edb7c0d376fe5262b2.
