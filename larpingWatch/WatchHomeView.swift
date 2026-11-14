import SwiftUI

struct WatchHomeView: View {
    private let receiver = MirrorReceiver.shared
    private let recorder = WatchRecorder.shared
    @State private var finish = FinishConfirmation()
    @State private var notReachable = false
    private let monitor = HeartRateMonitor.shared

    /// True while this watch is recording by itself. That takes priority over mirroring.
    private var isOwn: Bool { recorder.state != .idle }
    private var snapshot: MirrorSnapshot { isOwn ? recorder.snapshot : receiver.snapshot }

    var body: some View {
        let current = snapshot
        Group {
            if current.state == .idle {
                startView
            } else {
                recordingView(MirrorDisplay(current), sport: statusLine(for: current))
                    .onChange(of: current.state) { _, new in finish.stateChanged(to: new) }
            }
        }
        // When the watch records by itself, the recorder drives the sensor. Otherwise the
        // sensor only follows what the iPhone is recording.
        .onChange(of: receiver.snapshot.state, initial: true) { _, new in
            if !isOwn { monitor.follow(new) }
        }
        .onChange(of: isOwn) { _, own in
            if !own { monitor.follow(receiver.snapshot.state) }
        }
    }

    /// The watch's own start screen: pick a sport and go. It never waits for the iPhone.
    private var startView: some View {
        NavigationStack {
            List {
                ForEach(WatchSport.allCases, id: \.self) { sport in
                    Button { recorder.start(sport) } label: {
                        Label(sport.label, systemImage: sport.symbolName)
                    }
                }
                if let message = outcomeMessage {
                    Text(message.text)
                        .font(.footnote)
                        .foregroundStyle(message.isProblem ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                    if recorder.outcome == .saveFailed {
                        Button("Retry") { recorder.retrySave() }
                    }
                }
            }
            .navigationTitle("MURY")
        }
    }

    private var outcomeMessage: (text: String, isProblem: Bool)? {
        switch recorder.outcome {
        case .saved(let summary): ("Saved \u{00B7} \(summary)", false)
        case .tooShort: ("Too short to save", false)
        case .saveFailed: ("Could not save", true)
        case nil: nil
        }
    }

    /// The small line above the clock: the sport, a pause or a GPS hint.
    private func statusLine(for snapshot: MirrorSnapshot) -> String {
        guard isOwn else { return snapshot.sportLabel }
        if recorder.locationDenied { return "\(snapshot.sportLabel) \u{00B7} Location off" }
        if snapshot.state == .recording && !recorder.core.hasFix {
            return "\(snapshot.sportLabel) \u{00B7} GPS\u{2026}"
        }
        return snapshot.sportLabel
    }

    private func recordingView(_ display: MirrorDisplay, sport: String) -> some View {
        VStack(spacing: 4) {
            Text(display.isPaused ? "\(sport) \u{00B7} Paused" : sport)
                .lineLimit(1)
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
            HStack(spacing: 10) {
                Text(display.rate)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                heartRateLabel
            }
            controls(for: snapshot.state)
        }
        .padding(.horizontal)
    }

    /// The heart rate, or a dash when there is no fresh reading. It is re-evaluated every
    /// second so that an old number never stays on screen as if it were live.
    private var heartRateLabel: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let display = HeartRateDisplay(monitor.latest, now: context.date)
            Label(display.text, systemImage: "heart.fill")
                .font(.footnote.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(display.isLive ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
        }
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
            if notReachable && !isOwn {
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
        case .pause:
            if isOwn { recorder.pause() } else { notReachable = !receiver.send(command) }
        case .resume:
            if isOwn { recorder.resume() } else { notReachable = !receiver.send(command) }
        }
    }

    private func confirmFinish(in state: MirrorSnapshot.State) {
        guard let command = finish.confirm(in: state) else { return }
        if isOwn { recorder.finish() } else { notReachable = !receiver.send(command) }
    }
}

#Preview("Recording") {
    WatchHomeView()
}
