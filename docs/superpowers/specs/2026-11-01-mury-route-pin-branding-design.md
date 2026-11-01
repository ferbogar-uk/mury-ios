> Superseded artwork: Ricardo rejected the reconstructed logo/fonts below. On 1 November he supplied MURY-Full-Brand-Pack.zip (Open Air v1.3). Use design/branding/brand-pack masters and docs/mury-brand-pack-intake.md. This document retains the migration/verification proposal only; its old logo, typography, tagline and colour-role suggestions are not final.

# Mury route-pin branding design

Status: visual draft for owner review, 1 November 2026. App implementation has not started.

## Decisions confirmed by Ricardo

Replace Pink and Tiffany Blue with one combined identity. Create a new editable vector draft from the supplied boards. These decisions authorize drafting; the actual artwork remains subject to review.

Identity: bold Mury wordmark, route-shaped M and location pin. Tagline: Track. Explore. Move Together. Palette: baby blue #A7D8F3, blood red #B20E1C, white #F9FAFB, charcoal #1F2937. The draft is reconstructed artwork, not the original master. SVG lettering currently uses live Arial/Helvetica text; final packaged artwork must have stable outlined lettering. App-icon SVG is a presentation treatment; production raster icon must be square without baked rounded corners.

## User journey and boundaries

New installations see a Mury welcome screen and Continue, without a redundant theme choice. Existing valid pink/tiffany preferences resolve to Mury and retain completed onboarding; activity stores and all recording preferences remain intact. Existing invalid or absent theme values retain the welcome path. Settings retains System/Light/Dark appearance and removes the obsolete colour picker. Appearance persistence remains independent from onboarding.

Home, recording, lists, details, statistics, profile and replay retain their existing behavior and use centralized Mury roles. Recording, permission denial, empty activities and import/export failures retain their current recovery flows. No new permissions, dependencies, accounts, social metrics or services are introduced.

Maps use red routes with a contrasting casing where supported. Image and existing flat-map video exports use the same identity and accurate recorded statistics. Existing share/save mechanisms remain. Social feeds, clubs, follows, cinematic street-level 3D and 3D video export pictured in the boards remain outside this branding change.

## Colour roles

Light: white canvas/surfaces, charcoal text, blue supporting surfaces, red action emphasis with white button labels. Dark: charcoal canvas, lighter dark cards, white text and blue readable interactive labels. Blood red remains the route and filled action colour; use contrasting outlines over variable maps. Calculated WCAG contrast: white/red 6.76:1; charcoal/blue 9.62:1; red/charcoal 2.08:1, unsuitable for ordinary text. Check disabled, selected and focus states as well as default states.

## Integration sequence and file ownership

One implementer owns shared theme and asset files; parallel work must use disjoint files if available.

1. Core/BrandTheme.swift and Assets.xcassets: keep the existing environment/share-style interface; replace theme variants with one identity and explicit legacy preference resolution. Add dynamic colour assets and approved stable logo/icon exports; retire only assets proven unused.
2. larpingApp.swift, Features/Root/ThemeSelectionView.swift, SplashView.swift and Features/Profile/SettingsView.swift: safe preference resolution, welcome/Continue, new branding and retained appearance picker. Do not change SwiftData models, bundle ID or signing.
3. Features/Home/HomeDashboardView.swift, Record/RecordView.swift, Activities/ActivitiesListView.swift, ActivityDetailView.swift, ActivityReplayView.swift, ImportGPXView.swift, ImportHealthKitView.swift, Stats/StatsView.swift and Profile/ProfileView.swift: audit existing semantic roles, replace residual legacy wording/colour, and check selected/dark states. Preserve location and HealthKit logic.
4. Core/ShareImageComposer.swift, ShareVideoComposer.swift and Features/Activities/ShareActivityView.swift: updated logo and colours in actual exports, retaining existing export error handling and statistics.
5. larpingTests/BrandThemeTests.swift, ShareImageComposerTests.swift and ShareVideoComposerTests.swift; larpingUITests/larpingUITests.swift, ScreenshotTests.swift and HomeDashboardTests.swift; scripts/check-branding.mjs: update meaningful expectations and protection checks. Adjust other tests only when their actual callers require it.

## Acceptance and verification

- Legacy pink/tiffany values resolve to the same Mury identity and skip previously completed onboarding: targeted unit tests and isolated UI launch cases without resetting owner data.
- Fresh installation shows welcome and Continue persists completion: isolated UI test.
- System/light/dark setting persists across relaunch: retain and update existing UI regression.
- Approved logo, palettes and routes appear throughout screens and exports: static checks, simulator screenshots and composer tests; owner visual review.
- GPS, background location, pause/resume, saving/loading and HealthKit remain operational: retain protected-file checks and existing unit/UI CI; real-iPhone regression still required for hardware behavior.
- Run node scripts/check-branding.mjs, git diff --check and signed-upload-free simulator CI after implementation. Native iOS functionality cannot be validated through this HTML preview or on Windows alone.

## Draft verification evidence

The preview loaded all three referenced SVG images in an actual browser without desktop horizontal overflow. A real button click changed aria-pressed to true and applied the dark-mode class. The primary logo and icon were visually inspected in a rendered screenshot. At a 390px browser viewport, all SVG images loaded, the grid used a single column and there was no horizontal overflow. These checks validate the draft preview only, not the app.

## Release and rollback

Develop only on feature/mury-branding. No activity schema migration, GPS algorithm changes, signing changes, workflow changes or bundle-ID change. Current TestFlight 1.1(1) retains the prior branding. Any new TestFlight upload requires separate explicit approval. Keep changes modular; rollback branding commits without deleting user preferences or stored activities. No commits or pushes made for this draft.
