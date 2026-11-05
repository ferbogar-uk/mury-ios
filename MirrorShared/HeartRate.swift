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

/// What the watch's heart-rate sensor is doing.
enum HeartRateSensorState: Equatable {
    case stopped, running, paused
}

/// What the sensor should do next.
enum HeartRateSensorAction: Equatable {
    case start, pause, resume, stop, nothing
}

/// Decides what the sensor should do so that it follows what the iPhone is recording.
/// The sensor never decides on its own: the iPhone is the one recording, the watch only
/// measures while a recording is under way.
enum HeartRateSensorPlan {
    static func action(
        mirrored: MirrorSnapshot.State, sensor: HeartRateSensorState
    ) -> HeartRateSensorAction {
        switch (mirrored, sensor) {
        case (.recording, .stopped): return .start
        case (.recording, .paused): return .resume
        case (.paused, .running): return .pause
        case (.idle, .running), (.idle, .paused): return .stop
        default: return .nothing
        }
    }
}

/// Collects the readings of one recording and says where each belongs on the route.
///
/// Pure logic (Foundation only), tested on Linux. It lives in memory for the length of a
/// recording and is emptied when the recording is saved or dropped. The iPhone keeps
/// every reading so that, when the activity is saved, each one can be attached to the
/// route point closest to it in time. Averages and maximums are then worked out from the
/// stored points, the same way they already are for activities imported from Health.
struct HeartRateLog: Equatable {
    /// A reading further than this from any route point is not attached: the watch
    /// measured it while the iPhone was not recording a position (for example during a
    /// pause), so it does not describe that point.
    static let maxGapToPoint: TimeInterval = 10

    private(set) var readings: [HeartRateReading] = []

    var isEmpty: Bool { readings.isEmpty }

    mutating func add(_ reading: HeartRateReading) {
        // Out-of-order or repeated readings are dropped: the average must not count one twice.
        if let last = readings.last, reading.date <= last.date { return }
        readings.append(reading)
    }

    mutating func clear() { readings.removeAll() }

    /// Heart rate for each route point, in the same order as `pointDates`. Each reading
    /// goes to the nearest point in time, and a point keeps the highest reading that
    /// landed on it, so a peak is never lost.
    func assign(toPointsAt pointDates: [Date]) -> [Int?] {
        var result = [Int?](repeating: nil, count: pointDates.count)
        guard !readings.isEmpty, !pointDates.isEmpty else { return result }
        for reading in readings {
            var best: Int?
            var bestGap = TimeInterval.infinity
            for (index, date) in pointDates.enumerated() {
                let gap = abs(date.timeIntervalSince(reading.date))
                if gap < bestGap { bestGap = gap; best = index }
            }
            guard let index = best, bestGap <= Self.maxGapToPoint else { continue }
            result[index] = max(result[index] ?? 0, reading.beatsPerMinute)
        }
        return result
    }
}
