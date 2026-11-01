# MURY brand-pack intake

Received 1 November 2026. Source: MURY-Full-Brand-Pack.zip, Open Air v1.3, supplied by Ricardo from Downloads.

Archive SHA-256: 52A626EEA1CB0DB3277B59734E49F6FDF012D27057D12AAB67EDB86B966EEF00.

## Imported source

The archive contains 437 entries, approximately 171.9 MiB expanded. Imported 105 app-relevant files (19.9 MiB) unchanged into design/branding/brand-pack: outlined SVG/PNG logo variants, iOS icon catalogue and RGB marketing master, palette/tokens/native colour examples, Rubik fonts and OFL, selected PNG screen references, implementation guidance, provenance, Lucide notice, guidelines and inventory. Other marketing, web/Android/desktop, stationery and large SVG concepts remain in the original archive. This is a selected app-source import, not a claim that the entire archive was copied or validated.

## Source of truth

Owner correction, 1 November 2026: the logo symbol and Mury wordmark may use only red #B20E1C, white #FFFFFF or light blue #A7D8F3. Navy/charcoal is permitted elsewhere in the app, never in the logo or Mury lettering. This instruction overrides the supplied primary preview and guideline where they show charcoal lettering. Use 01-Logos/mury-horizontal-red.svg on light/blue backgrounds; mury-horizontal-dark.svg on dark backgrounds (light-blue symbol, white lettering), or the supplied white variant where suitable. Do not use the charcoal or black wordmark treatments. Preserve geometry, proportions and clear space. Use standalone symbols when space cannot accommodate the horizontal minimum. New tagline: Move. Explore. Achieve.

Colours: blue #A7D8F3; red #B20E1C; soft-white canvas #F9FAFB; white panel #FFFFFF; charcoal #1F2937. Dark action and selected navigation are baby blue, with charcoal action text. Route colour remains red in both appearances with white casing. Do not substitute action colour for route colour in dark mode.

Typography: supplied Rubik Regular 400, SemiBold 600 and Bold 700, with SIL OFL. Guideline permits system typography for native controls; JSON nativeIos also says system font. Use the supplied outlined wordmark directly and Rubik for designed app content, retaining native control typography and scalable text roles. No global system-font replacement or machine font installation is needed.

iOS: use supplied AppIcon.appiconset and square RGB App Store master after validating metadata, dimensions/opacity and actual Xcode build. The pack's verification report is upstream evidence, not our runtime validation.

## Integration sequence

1. Map the supplied dynamic tokens to the existing centralized BrandTheme interface, separating red routes from light/dark action tint. Import selected red/dark/white logo assets, static Rubik fonts with OFL, and iOS icon resources.
2. Replace the theme chooser with a single-identity welcome. Accept legacy pink/tiffany onboarding markers without touching activity data or appearance preference. Keep System/Light/Dark settings.
3. Update existing screen logo rendering to retain supplied colours; apply typography, navigation, controls and map casing. Do not redraw the mark or invent social metrics.
4. Apply the identity to existing image and flat-map route-video exports, preserving real statistics, error handling and save/share flows. Correct pace/speed labels if confirmed by targeted source review.
5. Update meaningful theme/onboarding/export tests and static branding checks, review combined diff, then run simulator CI. Real-device GPS/background/HealthKit, upgrade and accessibility checks remain separate requirements.

Parent assigns exact edit ownership before parallel implementation. Shared theme, app entry and project files are serialized. Brand foundation and independent-review sessions are performing bounded pack-specific read-only reviews now.

## Verification performed during intake

- Archive opened successfully and entry metadata inventoried.
- Selected extraction checked resolved target paths stay under workspace; existing files were not overwritten.
- SHA-256 compared 104 imported files against supplied INVENTORY.csv: zero mismatches. INVENTORY.csv itself is not self-listed. This verifies imported bytes, not design correctness or native acceptance.
- Supplied preview PNG visually inspected; primary SVG inspected and uses outlined paths.
- README, TYPOGRAPHY, tokens, IMPLEMENTATION-SPEC, PROVENANCE and VERIFICATION read.
- docread outlined the 18-page guideline and read the logo/clear-space/contrast/typography/components section (lines 25–100).
- Prior rejected draft specification marked superseded; team handoff updated.

## Limits and release protection

No application code, signing, secrets, workflows or installed data changed during intake. No commit, push, new CI run or TestFlight upload performed. Concept city/screens/sample metrics are not functioning app evidence or release screenshots. Cinematic street-level flyover and 3D export remain proposal-only. Keep backup discriminator Larping for compatibility. New uploads require explicit per-upload approval.
