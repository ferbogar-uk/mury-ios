# MURY supplied-brand integration implementation plan

> **For agentic workers:** Use subagent-driven-development or executing-plans; parent coordinates exact file ownership. Owner explicitly requested implementation now, 1 November 2026.

**Goal:** Build the existing app with supplied Open Air branding and owner-corrected logo colours.

**Architecture:** Reuse BrandTheme environment, SwiftData and current export composers. One Mury identity resolves legacy onboarding markers. Dynamic action colours are separate from fixed red route and white casing.

**Tech Stack:** SwiftUI, UIKit, MapKit, SwiftData, existing Xcode targets; no new dependencies.

**Spec:** docs/mury-brand-pack-intake.md plus supplied pack guidance. Owner override: logo and Mury lettering only red #B20E1C, white #FFFFFF or light blue #A7D8F3. Navy elsewhere in UI allowed.

## Global constraints

Use feature/mury-branding only; preserve main, rdyy.larping, signing, secrets, workflows, activity models/storage, backup discriminator Larping, GPS algorithms, HealthKit and permissions. Do not use rejected route-pin-draft artwork or sample activity data. No cinematic engine or 3D export addition. No upload until per-upload approval. Parent alone handles authorized Git operations and CI. Keep existing version 1.1; next distribution build number must be distinct from uploaded 1.

## Review focus

Legacy pink/tiffany onboarding completion and appearance persist; fresh/unknown markers show a usable welcome. Red route remains red in dark appearance while controls become blue. Logo never contains charcoal lettering or template tint that introduces navy. Font resources register and scale in native app. Image/video exports retain real metrics, pace/speed units, cleanup and failure recovery.

### Task 1: Foundation, interface and exports

Owner: full-capability App implementation child, exclusive edit ownership of larping except ActivityReplayView.swift and ActivityDetailView.swift (reserved maps child), Core/Location, Core/Health, Core/Models, ActivitiesStore, BackupService, GPXParser and ReplayTimeline (protected). Also owns related larpingTests and larpingUITests updates except ReplayTests. Own scripts/check-branding.mjs. Project config may change only resource registration/version as necessary, never signing/identifiers/deployment/workflows.

- [ ] Read relevant source and all theme/logo callers. Add meaningful preference resolution tests for missing, invalid, pink, tiffany and mury values before implementation.
- [ ] BrandTheme: one mury case; preserve storageKey; explicit onboarding marker acceptance. Preserve eight existing role properties, add navigation, route and routeCasing. shareStyle route uses route asset rather than action accent. Dynamic assets use pack exact values.
- [ ] Import red/white/blue-white logo variants and iOS square icon. Keep source geometry; no charcoal wordmark. Include static Rubik 400/600/700 and OFL, register via UIAppFonts, use scalable typography for designed content while preserving native controls. No global font installation/dependency.
- [ ] App/welcome/settings/splash: single welcome Continue persists mury, legacy markers skip onboarding, retain appearance picker and activity container. Tagline Move. Explore. Achieve.
- [ ] Existing dashboard/record/history/stats/profile/settings/share UI: selected colours, navigation backgrounds, original multicolour assets, Rubik where appropriate, accessible labels; no behavior refactors. Recording route styling red/white without changing data handling.
- [ ] Existing image and flat-map video composers: approved logo, selected appearance tokens, accurate metrics and correct pace versus speed labels. Preserve native share/Files and error handling.
- [ ] Update affected unit/UI tests and static checks for new identity, logo palette, font/icon metadata, route/action separation, legacy compatibility, and preserve protected-file hashes. Do not weaken checks.
- [ ] Report actual local commands/results; Windows parse is syntax only. No commits/pushes/CI/upload.

### Task 2: Map presentation

Owner: existing Maps and 3D replay child, exclusive ActivityDetailView.swift and ActivityReplayView.swift only. Consumes theme.route, theme.routeCasing and existing theme roles from Task 1; no edits to BrandTheme or timeline.

- [ ] Inspect polylines/markers and logo use. Apply fixed red with white casing in current maps and marker borders; preserve timeline gaps, camera, controls, metrics and navigation.
- [ ] Remove residual forced logo tint only if present in these files. Fonts may consume Task 1 typography only once its interface is confirmed; system metrics acceptable until parent integration.
- [ ] Verify syntax and inspect diff; do not claim native renderer test on Windows. No additional 3D capability or provider.

### Task 3: Combined review, checks and build

Owner: parent; independent review session reviews actual combined diff. GPS/data specialist verifies protected logic unchanged if needed.

- [ ] Review all modifications for scope, data safety, owner logo palette, resource registration, unit/UI compatibility and exact export stats. Fix demonstrated issues, at most two repair cycles.
- [ ] Run node scripts/check-branding.mjs, Swift frontend parse of changed sources, git diff --check; inspect iOS asset metadata and supplied logo resources.
- [ ] Use Nimbalyst commit proposal for authorized feature-branch commit and push (owner previously explicitly requested commit/push for this build). Never merge/main. Run existing simulator CI for exact pushed commit; inspect failures and fix, rerun only affected checks.
- [ ] After simulator success present concrete build and obtain separate explicit TestFlight upload approval. Native GPS/background/HealthKit and outdoor visual/device checks remain manual limitations.

## Preflight interface review

| Tasks | Shared interface | Resolution |
|---|---|---|
|1/2|theme.route and theme.routeCasing|Names fixed here; task 2 edits disjoint view files only.|
|1/3|new tests/static checks and protected hashes|Parent reruns actual commands; old palette tests are replaced with single-identity assertions, protected hashes preserved.|
|2/3|Map renderer behavior|Source/syntax review locally; simulator CI plus later iPhone required for visual fidelity.|
|1 self|Migration tests vs startup gate|Use one explicit acceptance helper for pink/tiffany/mury; invalid values do not erase activity storage.|
|2 self|Presentation vs timeline|Only route colour/layer and font presentation edits; no camera/timeline changes.|
|3 self|Build versus release|CI may run after authorized commit/push; upload always separate approval.|

Ruling: reuse current dedicated development branch/workspace rather than new worktree, as user restricts development to feature/mury-branding and all child sessions share this checkout. Cost if wrong: reduced isolation; disjoint ownership and parent diff review mitigate it.
Ruling: existing read-only foundation/screen/test sessions remain advisory; a full-capability implementation worker is needed for actual writes, not claimed upgrades of their permissions.
