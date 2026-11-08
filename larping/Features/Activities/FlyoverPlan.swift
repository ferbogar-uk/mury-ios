import Foundation

/// Foundation-only camera script for the route flyover (the Strava-style opening).
///
/// The clip is split in four phases, scaled to the chosen length:
/// overview (top-down, whole route fitted to the screen) -> orbit (a quarter turn while tilting down onto the start)
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
        /// Height of the position marker above its spot: 1 = high above (or not yet shown), 0 = landed. It drops in during the orbit.
        let markerDrop: Double
    }

    static let followDistanceMeters = 450.0
    /// MapKit clamps pitch to what the map allows at that zoom, so asking for a high value is safe.
    static let followPitchDegrees = 65.0
    /// The marker starts falling at this share of the orbit and lands as the orbit ends.
    static let dropStartShareOfOrbit = 0.45
    /// Share of the clip each phase takes. They add up to 1.
    static let phaseShares: [(phase: Phase, share: Double)] = [
        (.overview, 0.12), (.orbit, 0.20), (.follow, 0.58), (.finish, 0.10)
    ]

    let clipSeconds: TimeInterval
    let isUsable: Bool
    let overviewDistanceMeters: Double

    private let timeline: ReplayTimeline
    /// Centre of the route as it sits on screen when the camera looks along `overviewHeading`.
    private let boxCenter: ReplayCoordinate
    private let overviewHeading: Double
    private let start: ReplayCoordinate
    private let startHeading: Double
    private let endHeading: Double
    private let followStartCenter: ReplayCoordinate
    private let followEndCenter: ReplayCoordinate
    /// Pre-smoothed travel direction at 121 evenly spaced points along the activity.
    private let headingTable: [Double]

    init(timeline: ReplayTimeline, clipSeconds: TimeInterval) {
        self.timeline = timeline
        self.clipSeconds = clipSeconds.isFinite ? max(1, clipSeconds) : 30
        let all = timeline.segments.flatMap { $0 }
        guard timeline.duration > 0, all.count > 1 else {
            isUsable = false
            overviewDistanceMeters = 2_000
            boxCenter = ReplayCoordinate(latitude: 0, longitude: 0)
            overviewHeading = 0
            start = boxCenter
            startHeading = 0
            endHeading = 0
            followStartCenter = boxCenter
            followEndCenter = boxCenter
            headingTable = []
            return
        }
        isUsable = true
        let table = (0...120).map { FlyoverPlan.smoothedHeading(timeline: timeline, progress: Double($0) / 120) }
        headingTable = table
        startHeading = table[0]
        endHeading = table[120]
        start = all[0]
        // The opening looks 90 degrees off the first step (route heads across the screen), then swings a quarter turn onto it.
        let opening = FlyoverPlan.normalized(table[0] - 90)
        overviewHeading = opening
        let fit = FlyoverPlan.overviewFit(points: all, headingDegrees: opening)
        boxCenter = fit.center
        overviewDistanceMeters = fit.distance
        followStartCenter = FlyoverPlan.position(timeline: timeline, progress: 0) ?? all[0]
        followEndCenter = FlyoverPlan.position(timeline: timeline, progress: 1) ?? all[all.count - 1]
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
        let followStart = followStartCenter
        let followEnd = followEndCenter

        if t < overview.upperBound {
            return State(phase: .overview, centerLatitude: boxCenter.latitude, centerLongitude: boxCenter.longitude,
                         distanceMeters: overviewDistanceMeters, headingDegrees: overviewHeading, pitchDegrees: 0,
                         routeElapsedSeconds: 0, routeProgress: 0, markerDrop: 1)
        }
        if t < orbit.upperBound {
            let e = FlyoverPlan.smooth(FlyoverPlan.fraction(t, in: orbit))
            return State(phase: .orbit,
                         centerLatitude: FlyoverPlan.mix(boxCenter.latitude, followStart.latitude, e),
                         centerLongitude: FlyoverPlan.mix(boxCenter.longitude, followStart.longitude, e),
                         distanceMeters: FlyoverPlan.mix(overviewDistanceMeters, FlyoverPlan.followDistanceMeters, e),
                         // A quarter turn, ending exactly on the heading the follow phase starts with.
                         headingDegrees: FlyoverPlan.normalized(overviewHeading + 90 * e),
                         pitchDegrees: FlyoverPlan.followPitchDegrees * e,
                         routeElapsedSeconds: 0, routeProgress: 0,
                         markerDrop: 1 - FlyoverPlan.bounceOut(FlyoverPlan.fraction(FlyoverPlan.fraction(t, in: orbit), in: FlyoverPlan.dropStartShareOfOrbit...1)))
        }
        if t < follow.upperBound {
            let progress = FlyoverPlan.fraction(t, in: follow)
            let center = followCenter(progress: progress)
            return State(phase: .follow, centerLatitude: center.latitude, centerLongitude: center.longitude,
                         distanceMeters: FlyoverPlan.followDistanceMeters,
                         headingDegrees: heading(at: progress),
                         pitchDegrees: FlyoverPlan.followPitchDegrees,
                         routeElapsedSeconds: progress * timeline.duration, routeProgress: progress, markerDrop: 0)
        }
        let e = FlyoverPlan.smooth(FlyoverPlan.fraction(t, in: finish))
        return State(phase: .finish,
                     centerLatitude: FlyoverPlan.mix(followEnd.latitude, boxCenter.latitude, e),
                     centerLongitude: FlyoverPlan.mix(followEnd.longitude, boxCenter.longitude, e),
                     distanceMeters: FlyoverPlan.mix(FlyoverPlan.followDistanceMeters, overviewDistanceMeters, e),
                     headingDegrees: FlyoverPlan.normalized(endHeading + FlyoverPlan.shortestDelta(from: endHeading, to: overviewHeading) * e),
                     pitchDegrees: FlyoverPlan.followPitchDegrees * (1 - e),
                     routeElapsedSeconds: timeline.duration, routeProgress: 1, markerDrop: 0)
    }

    // MARK: - Route helpers

    /// Visible span of a top-down camera per metre of camera distance, portrait phone, with a margin.
    /// Width is the tight side (about 0.25 of the distance), height about 0.5.
    static let metersOfDistancePerMeterOfWidth = 5.0
    static let metersOfDistancePerMeterOfHeight = 2.4

    /// Where to point a top-down camera, and from how far, so every point of the route fits the screen
    /// when the camera looks along `headingDegrees` (screen up = that compass heading).
    static func overviewFit(points: [ReplayCoordinate], headingDegrees: Double) -> (center: ReplayCoordinate, distance: Double) {
        guard let first = points.first else { return (ReplayCoordinate(latitude: 0, longitude: 0), 2_000) }
        let metersPerDegree = 111_320.0
        let latitudes = points.map { $0.latitude }
        let reference = (latitudes.min()! + latitudes.max()!) / 2
        let lonScale = metersPerDegree * max(0.1, cos(reference * Double.pi / 180))
        let radians = headingDegrees * Double.pi / 180
        let sine = sin(radians), cosine = cos(radians)
        var minRight = Double.infinity, maxRight = -Double.infinity
        var minUp = Double.infinity, maxUp = -Double.infinity
        for point in points {
            var deltaLon = point.longitude - first.longitude
            if deltaLon > 180 { deltaLon -= 360 } else if deltaLon < -180 { deltaLon += 360 }
            let east = deltaLon * lonScale
            let north = (point.latitude - first.latitude) * metersPerDegree
            let right = east * cosine - north * sine
            let up = east * sine + north * cosine
            minRight = min(minRight, right); maxRight = max(maxRight, right)
            minUp = min(minUp, up); maxUp = max(maxUp, up)
        }
        let centerRight = (minRight + maxRight) / 2
        let centerUp = (minUp + maxUp) / 2
        let east = centerRight * cosine + centerUp * sine
        let north = -centerRight * sine + centerUp * cosine
        let center = ReplayCoordinate(latitude: first.latitude + north / metersPerDegree,
                                      longitude: first.longitude + east / lonScale)
        let distance = max(1_500, (maxRight - minRight) * metersOfDistancePerMeterOfWidth,
                           (maxUp - minUp) * metersOfDistancePerMeterOfHeight)
        return (center, min(2_000_000, distance))
    }

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

    /// Travel direction at a point of the table, interpolated the short way round.
    private func heading(at progress: Double) -> Double {
        guard headingTable.count > 1 else { return startHeading }
        let x = min(max(progress, 0), 1) * Double(headingTable.count - 1)
        let i = min(Int(x), headingTable.count - 2)
        let f = x - Double(i)
        let a = headingTable[i], b = headingTable[i + 1]
        return FlyoverPlan.normalized(a + FlyoverPlan.shortestDelta(from: a, to: b) * f)
    }

    /// Stabilised travel direction for a camera that chases the route. GPS bearings jump around from
    /// point to point, so this averages the local bearing over roughly +-9% of the route (triangular
    /// weights, circular mean). Used by the flyover and by the live replay.
    static func smoothedHeading(timeline: ReplayTimeline, progress: Double) -> Double {
        guard timeline.duration > 0 else { return 0 }
        let p = min(max(progress, 0), 1)
        var sumX = 0.0, sumY = 0.0
        for k in -4...4 {
            let q = p + Double(k) * 0.02
            let from = position(timeline: timeline, progress: min(max(q - 0.01, 0), 1))
            let to = position(timeline: timeline, progress: min(max(q + 0.01, 0), 1))
            guard let from, let to, let direction = bearing(from: from, to: to) else { continue }
            let weight = Double(5 - abs(k))
            let radians = direction * Double.pi / 180
            sumX += weight * sin(radians)
            sumY += weight * cos(radians)
        }
        if sumX * sumX + sumY * sumY > 1e-9 {
            return normalized(atan2(sumX, sumY) * 180 / Double.pi)
        }
        return timeline.sample(at: p * timeline.duration).headingDegrees ?? 0
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

    /// Ease-out bounce: 0 -> 1 with a few diminishing bounces, so a falling marker settles on its spot.
    static func bounceOut(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        let n = 7.5625, d = 2.75
        if t < 1 / d { return n * t * t }
        if t < 2 / d { let u = t - 1.5 / d; return n * u * u + 0.75 }
        if t < 2.5 / d { let u = t - 2.25 / d; return n * u * u + 0.9375 }
        let u = t - 2.625 / d
        return n * u * u + 0.984375
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
