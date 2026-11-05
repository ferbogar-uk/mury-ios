import Foundation
import Observation
import WatchConnectivity

/// Watch side of the mirror. Receives what the iPhone is recording and keeps
/// the newest snapshot for the screen. It never records anything itself.
@MainActor
@Observable
final class MirrorReceiver: NSObject, WCSessionDelegate {
    static let shared = MirrorReceiver()

    private(set) var snapshot: MirrorSnapshot = .idle
    private(set) var hasReceivedAnything = false

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Sends a command to the iPhone. It only works while the iPhone is reachable;
    /// otherwise it is dropped and the screen keeps showing the last good state.
    /// Returns whether it was handed to the iPhone, so the screen can tell the person.
    @discardableResult
    func send(_ command: WatchCommand) -> Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return false }
        session.sendMessage(command.dictionary, replyHandler: nil, errorHandler: nil)
        return true
    }

    /// Sends a heart-rate reading to the iPhone. It is dropped when the iPhone is not
    /// reachable: the next reading comes within seconds, so nothing is worth queueing.
    func send(_ reading: HeartRateReading) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(reading.dictionary, replyHandler: nil, errorHandler: nil)
    }

    private func apply(_ dictionary: [String: Any]) {
        // A malformed message is ignored: the screen keeps its last good state.
        guard let next = MirrorSnapshot(dictionary: dictionary) else { return }
        snapshot = next
        hasReceivedAnything = true
    }

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // The iPhone may have sent a state before this app was open.
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        Task { @MainActor in self.apply(context) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message) }
    }

    nonisolated func session(
        _ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in self.apply(applicationContext) }
    }
}
