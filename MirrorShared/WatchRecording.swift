import Foundation

/// The sports the watch can record on its own. The raw values are the same strings
/// the iPhone's `SportType` uses, so a watch recording can be turned into an iPhone
/// activity later without a translation table (WatchRecordingTests checks they match).
enum WatchSport: String, Codable, CaseIterable, Equatable {
    case run, walk, ride, hike

    var label: String {
        switch self {
        case .run: "Run"
        case .walk: "Walk"
        case .ride: "Ride"
        case .hike: "Hike"
        }
    }

    var symbolName: String {
        switch self {
        case .run: "figure.run"
        case .walk: "figure.walk"
        case .ride: "figure.outdoor.cycle"
        case .hike: "figure.hiking"
        }
    }

    /// Same rule as the iPhone: pace for foot sports, speed for cycling.
    var usesPace: Bool { self != .ride }
}

/// One recorded point of a watch recording.
struct WatchTrackPoint: Codable, Equatable {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    /// Nil when the altitude was not trustworthy.
    var altitudeMeters: Double?
    /// Nil when the speed was unknown.
    var speedMps: Double?
    var heartRateBpm: Int?
}

/// A finished recording made on the watch, ready to be stored and, later, sent to the
/// iPhone. The `id` is created once on the watch and never changes, so the iPhone can
/// recognise an activity it already imported and never duplicate it.
struct WatchActivityRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var sport: WatchSport
    var startedAt: Date
    var endedAt: Date
    /// Moving time in whole seconds, pauses excluded (same as the iPhone).
    var durationSeconds: Int
    var distanceMeters: Double
    var elevationGainMeters: Double
    var maxSpeedMps: Double
    var points: [WatchTrackPoint]

    /// Below both limits a recording is almost surely an accidental start, so it is
    /// dropped instead of cluttering the list.
    static let minimumSeconds = 10
    static let minimumMeters = 20.0

    var isTooShort: Bool {
        durationSeconds < Self.minimumSeconds && distanceMeters < Self.minimumMeters
    }
}

/// The recording logic of the watch: state, active time, totals and route points.
///
/// Pure logic (Foundation only), shared with the iPhone target and tested on Linux. It
/// does not talk to GPS or the clock: the watch code feeds it fixes and passes the time
/// in, so every rule here can be tested without a device.
struct WatchRecorderCore: Equatable {
    enum State: Equatable {
        case idle, recording, paused

        /// The same state in the iPhone-mirror vocabulary, used to drive the heart sensor.
        var mirrored: MirrorSnapshot.State {
            switch self {
            case .idle: .idle
            case .recording: .recording
            case .paused: .paused
            }
        }
    }

    private(set) var state: State = .idle
    private(set) var sport: WatchSport = .run
    private(set) var points: [WatchTrackPoint] = []
    private var math = RecorderMath()
    private var startedAt: Date?
    private var activeTime: TimeInterval = 0
    private var segmentStart: Date?

    var distanceMeters: Double { math.distanceMeters }
    var currentSpeedMps: Double { math.currentSpeedMps }
    var isGPSDegraded: Bool { math.isGPSDegraded }
    /// False until the first usable fix of the recording arrives.
    var hasFix: Bool { !points.isEmpty }

    mutating func start(sport: WatchSport, at now: Date) {
        guard state == .idle else { return }
        self = WatchRecorderCore()
        self.sport = sport
        state = .recording
        startedAt = now
        segmentStart = now
    }

    mutating func pause(at now: Date) {
        guard state == .recording else { return }
        if let segmentStart { activeTime += max(0, now.timeIntervalSince(segmentStart)) }
        segmentStart = nil
        state = .paused
    }

    mutating func resume(at now: Date) {
        guard state == .paused else { return }
        segmentStart = now
        state = .recording
    }

    /// Active time in whole seconds at `now`, pauses excluded.
    func elapsedSeconds(at now: Date) -> Int {
        var total = activeTime
        if state == .recording, let segmentStart { total += max(0, now.timeIntervalSince(segmentStart)) }
        return Int(total)
    }

    /// Feeds one GPS fix. Returns whether it became a route point. While paused, or with a
    /// weak signal, the fix is dropped (the totals follow `RecorderMath`, same as the iPhone).
    @discardableResult
    mutating func add(_ fix: GPSFix, at timestamp: Date, heartRate: Int?) -> Bool {
        guard math.add(fix, isRecording: state == .recording) == .accepted else { return false }
        points.append(
            WatchTrackPoint(
                timestamp: timestamp,
                latitude: fix.latitude,
                longitude: fix.longitude,
                altitudeMeters: fix.verticalAccuracy >= 0 ? fix.altitude : nil,
                speedMps: fix.speed >= 0 ? fix.speed : nil,
                heartRateBpm: heartRate
            )
        )
        return true
    }

    /// Ends the recording and returns it, or nil when there was nothing recording.
    /// The core goes back to idle either way, ready for the next one.
    mutating func finish(at now: Date, id: UUID = UUID()) -> WatchActivityRecord? {
        guard state != .idle, let startedAt else { return nil }
        let duration = elapsedSeconds(at: now)
        let record = WatchActivityRecord(
            id: id, sport: sport, startedAt: startedAt, endedAt: now,
            durationSeconds: duration, distanceMeters: math.distanceMeters,
            elevationGainMeters: math.elevationGainMeters, maxSpeedMps: math.maxSpeedMps,
            points: points
        )
        self = WatchRecorderCore()
        return record
    }

    /// What the watch screen shows, reusing the iPhone's number formatting.
    func snapshot(at now: Date) -> MirrorSnapshot {
        MirrorSnapshot(
            state: state.mirrored, elapsedSeconds: elapsedSeconds(at: now),
            distanceMeters: distanceMeters, speedMetersPerSecond: currentSpeedMps,
            sportLabel: sport.label, usesPace: sport.usesPace
        )
    }
}

/// Keeps finished watch recordings on the watch, one JSON file each, until they have
/// reached the iPhone. Nothing leaves the device from here.
struct WatchActivityStore {
    let directory: URL

    init(directory: URL) { self.directory = directory }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    /// Writes the recording atomically, so a crash or a flat battery in the middle of a
    /// save never leaves a half-written file.
    func save(_ record: WatchActivityRecord) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(record).write(to: url(for: record.id), options: .atomic)
    }

    /// Every readable recording, oldest first. A damaged file is skipped, not fatal.
    func loadAll() -> [WatchActivityRecord] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(WatchActivityRecord.self, from: Data(contentsOf: $0)) }
            .sorted { $0.startedAt < $1.startedAt }
    }

    func delete(id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
    }
}
