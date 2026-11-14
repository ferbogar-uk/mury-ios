import Foundation
import Observation
import WatchConnectivity

/// iPhone side of the watch mirror. Sends the recording state to the watch.
///
/// It only transports `MirrorSnapshot`; all formatting lives in the pure-logic
/// files. Recording never depends on the watch: if there is no paired watch, or
/// it is out of reach, every call here silently does nothing.
@MainActor
@Observable
final class WatchMirror: NSObject, WCSessionDelegate {
    static let shared = WatchMirror()

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    @ObservationIgnored private var lastSent: MirrorSnapshot?

    /// The newest heart rate the watch measured, for the Record tab. It is never stored:
    /// it is cleared as soon as the recording ends.
    private(set) var heartRate: HeartRateReading?

    /// Every reading of the current recording, kept so the average and the maximum can be
    /// saved with the activity. In memory only; it is emptied by `takeHeartRateLog()`.
    @ObservationIgnored private var heartRateLog = HeartRateLog()

    /// Hands over the readings of the recording that is ending and empties the log, so the
    /// next recording starts clean. Call it before the recorder stops.
    func takeHeartRateLog() -> HeartRateLog {
        let log = heartRateLog
        heartRateLog.clear()
        return log
    }

    /// Set by the app root. Called on the main actor with each valid command from the watch.
    @ObservationIgnored var onCommand: ((WatchCommand) -> Void)?

    /// Set by the app root. Called on the main actor when a recording from the watch has
    /// arrived in the inbox.
    @ObservationIgnored var onRecordingReceived: (() -> Void)?

    /// Where recordings from the watch wait until they are imported. They live here, not in
    /// memory, so one that arrives while the app is closed is still imported on the next launch.
    nonisolated static var inbox: WatchActivityStore {
        WatchActivityStore(directory: URL.applicationSupportDirectory.appendingPathComponent("WatchInbox", isDirectory: true))
    }

    /// Call once at launch.
    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Sends the snapshot if it differs from the last one and the watch is reachable.
    func send(_ snapshot: MirrorSnapshot) {
        if snapshot.state == .idle {
            heartRate = nil
            // A recording that ends without being saved must not leak into the next one.
            heartRateLog.clear()
        }
        guard let session, session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled else { return }
        guard snapshot != lastSent else { return }
        lastSent = snapshot
        if session.isReachable {
            session.sendMessage(snapshot.dictionary, replyHandler: nil, errorHandler: nil)
        }
        // Keeps the newest state for when the watch app opens later.
        try? session.updateApplicationContext(snapshot.dictionary)
    }

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let reading = HeartRateReading(dictionary: message) {
            Task { @MainActor in
                self.heartRate = reading
                self.heartRateLog.add(reading)
            }
            return
        }
        // Anything that is not exactly a known command is dropped.
        guard let command = WatchCommand(dictionary: message) else { return }
        Task { @MainActor in self.onCommand?(command) }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // The system deletes the file when this method returns, so it is copied at once.
        // A file that is not a recording is dropped.
        guard let data = try? Data(contentsOf: file.fileURL),
              let record = try? WatchActivityRecord.decode(data),
              (try? Self.inbox.save(record)) != nil
        else { return }
        Task { @MainActor in self.onRecordingReceived?() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
