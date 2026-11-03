#!/usr/bin/env bash
# Runs the Foundation-only logic tests on Linux without touching the iOS app.
# It copies the pure source files and their tests into CoreLogic/, rewrites the
# test import from the app module to CoreLogic, then runs swift test.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=CoreLogic/Sources/CoreLogic
TST=CoreLogic/Tests/CoreLogicTests
rm -f "$SRC"/*.swift "$TST"/*.swift
mkdir -p "$SRC" "$TST"
cp larping/Core/Models/Activity.swift          "$SRC/"
cp larping/Core/Formatters.swift               "$SRC/"
cp larping/Core/VideoShareFile.swift           "$SRC/"
cp larping/Features/Activities/ReplayTimeline.swift "$SRC/"
for t in ReplayTimelineTests FormattersTests EventNamerTests VideoShareFileTests; do
  sed 's/@testable import larping/@testable import CoreLogic/' "larpingTests/$t.swift" > "$TST/$t.swift"
done
cd CoreLogic
swift test