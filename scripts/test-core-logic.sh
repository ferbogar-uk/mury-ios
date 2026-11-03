#!/usr/bin/env bash
# Runs the Foundation-only logic tests on Linux without touching the iOS app.
# It copies the pure source files and their tests into CoreLogic/, rewrites the
# test import from the app module to CoreLogic, then runs swift test.
# Files that do not exist on the current branch are skipped, so the same script
# works on main and on feature branches.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=CoreLogic/Sources/CoreLogic
TST=CoreLogic/Tests/CoreLogicTests
rm -f "$SRC"/*.swift "$TST"/*.swift
mkdir -p "$SRC" "$TST"

copied=0
for f in \
  larping/Core/Models/Activity.swift \
  larping/Core/Formatters.swift \
  larping/Core/VideoShareFile.swift \
  larping/Features/Activities/ReplayTimeline.swift; do
  if [ -f "$f" ]; then cp "$f" "$SRC/"; copied=$((copied + 1)); else echo "skip (not on this branch): $f"; fi
done

for t in ReplayTimelineTests FormattersTests EventNamerTests VideoShareFileTests; do
  if [ -f "larpingTests/$t.swift" ]; then
    sed 's/@testable import larping/@testable import CoreLogic/' "larpingTests/$t.swift" > "$TST/$t.swift"
  else
    echo "skip (not on this branch): larpingTests/$t.swift"
  fi
done

[ "$copied" -gt 0 ] || { echo "No source files found to test."; exit 1; }
cd CoreLogic
swift test