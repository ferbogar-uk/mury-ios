import XCTest
@testable import larping

final class MapFrameScheduleTests: XCTestCase {
    func testEvenFramesAndTheLastAreKeyframes() {
        XCTAssertTrue(MapFrameSchedule.isKeyframe(index: 0, count: 6))
        XCTAssertFalse(MapFrameSchedule.isKeyframe(index: 1, count: 6))
        XCTAssertTrue(MapFrameSchedule.isKeyframe(index: 4, count: 6))
        XCTAssertTrue(MapFrameSchedule.isKeyframe(index: 5, count: 6), "the last frame is always copied")
        XCTAssertFalse(MapFrameSchedule.isKeyframe(index: 3, count: 6))
    }

    func testEveryNonKeyframeHasANextFrame() {
        for count in 2...40 {
            for index in 0..<count where !MapFrameSchedule.isKeyframe(index: index, count: count) {
                XCTAssertLessThan(index + 1, count)
                XCTAssertTrue(MapFrameSchedule.isKeyframe(index: index + 1, count: count))
            }
        }
    }

    func testHalfTheFramesAreCopied() {
        let copied = (0..<600).filter { MapFrameSchedule.isKeyframe(index: $0, count: 600) }.count
        XCTAssertEqual(copied, 301, "300 even frames plus the last odd one")
    }

    func testMeanDifference() {
        XCTAssertEqual(MapFrameSchedule.meanDifference([0, 0, 0, 0], [0, 0, 0, 0]), 0)
        XCTAssertEqual(MapFrameSchedule.meanDifference([0, 0], [255, 255]), 1)
        XCTAssertEqual(MapFrameSchedule.meanDifference([0, 100], [0, 100]), 0)
        XCTAssertEqual(MapFrameSchedule.meanDifference([1], [1, 2]), 1, "different sizes never count as settled")
    }

    func testSettledThreshold() {
        XCTAssertTrue(MapFrameSchedule.isSettled(difference: 0.002))
        XCTAssertFalse(MapFrameSchedule.isSettled(difference: 0.05))
    }
}
