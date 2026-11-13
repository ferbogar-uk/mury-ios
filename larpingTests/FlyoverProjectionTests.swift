import XCTest
@testable import larping

final class FlyoverProjectionTests: XCTestCase {
    private func camera(heading: Double = 0, pitch: Double = 0, distance: Double = 1000) -> FlyoverProjection.Camera {
        FlyoverProjection.Camera(centerLatitude: 51.5, centerLongitude: -0.1, distanceMeters: distance,
                                 headingDegrees: heading, pitchDegrees: pitch)
    }

    func testCentreProjectsToTheMiddleOfThePictureAtAnyPitchAndHeading() {
        for pitch in [0.0, 30, 60, 75] {
            for heading in [0.0, 90, 200] {
                let p = FlyoverProjection.project(latitude: 51.5, longitude: -0.1, camera: camera(heading: heading, pitch: pitch),
                                                  width: 360, height: 640)
                XCTAssertEqual(p?.x ?? -1, 180, accuracy: 1e-6)
                XCTAssertEqual(p?.y ?? -1, 320, accuracy: 1e-6)
            }
        }
    }

    func testTopDownScaleMatchesTheFieldOfView() {
        // 100 m north of the centre, camera 1000 m above looking straight down, heading north.
        let north = 100.0 / 111_132.0
        let p = FlyoverProjection.project(latitude: 51.5 + north, longitude: -0.1, camera: camera(), width: 360, height: 640)
        let focal = 320 / tan(FlyoverProjection.verticalFieldOfViewDegrees * .pi / 360)
        XCTAssertEqual(p?.x ?? -1, 180, accuracy: 1e-6)
        XCTAssertEqual(p?.y ?? -1, 320 - focal * 0.1, accuracy: 1e-3)
    }

    func testHeadingTurnsTheMap() {
        // Heading east: a point east of the centre is straight "up" on the picture.
        let east = 100.0 / (111_320.0 * cos(51.5 * .pi / 180))
        let p = FlyoverProjection.project(latitude: 51.5, longitude: -0.1 + east, camera: camera(heading: 90), width: 360, height: 640)
        XCTAssertEqual(p?.x ?? -1, 180, accuracy: 1e-3)
        XCTAssertLessThan(p?.y ?? 999, 320)
    }

    func testTiltedCameraSeesAheadAboveCentreAndBehindBelowIt() {
        let step = 200.0 / 111_132.0
        let ahead = FlyoverProjection.project(latitude: 51.5 + step, longitude: -0.1, camera: camera(pitch: 60), width: 360, height: 640)
        let behind = FlyoverProjection.project(latitude: 51.5 - step, longitude: -0.1, camera: camera(pitch: 60), width: 360, height: 640)
        XCTAssertLessThan(ahead?.y ?? 999, 320)
        XCTAssertGreaterThan(behind?.y ?? -1, 320)
        // Perspective: the same ground distance covers fewer pixels further away.
        XCTAssertLessThan(320 - (ahead?.y ?? 0), (behind?.y ?? 0) - 320)
    }

    func testPointsBehindTheCameraAreNotProjected() {
        let farBehind = 5000.0 / 111_132.0
        let p = FlyoverProjection.project(latitude: 51.5 - farBehind, longitude: -0.1, camera: camera(pitch: 80, distance: 500), width: 360, height: 640)
        XCTAssertNil(p)
    }

    func testUnusableSizeOrDistanceGivesNil() {
        XCTAssertNil(FlyoverProjection.project(latitude: 51.5, longitude: -0.1, camera: camera(), width: 0, height: 640))
        XCTAssertNil(FlyoverProjection.project(latitude: 51.5, longitude: -0.1, camera: camera(distance: 0), width: 360, height: 640))
    }
}
