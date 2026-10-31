# MURY 1.1 — native acceptance checklist

Status: NOT RUN. These checks require an authorized iOS build and a real iPhone. Never uninstall the data-bearing LARPING install for the upgrade test. A Windows Swift syntax pass or HTML palette proof does not satisfy these checks.

## Exact manual iPhone sequence (pending)

### Upgrade/data preservation

1. On the existing LARPING install, export a backup and keep it outside the app. Record activity count, selected old/imported IDs, names, dates, sport, distance, duration, track-point counts, profile fields, appearance and permission choices. Use an ordinary data-bearing install, not just seeds.
2. Install the MURY build over it with the same rdyy.larping identifier/signing; do not uninstall. If no valid theme key exists, select Tiffany explicitly; confirm old appearance/profile/history remain. Reopen the app and verify theme choice persists.
3. Export backup again. Compare stable IDs/fields/track points against the baseline, excluding exportedAt and any intentionally added recording. Confirm app discriminator remains Larping, count unchanged, and no new samples appeared. Confirm old seeded activities remain in Activities/backup but are absent from Home personal cards/totals. Import the original backup twice: existing IDs are skipped without duplicate points. Use a disposable backup/install for destructive cases.

### Active/background GPS + navigation

1. Enable location, choose Run, type a distinctive event title, start outside with a usable signal. Note timer/distance and route.
2. While recording, go Home -> Ride shortcut, then Profile -> Settings, change theme and Light/Dark, and return Record. Expect original Run/title, ongoing timer and accumulated route; no new tracker, cleared route or duplicate recording.
3. Walk with the app backgrounded and screen locked for 3-5 minutes; unlock and verify route continuity and active elapsed time. Pause, navigate Home -> Swim, change theme, return: Run/title remain and timer/distance stay paused. Resume, walk, Finish; one activity is saved with the same sport/title, continuous route and pause-excluded duration. Relaunch and inspect it.
4. On a separate permission case, deny location and confirm Start is unavailable and guidance is actionable; restore permission and retry. A force-quit recovery claim is out of scope: recording state currently lives in memory, so do not promise crash/force-quit recovery.

### HealthKit preservation

1. With workout/route write allowed, finish one new activity; verify exactly one matching Health workout and route, while the local record is already persisted. Deny Health writes and finish another: local save must still succeed.
2. Import a known Apple Watch workout with route, and separately one with no route. Compare date, sport, duration, distance and route against Health; Home counts the imported real activity. Do not re-import the same workout as an idempotency claim: current importer does not keep the Health UUID.
3. Where the fixture has heart-rate data, inspect imported HR. Existing code gates HR reads using authorizationStatus(for: heartRateType), and the route query processes done before the final locations batch. Treat missing HR/final route points as pre-existing reproduction candidates, not verified new regressions or reasons to expand branding scope.

### Save to Files, cancellation and failure

1. Open Share for a real activity. Classic without photo: Save PNG to On My iPhone; open the saved image, verify 1080x1920 and transparency in an alpha-aware viewer. Repeat Classic with photo and Map card; verify saved pixels correspond to the selected template and existing Share still opens.
2. Select Map before render completion; Save is disabled. Select Video before generation and while generating; Save is disabled. Generate, Save MP4, leave Share, and reopen the saved file from Files: it plays through after source temporary cleanup. Repeat export after a theme/appearance change and confirm the result matches the ready preview.
3. Start saving PNG, Cancel the native exporter: no success/error alert and no destination file. Repeat MP4 cancellation, then retry successfully without regenerating unnecessarily. Successful-save feedback must not remain visible from a previous attempt.
4. Exercise a reproducible writable-provider failure (e.g. authenticated test cloud provider with write access revoked after selection), then restore access and retry. Expect error feedback, no false success, activity unchanged, and successful retry. If no real provider failure can be induced, mark this case NOT RUN; cancel or airplane mode against local storage is not a write-failure test.
5. Generate video and dismiss Share during generation; reopen Share and retry. No stale finished URL/error should leak from the cancelled generation; existing cancel test only checks the composer, not view lifecycle. Native Share sheet must still work for ready PNG/MP4.


## Home date rollover (pending)

Use a controlled simulator/device fixture with a real activity on the oldest included day. Keep Home visible across local midnight: the expired day must drop from Last 7 days automatically, without a pull-to-refresh or tab change. Repeat by backgrounding while Home is shown before midnight and resuming after midnight; the same cutoff update must occur immediately on activation. Check a calendar/time-zone/DST transition in deterministic summary tests separately. Samples/history remain unchanged. This native notification/lifecycle case is NOT RUN.
