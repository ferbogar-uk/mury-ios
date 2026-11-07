import Foundation

/// Foundation-only camera script for the route flyover (the Strava-style opening).
///
/// The clip is split in four phases, scaled to the chosen length:
/// overview (top-down, whole route) -> orbit (one full turn while tilting down onto the start)
/// -> follow (camera chases the moving point, trail grows) -> finish (pull back to the whole route).
struct FlyoverPlan {
    enum Phase: Equatable {
        case overview, orbit, follow, finish
    }

    struct State: Equatable {
        let phase: Phase
        let centerLatitude: Double
        let centerLongitude: Double
        let distanceMeters: Double
        let headingDegrees: Double
        let pitchDegrees: Double
        /// Seconds into the recorded activity that the trail should be revealed to.
        let routeElapsedSeconds: TimeInterval
        /// 0...1 share of the activity already played.
        let routeProgress: Double
    }

    static let followDistanceMeters = 700.0
    static let followPitchDegrees = 55.0
    /// Share of the clip each phase takes. They add up to 1.
    static let phaseShares: [(phase: Phase, share: Double)] = [
        (.overview, 0.12), (.orbit, 0.20), (.follow, 0.58), (.finish, 0.10)
    ]

    let clipSeconds: TimeInterval
    let isUsable: Bool
    let overviewDistanceMeters: Double

    private let timeline: ReplayTimeline
    private let boxCenter: ReplayCoordinate
    private let start: ReplayCoordinate
    private let startHeading: Double

    init(timeline: ReplayTimeline, clipSeconds: TimeInterval) {
        self.timeline = timeline
        self.clipSeconds = clipSeconds.isFinite ? max(1, clipSeconds) : 30
        let all = timeline.segments.flatMap { $0 }
        guard timeline.duration > 0, all.count > 1 else {
            isUsable = false
            overviewDistanceMeters = 2_000
            boxCenter = ReplayCoordinate(latitude: 0, longitude: 0)
            start = boxCenter
            startHeading = 0
            return
        }
        isUsable = true
        let latitudes = all.map(\.latitude)
        let longitudes = all.map(\.longitude)
        let minLat = latitudes.min()!, maxLat = latitudes.max()!
        let minLon = longitudes.min()!, maxLon = longitudes.max()!
        let centerLat = (minLat + maxLat) / 2
        boxCenter = ReplayCoordinate(latitude: centerLat, longitude: (minLon + maxLon) / 2)
        start = all[0]
        let metersPerDegree = 111_320.0
        let height = (maxLat - minLat) * metersPerDegree
        let width = (maxLon - minLon) * metersPerDegree * max(0.1, cos(centerLat * .pi / 180))
        // Top-down camera: distance is roughly 2.6 times the longest side so the route fits a portrait screen.
        overviewDistanceMeters = min(2_000_000, max(1_500, max(width, height) * 2.6))
        startHeading = FlyoverPlan.followHeading(timeline: timeline, progress: 0)
    }

    /// Start and end time (seconds into the clip) of a phase.
    func range(of phase: Phase) -> ClosedRange<TimeInterval> {
        var begin = 0.0
        for entry in FlyoverPlan.phaseShares {
            let end = begin + entry.share * clipSeconds
            if entry.phase == phase { return begin...end }
            begin = end
        }
        return clipSeconds...clipSeconds
    }

