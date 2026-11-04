import SwiftUI

struct WatchHomeView: View {
    private let receiver = MirrorReceiver.shared

    var body: some View {
        let snapshot = receiver.snapshot
        if snapshot.state == .idle {
            idleView
        } else {
            recordingView(MirrorDisplay(snapshot), sport: snapshot.sportLabel)
        }
    }

    private var idleView: some View {
        VStack(spacing: 6) {
            Image(systemName: "figure.run")
                .font(.title2)
            Text("MURY")
                .font(.headline)
            Text(receiver.hasReceivedAnything ? "Start a recording on your iPhone" : "Waiting for your iPhone")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func recordingView(_ display: MirrorDisplay, sport: String) -> some View {
        VStack(spacing: 4) {
            Text(display.isPaused ? "\(sport) \u{00B7} Paused" : sport)
                .font(.caption)
                .foregroundStyle(display.isPaused ? .orange : .secondary)
            Text(display.time)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(display.distance)
                .font(.title3.weight(.medium))
                .monospacedDigit()
            Text(display.rate)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}

#Preview("Recording") {
    WatchHomeView()
}
