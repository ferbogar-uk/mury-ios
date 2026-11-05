import SwiftUI

/// Shows the heart rate the watch measures while a recording is under way. It shows
/// nothing at all when no watch is sending one, so it takes no space without a watch.
/// A reading that has gone stale shows a dash, never the old number.
struct HeartRateRow: View {
    private let mirror = WatchMirror.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let reading = mirror.heartRate {
                let display = HeartRateDisplay(reading, now: context.date)
                Label(display.isLive ? "\(display.text) bpm" : display.text, systemImage: "heart.fill")
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(display.isLive ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                    .accessibilityIdentifier("record-heart-rate")
            }
        }
    }
}