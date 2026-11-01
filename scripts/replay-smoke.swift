import Foundation

@main
struct ReplaySmoke {
    static func main() {
        let start = Date(timeIntervalSince1970: 1000)
        func p(_ t: Double, _ lon: Double = 0, _ altitude: Double? = nil, _ speed: Double? = nil) -> ReplayPoint {
            ReplayPoint(timestamp: start.addingTimeInterval(t), latitude: 0, longitude: lon, altitudeMeters: altitude, speedMps: speed)
        }
        func timeline(_ points: [ReplayPoint], _ end: Double? = nil) -> ReplayTimeline {
            ReplayTimeline(points: points, startedAt: start, endedAt: end.map { start.addingTimeInterval($0) })
        }
        let route = timeline([p(10, 0.001), p(0, 0, 10, 2), p(2, 0.0002, 20, 4)])
        assert(route.duration == 10)
        assert(abs(route.sample(at: 1).position!.longitude - 0.0001) < 0.0000001)
        assert(route.sample(at: 1).altitudeMeters == 15)
        assert(route.sample(at: 1).speedMps == 3)
        assert(route.sample(at: 5).altitudeMeters == nil)
        assert(route.sample(at: 1).headingDegrees == 90)
        assert(timeline([p(0), p(0, 1), p(2, 0.0002)]).segments[0][0].longitude == 0)
        let invalid = ReplayPoint(timestamp: start, latitude: .nan, longitude: 0)
        let badTime = ReplayPoint(timestamp: Date(timeIntervalSince1970: .nan), latitude: 0, longitude: 0)
        let cleaned = timeline([invalid, badTime, p(-1), p(0, 0, .infinity, -1), p(2, 0.0002), p(5)], 3)
        assert(cleaned.duration == 3 && cleaned.segments.flatMap { $0 }.count == 2)
        assert(cleaned.sample(at: 0).altitudeMeters == nil && cleaned.sample(at: 0).speedMps == nil)
        assert(timeline([]).duration == 0 && timeline([]).sample(at: 0).position == nil)
        assert(timeline([p(5)], 20).duration == 0)
        assert(route.sample(at: -1).elapsedSeconds == 0)
        assert(route.sample(at: 99).elapsedSeconds == 10)
        assert(route.sample(at: .nan).elapsedSeconds == 0)
        assert(route.sample(at: .infinity).elapsedSeconds == 0)
        let gap = timeline([p(0), p(2, 0.0002), p(40, 0.0004), p(42, 0.0006)])
        assert(gap.segments.count == 2)
        assert(gap.sample(at: 30).position == nil)
        assert(gap.sample(at: 41).revealedSegments.count == 2)
        assert(gap.sample(at: 1).revealedSegments.count == 1)
        assert(timeline([p(0), p(2, 1)]).segments.count == 2)
        let missingTail = timeline([p(0), p(2, 0.0002)], 10)
        assert(missingTail.sample(at: 2).position != nil)
        assert(missingTail.sample(at: 9).position == nil && missingTail.sample(at: 9).speedMps == nil)
        let crossing = timeline([p(0, 179.9999), p(2, -179.9999)])
        assert(crossing.segments.count == 1)
        assert(abs(abs(crossing.sample(at: 1).position!.longitude) - 180) < 0.000001)
        assert(abs(crossing.sample(at: 1).headingDegrees! - 90) < 0.00001)
        var playback = ReplayPlayback(duration: 10)
        playback.play(); playback.advance(by: 1); assert(playback.elapsedSeconds == 1)
        playback.pause(); playback.advance(by: 1); assert(playback.elapsedSeconds == 1)
        playback.seek(to: -1); assert(playback.elapsedSeconds == 0)
        playback.seek(to: .nan); assert(playback.elapsedSeconds == 0)
        playback.setSpeed(3); assert(playback.speed == 1)
        playback.setSpeed(4); playback.play(); playback.advance(by: -1); playback.advance(by: .infinity)
        assert(playback.elapsedSeconds == 0)
        playback.advance(by: 3); assert(playback.elapsedSeconds == 10 && !playback.isPlaying)
        playback.play(); assert(playback.elapsedSeconds == 0 && playback.isPlaying)
        playback.seek(to: 100); assert(playback.elapsedSeconds == 10 && !playback.isPlaying)
        var empty = ReplayPlayback(duration: 0); empty.play(); assert(!empty.isPlaying)
        print("PASS: replay timeline and playback checks")
    }
}
