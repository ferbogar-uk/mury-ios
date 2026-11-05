import Foundation

/// One heart-rate reading measured by the watch, and what to show for it.
///
/// Pure logic on purpose (Foundation only), like MirrorSnapshot: it is shared by the
/// iPhone and the watch app, and its tests run on Linux. The sensor (HealthKit) is
/// not here; it only produces the numbers this type checks. Nothing here stores
/// anything: a reading lives in memory for the length of a recording.
struct HeartRateReading: Equatable {
    /// A value outside this range is a sensor glitch, not a heart rate.
    static let plausibleRange: ClosedRange<Double> = 30...230

    let beatsPerMinute: Int
    let date: Date

    private enum Key {
        static let bpm = "heartRate"
        static let date = "heartRateDate"
    }

    /// Returns nil for a value that is not a plausible heart rate (not a number,
    /// infinite, or outside `plausibleRange`). The range is checked on the raw value,
    /// before rounding to whole beats.
    init?(beatsPerMinute: Double, date: Date) {
        guard beatsPerMinute.isFinite, Self.plausibleRange.contains(beatsPerMinute) else { return nil }
        self.beatsPerMinute = Int(beatsPerMinute.rounded())
        self.date = date
    }

    /// Property-list friendly, like MirrorSnapshot: WatchConnectivity only accepts these types.
    var dictionary: [String: Any] {
        [Key.bpm: beatsPerMinute, Key.date: date.timeIntervalSince1970]
    }

    /// Returns nil when the message is incomplete or malformed, so the iPhone keeps
    /// its last good reading instead of showing garbage. Messages of the other kinds
    /// (MirrorSnapshot, WatchCommand) do not have these keys and are rejected here.
    init?(dictionary: [String: Any]) {
        guard
            let bpm = dictionary[Key.bpm] as? Int,
            let seconds = dictionary[Key.date] as? Double,
            seconds.isFinite
        else { return nil }
        self.init(beatsPerMinute: Double(bpm), date: Date(timeIntervalSince1970: seconds))
    }
}

/// What the screen shows for the latest reading: the number, or a dash when there is
/// nothing trustworthy to show.
struct HeartRateDisplay: Equatable {
    /// A reading older than this is not shown: the sensor lost the wrist, or the
    /// watch app was suspended. Showing an old number as if it were live would mislead.
    static let staleAfter: TimeInterval = 15

    let text: String
    let isLive: Bool

    private static let dash = "\u{2013}"

    /// A reading dated slightly in the future (the two clocks disagree a little) counts
    /// as fresh.
    init(_ reading: HeartRateReading?, now: Date) {
        if let reading = reading, now.timeIntervalSince(reading.date) <= Self.staleAfter {
            text = String(reading.beatsPerMinute)
            isLive = true
        } else {
            text = Self.dash
            isLive = false
        }
    }
}