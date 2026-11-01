import Foundation

struct ReplayCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

struct ReplayPoint {
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double?
    let speedMps: Double?

    init(timestamp: Date, latitude: Double, longitude: Double, altitudeMeters: Double? = nil, speedMps: Double? = nil) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitudeMeters = altitudeMeters
        self.speedMps = speedMps
    }
}

struct ReplayFrame {
    let elapsedSeconds: TimeInterval
    let position: ReplayCoordinate?
    let headingDegrees: Double?
    let altitudeMeters: Double?
    let speedMps: Double?
    let revealedSegments: [[ReplayCoordinate]]
}

struct ReplayTimeline {
    let duration: TimeInterval
    let segments: [[ReplayCoordinate]]
    private let points: [ReplayPoint]
    private let times: [TimeInterval]
    private let segmentIDs: [Int]

    init(points: [ReplayPoint], startedAt: Date, endedAt: Date?) {
        let valid = points.enumerated().filter {
            $0.element.timestamp.timeIntervalSince1970.isFinite &&
            $0.element.latitude.isFinite && (-90...90).contains($0.element.latitude) &&
            $0.element.longitude.isFinite && (-180...180).contains($0.element.longitude)
        }.sorted {
            $0.element.timestamp == $1.element.timestamp ? $0.offset < $1.offset : $0.element.timestamp < $1.element.timestamp
        }
        let start = startedAt.timeIntervalSince1970.isFinite ? startedAt : (valid.first?.element.timestamp ?? Date(timeIntervalSince1970: 0))
        let end = endedAt.flatMap { $0.timeIntervalSince1970.isFinite && $0.timeIntervalSince(start).isFinite && $0 >= start ? $0 : nil }
        var accepted: [ReplayPoint] = []
        for entry in valid {
            let point = entry.element
            guard point.timestamp.timeIntervalSince(start).isFinite, point.timestamp >= start, end.map({ point.timestamp <= $0 }) ?? true,
                  accepted.last?.timestamp != point.timestamp else { continue }
            accepted.append(ReplayPoint(timestamp: point.timestamp, latitude: point.latitude, longitude: point.longitude,
                altitudeMeters: point.altitudeMeters.flatMap { $0.isFinite ? $0 : nil },
                speedMps: point.speedMps.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }))
        }
        self.points = accepted
        times = accepted.map { $0.timestamp.timeIntervalSince(start) }
        duration = accepted.count > 1 ? (end ?? accepted.last!.timestamp).timeIntervalSince(start) : 0
        var routes: [[ReplayCoordinate]] = []
        var ids: [Int] = []
        for (index, point) in accepted.enumerated() {
            let coordinate = ReplayCoordinate(latitude: point.latitude, longitude: point.longitude)
            var gap = index == 0
            if index > 0 {
                let seconds = point.timestamp.timeIntervalSince(accepted[index - 1].timestamp)
                // Prototype heuristic for missing data, not pause detection.
                gap = seconds > 30 || Self.distance(accepted[index - 1], point) / seconds > 100
            }
            if gap { routes.append([]) }
            routes[routes.count - 1].append(coordinate)
            ids.append(routes.count - 1)
        }
        segments = routes
        segmentIDs = ids
    }

    func sample(at elapsed: TimeInterval) -> ReplayFrame {
        let time = elapsed.isFinite ? min(max(elapsed, 0), duration) : 0
        var revealed: [[ReplayCoordinate]] = []
        var index: Int?
        for i in points.indices where times[i] <= time {
            if revealed.count <= segmentIDs[i] { revealed.append([]) }
            revealed[segmentIDs[i]].append(coordinate(points[i]))
            index = i
        }
        func frame(_ position: ReplayCoordinate? = nil, _ heading: Double? = nil, _ altitude: Double? = nil, _ speed: Double? = nil) -> ReplayFrame {
            ReplayFrame(elapsedSeconds: time, position: position, headingDegrees: heading, altitudeMeters: altitude, speedMps: speed, revealedSegments: revealed)
        }
        guard let i = index else { return frame() }
        let a = points[i]
        guard i + 1 < points.count else {
            return time == times[i] ? frame(coordinate(a), nil, a.altitudeMeters, a.speedMps) : frame()
        }
        let b = points[i + 1]
        guard segmentIDs[i] == segmentIDs[i + 1] else {
            return time == times[i] ? frame(coordinate(a), nil, a.altitudeMeters, a.speedMps) : frame()
        }
        let fraction = (time - times[i]) / (times[i + 1] - times[i])
        let longitude = a.longitude + Self.longitudeDelta(a.longitude, b.longitude) * fraction
        let position = ReplayCoordinate(latitude: a.latitude + (b.latitude - a.latitude) * fraction,
            longitude: longitude > 180 ? longitude - 360 : (longitude < -180 ? longitude + 360 : longitude))
        if fraction > 0 { revealed[segmentIDs[i]].append(position) }
        func metric(_ first: Double?, _ second: Double?) -> Double? {
            if fraction == 0 { return first }
            guard let first, let second else { return nil }
            return first * (1 - fraction) + second * fraction
        }
        return frame(position, Self.heading(a, b), metric(a.altitudeMeters, b.altitudeMeters), metric(a.speedMps, b.speedMps))
    }

    private func coordinate(_ point: ReplayPoint) -> ReplayCoordinate {
        ReplayCoordinate(latitude: point.latitude, longitude: point.longitude)
    }

    private static func longitudeDelta(_ a: Double, _ b: Double) -> Double {
        let delta = b - a
        return delta > 180 ? delta - 360 : (delta < -180 ? delta + 360 : delta)
    }

    private static func distance(_ a: ReplayPoint, _ b: ReplayPoint) -> Double {
        let radians = Double.pi / 180
        let latitude = (b.latitude - a.latitude) * radians
        let longitude = longitudeDelta(a.longitude, b.longitude) * radians
        let h = pow(sin(latitude / 2), 2) + cos(a.latitude * radians) * cos(b.latitude * radians) * pow(sin(longitude / 2), 2)
        return 6_371_000 * 2 * asin(sqrt(min(1, max(0, h))))
    }

    private static func heading(_ a: ReplayPoint, _ b: ReplayPoint) -> Double? {
        guard a.latitude != b.latitude || longitudeDelta(a.longitude, b.longitude) != 0 else { return nil }
        let radians = Double.pi / 180
        let longitude = longitudeDelta(a.longitude, b.longitude) * radians
        let y = sin(longitude) * cos(b.latitude * radians)
        let x = cos(a.latitude * radians) * sin(b.latitude * radians) - sin(a.latitude * radians) * cos(b.latitude * radians) * cos(longitude)
        return (atan2(y, x) / radians + 360).truncatingRemainder(dividingBy: 360)
    }
}

struct ReplayPlayback {
    private let duration: TimeInterval
    private(set) var elapsedSeconds: TimeInterval = 0
    private(set) var isPlaying = false
    private(set) var speed = 1.0

    init(duration: TimeInterval) {
        self.duration = duration.isFinite ? max(0, duration) : 0
    }

    mutating func play() {
        guard duration > 0 else { return }
        if elapsedSeconds >= duration { elapsedSeconds = 0 }
        isPlaying = true
    }

    mutating func pause() { isPlaying = false }

    mutating func seek(to time: TimeInterval) {
        elapsedSeconds = time.isFinite ? min(max(time, 0), duration) : 0
        if elapsedSeconds >= duration { isPlaying = false }
    }

    mutating func setSpeed(_ speed: Double) {
        if [1.0, 2.0, 4.0].contains(speed) { self.speed = speed }
    }

    mutating func advance(by delta: TimeInterval) {
        guard isPlaying, delta.isFinite, delta > 0 else { return }
        elapsedSeconds = min(duration, elapsedSeconds + delta * speed)
        if elapsedSeconds >= duration { isPlaying = false }
    }
}
