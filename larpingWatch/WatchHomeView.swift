import SwiftUI

struct WatchHomeView: View {
    private let receiver = MirrorReceiver.shared
    @State private var finish = FinishConfirmation()
    @State private var notReachable = false

    var body: some View {
        let snapshot = receiver.snapshot
        if snapshot.state == .idle {
            idleView
        } else {
            recordingView(MirrorDisplay(snapshot), sport: snapshot.sportLabel)
                .onChange(of: snapshot.state) { _, new in finish.stateChanged(to: new) }
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
            controls(for: receiver.snapshot.state)
        }
        .padding(.horizontal)
    }

    /// The buttons the current state allows. Finish needs a second tap to confirm,
    /// and even then the iPhone asks again before anything is saved.
    @ViewBuilder
    private func controls(for state: MirrorSnapshot.State) -> some View {
        if finish.isAwaiting {
            HStack(spacing: 8) {
                Button("Cancel") { finish.cancel() }
                    .buttonStyle(.bordered)
                Button("Finish?") { confirmFinish(in: state) }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
            .font(.footnote)
            .task(id: finish.isAwaiting) {
                // A forgotten first tap disarms itself.
                try? await Task.sleep(for: .seconds(4))
                finish.cancel()
            }
        } else {
            HStack(spacing: 8) {
                ForEach(WatchControls.availableCommands(in: state), id: \.self) { command in
                    Button(label(for: command)) { tap(command, in: state) }
                        .buttonStyle(.bordered)
                }
            }
            .font(.footnote)
            if notReachable {
                Text("iPhone not reachable")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func label(for command: WatchCommand) -> String {
        switch command {
        case .pause: "Pause"
        case .resume: "Resume"
        case .finish: "Finish"
        }
    }

    private func tap(_ command: WatchCommand, in state: MirrorSnapshot.State) {
        notReachable = false
        switch command {
        case .finish:
            _ = finish.requestFinish(in: state)
        case .pause, .resume:
            notReachable = !receiver.send(command)
        }
    }

    private func confirmFinish(in state: MirrorSnapshot.State) {
        guard let command = finish.confirm(in: state) else { return }
        notReachable = !receiver.send(command)
    }
}

#Preview("Recording") {
    WatchHomeView()
}