    func state(at time: TimeInterval) -> State {
        let t = time.isFinite ? min(max(time, 0), clipSeconds) : 0
        let overview = range(of: .overview)
        let orbit = range(of: .orbit)
        let follow = range(of: .follow)
        let finish = range(of: .finish)
        let followStart = followCenter(progress: 0)
        let followEnd = followCenter(progress: 1)
        let endHeading = FlyoverPlan.followHeading(timeline: timeline, progress: 1)

        if t < overview.upperBound {
            return State(phase: .overview, centerLatitude: boxCenter.latitude, centerLongitude: boxCenter.longitude,
                         distanceMeters: overviewDistanceMeters, headingDegrees: 0, pitchDegrees: 0,
                         routeElapsedSeconds: 0, routeProgress: 0)
        }
        if t < orbit.upperBound {
            let e = FlyoverPlan.smooth(FlyoverPlan.fraction(t, in: orbit))
            return State(phase: .orbit,
                         centerLatitude: FlyoverPlan.mix(boxCenter.latitude, followStart.latitude, e),
                         centerLongitude: FlyoverPlan.mix(boxCenter.longitude, followStart.longitude, e),
                         distanceMeters: FlyoverPlan.mix(overviewDistanceMeters, FlyoverPlan.followDistanceMeters, e),
                         // One full turn, ending exactly on the heading the follow phase starts with.
                         headingDegrees: FlyoverPlan.normalized((360 + startHeading) * e),
                         pitchDegrees: FlyoverPlan.followPitchDegrees * e,
                         routeElapsedSeconds: 0, routeProgress: 0)
        }
        if t < follow.upperBound {
            let progress = FlyoverPlan.fraction(t, in: follow)
            let center = followCenter(progress: progress)
            return State(phase: .follow, centerLatitude: center.latitude, centerLongitude: center.longitude,
                         distanceMeters: FlyoverPlan.followDistanceMeters,
                         headingDegrees: FlyoverPlan.followHeading(timeline: timeline, progress: progress),
                         pitchDegrees: FlyoverPlan.followPitchDegrees,
                         routeElapsedSeconds: progress * timeline.duration, routeProgress: progress)
        }
        let e = FlyoverPlan.smooth(FlyoverPlan.fraction(t, in: finish))
        return State(phase: .finish,
                     centerLatitude: FlyoverPlan.mix(followEnd.latitude, boxCenter.latitude, e),
                     centerLongitude: FlyoverPlan.mix(followEnd.longitude, boxCenter.longitude, e),
                     distanceMeters: FlyoverPlan.mix(FlyoverPlan.followDistanceMeters, overviewDistanceMeters, e),
                     headingDegrees: FlyoverPlan.normalized(endHeading + FlyoverPlan.shortestDelta(from: endHeading, to: 0) * e),
                     pitchDegrees: FlyoverPlan.followPitchDegrees * (1 - e),
                     routeElapsedSeconds: timeline.duration, routeProgress: 1)
    }

    // MARK: - Route helpers

    /// Where the camera centres at a share of the activity. Skips GPS gaps by looking back for the last known position.
    private func followCenter(progress: Double) -> ReplayCoordinate {
        FlyoverPlan.position(timeline: timeline, progress: progress) ?? start
    }

    static func position(timeline: ReplayTimeline, progress: Double) -> ReplayCoordinate? {
        let clamped = min(max(progress, 0), 1)
        if let now = timeline.sample(at: clamped * timeline.duration).position { return now }
        // Inside a gap (or on the last instant): walk back in 1 percent steps.
        for step in 1...100 {
            let back = clamped - Double(step) / 100
            if back < 0 { break }
            if let found = timeline.sample(at: back * timeline.duration).position { return found }
        }
        for step in 1...100 {
            let ahead = clamped + Double(step) / 100
            if ahead > 1 { break }
            if let found = timeline.sample(at: ahead * timeline.duration).position { return found }
        }
        return nil
    }

    /// Smoothed travel direction: bearing between the route a little behind and a little ahead, so the camera does not twitch with GPS noise.
    static func followHeading(timeline: ReplayTimeline, progress: Double) -> Double {
        let window = 0.04
        let from = position(timeline: timeline, progress: max(0, progress - window))
        let to = position(timeline: timeline, progress: min(1, progress + window))
        if let from, let to, let bearing = bearing(from: from, to: to) { return bearing }
        let single = timeline.sample(at: min(max(progress, 0), 1) * timeline.duration)
        return single.headingDegrees ?? 0
    }

    static func bearing(from a: ReplayCoordinate, to b: ReplayCoordinate) -> Double? {
        let radians = Double.pi / 180
        var deltaLon = b.longitude - a.longitude
        if deltaLon > 180 { deltaLon -= 360 } else if deltaLon < -180 { deltaLon += 360 }
        guard a.latitude != b.latitude || deltaLon != 0 else { return nil }
        let l = deltaLon * radians
        let y = sin(l) * cos(b.latitude * radians)
        let x = cos(a.latitude * radians) * sin(b.latitude * radians) - sin(a.latitude * radians) * cos(b.latitude * radians) * cos(l)
        return normalized(atan2(y, x) / radians)
    }

    // MARK: - Maths

    static func smooth(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    static func fraction(_ t: TimeInterval, in range: ClosedRange<TimeInterval>) -> Double {
        let length = range.upperBound - range.lowerBound
        guard length > 0 else { return 1 }
        return min(max((t - range.lowerBound) / length, 0), 1)
    }

    static func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    /// Signed shortest turn from one heading to another, in -180...180.
    static func shortestDelta(from: Double, to: Double) -> Double {
        var delta = (to - from).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
        return delta
    }
}
