import Foundation

/// A command the watch can send to the iPhone while a recording is running.
///
/// Starting is deliberately not here: it needs a sport and an event name, which
/// are chosen on the iPhone. Foundation only, shared by both apps, tested on Linux.
enum WatchCommand: String, Equatable, CaseIterable {
    case pause, resume, finish

    private static let key = "command"

    /// Property-list friendly, for WatchConnectivity.
    var dictionary: [String: Any] { [Self.key: rawValue] }

    /// Nil for anything that is not exactly a known command.
    init?(dictionary: [String: Any]) {
        guard let raw = dictionary[Self.key] as? String, let c = WatchCommand(rawValue: raw) else { return nil }
        self = c
    }
}

/// What the iPhone should do with a command that arrived while in a given state.
enum CommandDecision: Equatable {
    case pause, resume, finish
    /// A command that does not fit the state (a second "pause", a late "resume",
    /// anything while idle). It is dropped silently, never an error.
    case ignore
}

/// The rules for which commands are valid, and the buttons the watch should show.
enum WatchControls {
    /// Decides what to do with `command` given the iPhone's current state.
    static func decide(_ command: WatchCommand, in state: MirrorSnapshot.State) -> CommandDecision {
        switch (state, command) {
        case (.recording, .pause): return .pause
        case (.paused, .resume): return .resume
        case (.recording, .finish), (.paused, .finish): return .finish
        default: return .ignore
        }
    }

    /// Which buttons make sense right now, in the order they are shown.
    static func availableCommands(in state: MirrorSnapshot.State) -> [WatchCommand] {
        switch state {
        case .idle: return []
        case .recording: return [.pause, .finish]
        case .paused: return [.resume, .finish]
        }
    }
}

/// Finishing from the wrist needs a second tap, so a stray touch cannot end
/// and save an activity. Nothing is sent until the second tap.
struct FinishConfirmation: Equatable {
    private(set) var isAwaiting = false

    /// First tap on Finish: ask to confirm. Returns false if there was nothing to finish.
    mutating func requestFinish(in state: MirrorSnapshot.State) -> Bool {
        guard state != .idle else { isAwaiting = false; return false }
        isAwaiting = true
        return true
    }

    /// Second tap: only valid right after the first. Returns the command to send, or nil.
    mutating func confirm(in state: MirrorSnapshot.State) -> WatchCommand? {
        defer { isAwaiting = false }
        guard isAwaiting, state != .idle else { return nil }
        return .finish
    }

    /// Cancel, a timeout, or the recording ended by itself.
    mutating func cancel() { isAwaiting = false }

    /// Call whenever the iPhone state changes: a stale confirmation is dropped
    /// when the recording is gone.
    mutating func stateChanged(to state: MirrorSnapshot.State) {
        if state == .idle { isAwaiting = false }
    }
}
