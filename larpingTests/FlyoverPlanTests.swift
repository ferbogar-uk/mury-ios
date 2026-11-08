import XCTest
@testable import larping

final class FlyoverPlanTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1000)

    /// Ten points heading due east, 10 s apart: 90 s long, about 1 km across.
    private func eastboundTimeline() -> ReplayTimeline {
        let points = (0..<10).map {
            ReplayPoint(timestamp: origin.addingTimeInterval(Double($0) * 10), latitude: 0, longitude: Double($0) * 0.001)
        }
        return ReplayTimeline(points: points, startedAt: origin, endedAt: nil)
    }

    func testPhasesCoverTheWholeClipAndScaleWithLength() {
        XCTAssertEqual(FlyoverPlan.phaseShares.map { $0.share }.reduce(0, +), 1, accuracy: 1e-9)
        for seconds in [15.0, 30, 60] {
            let plan = FlyoverPlan(timeline: eastboundTimeline(), clipSeconds: seconds)
            XCTAssertEqual(plan.range(of: .overview).lowerBound, 0)
            XCTAssertEqual(plan.range(of: .finish).upperBound, seconds, accuracy: 1e-9)
            XCTAssertEqual(plan.range(of: .overview).upperBound, plan.range(of: .orbit).lowerBound, accuracy: 1e-9)
            XCTAssertEqual(plan.range(of: .orbit).upperBound, plan.range(of: .follow).lowerBound, accuracy: 1e-9)
            XCTAssertEqual(plan.range(of: .follow).upperBound, plan.range(of: .finish).lowerBound, accuracy: 1e-9)
        }
        let thirty = FlyoverPlan(timeline: eastboundTimeline(), clipSeconds: 30)
        XCTAssertEqual(thirty.range(of: .overview).upperBound, 3.6, accuracy: 1e-9)
        XCTAssertEqual(thirty.range(of: .follow).upperBound, 27, accuracy: 1e-9)
    }

    func testOpensTopDownOnTheWholeRoute() {
        let plan = FlyoverPlan(timeline: eastboundTimeline(), clipSeconds: 30)
        let state = plan.state(at: 0)
        XCTAssertTrue(plan.isUsable)
        XCTAssertEqual(state.phase, .overview)
        XCTAssertEqual(state.pitchDegrees, 0)
        XCTAssertEqual(state.centerLongitude, 0.0045, accuracy: 1e-9)
        XCTAssertEqual(state.distanceMeters, plan.overviewDistanceMeters)
        XCTAssertEqual(state.routeProgress, 0)
        XCTAssertGreaterThan(plan.overviewDistanceMeters, 2_000)
    }

    func testOrbitTurnsOnceAndLandsCentredOnTheStartFacingTheRoute() {
        let plan = FlyoverPlan(timeline: eastboundTimeline(), clipSeconds: 30)
        let orbit = plan.range(of: .orbit)
        let middle = plan.state(at: (orbit.lowerBound + orbit.upperBound) / 2)
        XCTAssertEqual(middle.phase, .orbit)
        // Tilts up early (more than half-way by the middle) while still far from the start.
        XCTAssertGreaterThan(middle.pitchDegrees, FlyoverPlan.followPitchDegrees / 2)
        XCTAssertLessThanOrEqual(middle.pitchDegrees, FlyoverPlan.followPitchDegrees)
        XCTAssertGreaterThan(middle.distanceMeters, FlyoverPlan.followDistanceMeters)
        XCTAssertLessThan(middle.distanceMeters, plan.overviewDistanceMeters)
        let linearMiddle = (plan.overviewDistanceMeters + FlyoverPlan.followDistanceMeters) / 2
        XCTAssertGreaterThan(middle.distanceMeters, linearMiddle)

        let landed = plan.state(at: orbit.upperBound - 1e-9)
        XCTAssertEqual(landed.pitchDegrees, FlyoverPlan.followPitchDegrees, accuracy: 1e-6)
        XCTAssertEqual(landed.distanceMeters, FlyoverPlan.followDistanceMeters, accuracy: 1e-3)
        XCTAssertEqual(landed.centerLongitude, 0, accuracy: 1e-7)
        XCTAssertEqual(landed.headingDegrees, 90, accuracy: 0.01)
        XCTAssertEqual(landed.routeProgress, 0)
    }

    func testHeadingAlwaysStaysInCompassRange() {
        let plan = FlyoverPlan(timeline: eastboundTimeline(), clipSeconds: 30)
        var time = 0.0
        while time <= 30 {
            let heading = plan.state(at: time).headingDegrees
            XCTAssertGreaterThanOrEqual(heading, 0)
            XCTAssertLessThan(heading, 360)
            time += 0.25
        }
    }

    func testFollowMovesAlongTheRouteAndRevealsTheTrail() {
        let plan = FlyoverPlan(timeline: eastboundTimeline(), clipSeconds: 30)
        let follow = plan.range(of: .follow)
        let half = plan.state(at: (follow.lowerBound + follow.upperBound) / 2)
        XCTAssertEqual(half.phase, .follow)
        XCTAssertEqual(half.routeProgress, 0.5, accuracy: 1e-9)
        XCTAssertEqual(half.routeElapsedSeconds, 45, accuracy: 1e-6)
        XCTAssertEqual(half.centerLongitude, 0.0045, accuracy: 1e-6)
        XCTAssertEqual(half.headingDegrees, 90, accuracy: 0.01)
        XCTAssertEqual(half.pitchDegrees, FlyoverPlan.followPitchDegrees)
        let early = plan.state(at: follow.lowerBound + 1)
        let late = plan.state(at: follow.upperBound - 1)
        XCTAssertLessThan(early.centerLongitude, half.centerLongitude)
        XCTAssertLessThan(half.centerLongitude, late.centerLongitude)
    }

    func testFinishPullsBackToTheWholeRouteWithTheFullTrail() {
        let plan = FlyoverPlan(timeline: eastboundTimeline(), clipSeconds: 30)
        let end = plan.state(at: 30)
        XCTAssertEqual(end.phase, .finish)
        XCTAssertEqual(end.pitchDegrees, 0, accuracy: 1e-9)
        XCTAssertEqual(end.distanceMeters, plan.overviewDistanceMeters, accuracy: 1e-6)
        XCTAssertEqual(end.centerLongitude, 0.0045, accuracy: 1e-9)
        XCTAssertEqual(end.routeProgress, 1)
        XCTAssertEqual(end.routeElapsedSeconds, 90, accuracy: 1e-9)
        XCTAssertEqual(end.headingDegrees, 0, accuracy: 1e-6)
    }

    func testTimeOutsideTheClipIsClamped() {
        let plan = FlyoverPlan(timeline: eastboundTimeline(), clipSeconds: 30)
        XCTAssertEqual(plan.state(at: -5), plan.state(at: 0))
        XCTAssertEqual(plan.state(at: 99), plan.state(at: 30))
        XCTAssertEqual(plan.state(at: .nan), plan.state(at: 0))
    }

    func testTinyRouteStillGetsAMinimumOverviewDistance() {
        let points = [0.0, 10].map {
            ReplayPoint(timestamp: origin.addingTimeInterval($0), latitude: 0, longitude: $0 * 0.000001)
        }
        let plan = FlyoverPlan(timeline: ReplayTimeline(points: points, startedAt: origin, endedAt: nil), clipSeconds: 30)
        XCTAssertEqual(plan.overviewDistanceMeters, 1_500)
    }

    func testRouteWithoutMovementIsNotUsable() {
        let single = ReplayTimeline(points: [ReplayPoint(timestamp: origin, latitude: 0, longitude: 0)], startedAt: origin, endedAt: nil)
        XCTAssertFalse(FlyoverPlan(timeline: single, clipSeconds: 30).isUsable)
        let empty = ReplayTimeline(points: [], startedAt: origin, endedAt: nil)
        XCTAssertFalse(FlyoverPlan(timeline: empty, clipSeconds: 30).isUsable)
    }

    func testGpsGapKeepsTheCameraOnTheLastKnownPosition() {
        let times: [Double] = [0, 10, 20, 100, 110, 120]
        let points = times.enumerated().map {
            ReplayPoint(timestamp: origin.addingTimeInterval($0.element), latitude: 0, longitude: Double($0.offset) * 0.001)
        }
        let timeline = ReplayTimeline(points: points, startedAt: origin, endedAt: nil)
        XCTAssertNil(timeline.sample(at: 60).position)
        let found = FlyoverPlan.position(timeline: timeline, progress: 0.5)
        XCTAssertNotNil(found)
        XCTAssertLessThanOrEqual(found!.longitude, 0.002 + 1e-9)
    }

    func testBearingAndAngleHelpers() {
        let origin = ReplayCoordinate(latitude: 0, longitude: 0)
        XCTAssertEqual(FlyoverPlan.bearing(from: origin, to: ReplayCoordinate(latitude: 1, longitude: 0)) ?? -1, 0, accuracy: 1e-6)
        XCTAssertEqual(FlyoverPlan.bearing(from: origin, to: ReplayCoordinate(latitude: 0, longitude: 1)) ?? -1, 90, accuracy: 1e-6)
        XCTAssertEqual(FlyoverPlan.bearing(from: origin, to: ReplayCoordinate(latitude: -1, longitude: 0)) ?? -1, 180, accuracy: 1e-6)
        XCTAssertEqual(FlyoverPlan.bearing(from: origin, to: ReplayCoordinate(latitude: 0, longitude: -1)) ?? -1, 270, accuracy: 1e-6)
        XCTAssertNil(FlyoverPlan.bearing(from: origin, to: origin))
        // Across the antimeridian the short way is still east.
        XCTAssertEqual(FlyoverPlan.bearing(from: ReplayCoordinate(latitude: 0, longitude: 179.9),
                                           to: ReplayCoordinate(latitude: 0, longitude: -179.9)) ?? -1, 90, accuracy: 1e-6)
        XCTAssertEqual(FlyoverPlan.normalized(-90), 270)
        XCTAssertEqual(FlyoverPlan.normalized(450), 90)
        XCTAssertEqual(FlyoverPlan.shortestDelta(from: 350, to: 10), 20, accuracy: 1e-9)
        XCTAssertEqual(FlyoverPlan.shortestDelta(from: 10, to: 350), -20, accuracy: 1e-9)
        XCTAssertEqual(FlyoverPlan.smooth(0), 0)
        XCTAssertEqual(FlyoverPlan.smooth(1), 1)
        XCTAssertEqual(FlyoverPlan.smooth(0.5), 0.5, accuracy: 1e-9)
    }

    /// 40 points heading east but zig-zagging up and down, so raw bearings alternate about 55 / 125 degrees.
    private func zigzagTimeline() -> ReplayTimeline {
        let points = (0..<40).map {
            ReplayPoint(timestamp: origin.addingTimeInterval(Double($0) * 5), latitude: $0 % 2 == 0 ? 0 : 0.0007, longitude: Double($0) * 0.001)
        }
        return ReplayTimeline(points: points, startedAt: origin, endedAt: nil)
    }

    func testSmoothedHeadingIgnoresGpsZigzag() {
        let timeline = zigzagTimeline()
        for step in 0...20 {
            let heading = FlyoverPlan.smoothedHeading(timeline: timeline, progress: Double(step) / 20)
            XCTAssertEqual(heading, 90, accuracy: 30)
        }
    }

    func testCameraHeadingChangesGraduallyThroughTheFollowPhase() {
        let plan = FlyoverPlan(timeline: zigzagTimeline(), clipSeconds: 30)
        let follow = plan.range(of: .follow)
        var previous = plan.state(at: follow.lowerBound).headingDegrees
        var time = follow.lowerBound
        while time < follow.upperBound {
            time += 0.1
            let heading = plan.state(at: min(time, follow.upperBound - 1e-9)).headingDegrees
            XCTAssertLessThan(abs(FlyoverPlan.shortestDelta(from: previous, to: heading)), 12)
            previous = heading
        }
    }

    func testSmoothedHeadingOnAStraightRouteMatchesItsBearing() {
        XCTAssertEqual(FlyoverPlan.smoothedHeading(timeline: eastboundTimeline(), progress: 0.5), 90, accuracy: 0.01)
        let empty = ReplayTimeline(points: [], startedAt: origin, endedAt: nil)
        XCTAssertEqual(FlyoverPlan.smoothedHeading(timeline: empty, progress: 0.5), 0)
    }

    /// Ten points heading due north, 10 s apart: about 1 km tall.
    private func northboundTimeline() -> ReplayTimeline {
        let points = (0..<10).map {
            ReplayPoint(timestamp: origin.addingTimeInterval(Double($0) * 10), latitude: Double($0) * 0.001, longitude: 0)
        }
        return ReplayTimeline(points: points, startedAt: origin, endedAt: nil)
    }

    func testOrbitIsAQuarterTurnNotAFullCircle() {
        let plan = FlyoverPlan(timeline: eastboundTimeline(), clipSeconds: 30)
        let orbit = plan.range(of: .orbit)
        let opening = plan.state(at: 0).headingDegrees
        XCTAssertEqual(opening, 0, accuracy: 0.01)
        let begin = plan.state(at: orbit.lowerBound + 1e-9).headingDegrees
        let middle = plan.state(at: (orbit.lowerBound + orbit.upperBound) / 2).headingDegrees
        let end = plan.state(at: orbit.upperBound - 1e-9).headingDegrees
        XCTAssertEqual(begin, 0, accuracy: 0.01)
        XCTAssertEqual(middle, 45, accuracy: 0.01)
        XCTAssertEqual(end, 90, accuracy: 0.01)
        var time = orbit.lowerBound
        var previous = begin
        while time < orbit.upperBound - 0.05 {
            time += 0.05
            let heading = plan.state(at: time).headingDegrees
            XCTAssertGreaterThanOrEqual(heading, previous - 1e-9)
            XCTAssertLessThanOrEqual(heading, 90 + 1e-6)
            previous = heading
        }
    }

    func testOpeningHeadingIsNinetyDegreesBeforeTheFirstStep() {
        let plan = FlyoverPlan(timeline: northboundTimeline(), clipSeconds: 30)
        XCTAssertEqual(plan.state(at: 0).headingDegrees, 270, accuracy: 0.01)
        let orbit = plan.range(of: .orbit)
        let landed = plan.state(at: orbit.upperBound - 1e-9).headingDegrees
        XCTAssertEqual(FlyoverPlan.shortestDelta(from: landed, to: 0), 0, accuracy: 0.01)
    }

    func testOverviewFitsTheWholeRouteAcrossTheScreenWidth() {
        // East-west route about 1002 m long, camera looking north: the route runs across the narrow screen width.
        let east = FlyoverPlan(timeline: eastboundTimeline(), clipSeconds: 30)
        XCTAssertGreaterThanOrEqual(east.overviewDistanceMeters, 1_000 * FlyoverPlan.metersOfDistancePerMeterOfWidth)
        // North-south route: the opening turns the camera so it also runs across the width, never along the height.
        let north = FlyoverPlan(timeline: northboundTimeline(), clipSeconds: 30)
        XCTAssertGreaterThanOrEqual(north.overviewDistanceMeters, 1_000 * FlyoverPlan.metersOfDistancePerMeterOfWidth)
    }

    func testOverviewFitCentresARotatedRoute() {
        let line = [ReplayCoordinate(latitude: 0, longitude: 0), ReplayCoordinate(latitude: 0.01, longitude: 0)]
        let fit = FlyoverPlan.overviewFit(points: line, headingDegrees: 270)
        XCTAssertEqual(fit.center.latitude, 0.005, accuracy: 1e-6)
        XCTAssertEqual(fit.center.longitude, 0, accuracy: 1e-6)
        XCTAssertEqual(fit.distance, 0.01 * 111_320 * FlyoverPlan.metersOfDistancePerMeterOfWidth, accuracy: 1)
    }

    func testMarkerDropsDuringTheOrbitAndStaysLanded() {
        let plan = FlyoverPlan(timeline: eastboundTimeline(), clipSeconds: 30)
        XCTAssertEqual(plan.state(at: 0).markerDrop, 1)
        let orbit = plan.range(of: .orbit)
        XCTAssertEqual(plan.state(at: orbit.lowerBound + 1e-6).markerDrop, 1, accuracy: 1e-3)
        XCTAssertEqual(plan.state(at: orbit.upperBound - 1e-9).markerDrop, 0, accuracy: 1e-3)
        XCTAssertEqual(plan.state(at: plan.range(of: .follow).lowerBound + 1).markerDrop, 0)
        XCTAssertEqual(plan.state(at: plan.range(of: .finish).lowerBound + 0.5).markerDrop, 0)
        for step in 0...100 {
            let drop = plan.state(at: orbit.lowerBound + (orbit.upperBound - orbit.lowerBound) * Double(step) / 100).markerDrop
            XCTAssertGreaterThanOrEqual(drop, -1e-9)
            XCTAssertLessThanOrEqual(drop, 1 + 1e-9)
        }
    }

    func testBounceOutEndpoints() {
        XCTAssertEqual(FlyoverPlan.bounceOut(0), 0, accuracy: 1e-9)
        XCTAssertEqual(FlyoverPlan.bounceOut(1), 1, accuracy: 1e-9)
        XCTAssertGreaterThan(FlyoverPlan.bounceOut(0.5), 0.5)
    }
}
