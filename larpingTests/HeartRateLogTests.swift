import XCTest
@testable import larping

final class HeartRateLogTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_793_000_000)

    private func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    private func reading(_ bpm: Double, at seconds: Double) -> HeartRateReading {
        HeartRateReading(beatsPerMinute: bpm, date: at(seconds))!
    }

    private func log(_ readings: [(Double, Double)]) -> HeartRateLog {
        var log = HeartRateLog()
        for (bpm, seconds) in readings { log.add(reading(bpm, at: seconds)) }
        return log
    }

    func testEmptyLogAssignsNothing() {
        let log = HeartRateLog()
        XCTAssertTrue(log.isEmpty)
        XCTAssertEqual(log.assign(toPointsAt: [at(0), at(5)]), [nil, nil])
    }

    func testNoPointsAssignsNothing() {
        XCTAssertEqual(log([(140, 0)]).assign(toPointsAt: []), [])
    }

    func testEachReadingGoesToTheNearestPoint() {
        let result = log([(140, 1), (150, 9)]).assign(toPointsAt: [at(0), at(10)])
        XCTAssertEqual(result, [140, 150])
    }

    func testAPointKeepsTheHighestReadingThatLandedOnIt() {
        let result = log([(140, 1), (170, 2), (150, 3)]).assign(toPointsAt: [at(2)])
        XCTAssertEqual(result, [170])
    }

    func testAReadingFarFromEveryPointIsNotAttached() {
        let result = log([(140, 100)]).assign(toPointsAt: [at(0), at(5)])
        XCTAssertEqual(result, [nil, nil])
    }

    func testTheGapLimitIsInclusive() {
        XCTAssertEqual(log([(140, 10)]).assign(toPointsAt: [at(0)]), [140])
        XCTAssertEqual(log([(140, 10.1)]).assign(toPointsAt: [at(0)]), [nil])
    }

    func testOutOfOrderAndRepeatedReadingsAreDropped() {
        var l = HeartRateLog()
        l.add(reading(140, at: 5))
        l.add(reading(150, at: 5))
        l.add(reading(160, at: 3))
        XCTAssertEqual(l.readings.count, 1)
        XCTAssertEqual(l.readings.first?.beatsPerMinute, 140)
    }

    func testClearEmptiesTheLog() {
        var l = log([(140, 1)])
        l.clear()
        XCTAssertTrue(l.isEmpty)
    }

    func testResultKeepsTheOrderOfThePoints() {
        let result = log([(120, 0), (180, 20)]).assign(toPointsAt: [at(20), at(0)])
        XCTAssertEqual(result, [180, 120])
    }
}