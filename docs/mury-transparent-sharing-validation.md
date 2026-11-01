# MURY transparent sharing — validation

Date: 2026-11-01
Source commit: 8b08004203de25e16ccdd5ccc5c3762af0f51a02
Branch: feature/mury-branding
CI: https://github.com/ferbogar-uk/mury-ios/actions/runs/41330019457

## Delivered behaviour

- New 1080 × 1920 transparent PNG overlays: Statistics, Compact, Route + stats.
- Supplied MURY blue/white logo retains original colours and has no filled plaque. Existing Classic export also loses its logo plaque.
- Available saved distance, time, pace/speed, elevation gain and optional average/max heart rate can be selected. Missing values and estimated calories are excluded.
- Empty metric selection exports only the logo. Activities without a GPS route can open Share.
- Preview-only checkerboard; PNG remains transparent. Copy PNG uses the PNG pasteboard type; native sharing explicitly exports PNG bytes.
- Existing Classic photo, Map, video and Save to Files paths retained.

## Verification

| Acceptance | Result | Evidence |
|---|---|---|
| Native iOS build | PASS | CI Build step success on exact source commit |
| Whole native test suite | PASS | Unfiltered test.log: 74 unit + 13 UI, zero failures, zero skipped tests; TEST SUCCEEDED |
| Classic logo plaque removed | PASS | testClassicLogoHasNoFilledPlaque |
| All three overlay PNGs preserve alpha and draw logo | PASS | testOverlayLayoutsPreserveAlphaThroughPNGExport |
| Empty selection produces logo-only; empty/nonempty routes | PASS | testOverlaySupportsNoRouteOrSelectedMetrics |
| Available metrics and pace/speed units | PASS | testOverlayMetricsUseOnlyAvailableSavedValuesAndCorrectUnits |
| PNG encoding and clipboard byte preservation | PASS | testPNGSharingAndClipboardPreserveAlphaAndBytes |
| Template selection, metric toggle, copy, Classic and Video controls | PASS | testTransparentTemplatesMetricSelectionAndPNGCopy, not skipped |
| Existing regressions | PASS | Entire existing unit/UI suite included |
| Static branding/protected content | PASS | node scripts/check-branding.mjs exit 0 |
| Local Swift syntax | PASS | 52 Swift files, frontend parse exit 0; distinguished from native build |
| Whitespace validation | PASS | git diff --check exit 0 |
| Independent source review | PASS after correction | Found unconditional title/date/route on empty selection; guard added and whole-content alpha regression passes |
| Real iPhone / Instagram paste / other receiving apps | NOT RUN | Receiving app may flatten or handle PNG differently |
| Visual inspection and largest accessibility text layout | NOT RUN | UI smoke tests passed; no exported CI screenshot artifact was inspected |
| New TestFlight distribution | NOT RUN | No upload authorized or triggered |

Native regressions passed on the candidate; a native failing-before-fix run was not performed on Windows. No red-to-green runtime claim.

## Boundaries and release status

Owner approved the recommended package, then explicit commit/push and simulator CI. No upload was included. The existing MURY 1.1 (2) TestFlight build remains the previously delivered version and does not contain these changes.

No changes to Bundle ID, build number, signing, secrets, workflows, activity schema, GPS algorithms, HealthKit or backup compatibility. Main remains ac9ab42af92ec41c764e16edb7c0d376fe5262b2.

No social backend, public activity links, direct Instagram posting, Photos permission or cinematic video exporter added. The current route-reveal video remains the existing flat-map implementation.

## Where to use after a future approved build

Activities → activity → actions menu → Share → Template.
Choose Statistics / Compact / Route + stats, select Metrics, then Copy PNG, Share or Save to Files. Remove all metrics for logo only. Classic retains Camera/Gallery; removing its photo restores transparency.
