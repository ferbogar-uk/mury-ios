import Foundation

/// Perspective projection of a map coordinate onto the picture of a camera described the way `MKMapCamera` is:
/// looking at `center` from `distanceMeters` away, turned to `headingDegrees` and tilted `pitchDegrees` from
/// straight down. Used to draw the route on rendered flyover frames, because `MKMapSnapshotter.Snapshot.point(for:)`
/// placed the route at random spots on tilted frames (build 9 device test).
///
/// The vertical field of view is an assumption (about 30 degrees, what Apple Maps appears to use); if the route
/// sits consistently too close to or too far from the camera centre on a device, this one number is the thing to fix.
/// The ground is treated as flat and at sea level.
enum FlyoverProjection {
    static let verticalFieldOfViewDegrees = 30.0

    struct Camera {
        var centerLatitude: Double
        var centerLongitude: Double
        var distanceMeters: Double
        var headingDegrees: Double
        var pitchDegrees: Double
    }

    /// Picture position in points (x to the right, y downward), or nil when the point is behind the camera.
    static func project(latitude: Double, longitude: Double, camera: Camera, width: Double, height: Double) -> (x: Double, y: Double)? {
        guard width > 0, height > 0, camera.distanceMeters > 0 else { return nil }
        let metersPerDegreeLatitude = 111_132.0
        let metersPerDegreeLongitude = 111_320.0 * cos(camera.centerLatitude * .pi / 180)
        let east = (longitude - camera.centerLongitude) * metersPerDegreeLongitude
        let north = (latitude - camera.centerLatitude) * metersPerDegreeLatitude

        let heading = camera.headingDegrees * .pi / 180
        let pitch = min(max(camera.pitchDegrees, 0), 89.9) * .pi / 180
        let distance = camera.distanceMeters

        // Camera position relative to the look-at point (east, north, up).
        let cameraEast = -distance * sin(pitch) * sin(heading)
        let cameraNorth = -distance * sin(pitch) * cos(heading)
        let cameraUp = distance * cos(pitch)
        // Forward, right and up axes of the camera.
        let forward = (x: sin(pitch) * sin(heading), y: sin(pitch) * cos(heading), z: -cos(pitch))
        let right = (x: cos(heading), y: -sin(heading), z: 0.0)
        let up = (x: right.y * forward.z, y: -right.x * forward.z, z: right.x * forward.y - right.y * forward.x)

        let vx = east - cameraEast
        let vy = north - cameraNorth
        let vz = 0 - cameraUp
        let depth = vx * forward.x + vy * forward.y + vz * forward.z
        guard depth > 1 else { return nil }
        let sideways = vx * right.x + vy * right.y + vz * right.z
        let upwards = vx * up.x + vy * up.y + vz * up.z
        let focal = (height / 2) / tan(verticalFieldOfViewDegrees * .pi / 360)
        return (width / 2 + focal * sideways / depth, height / 2 - focal * upwards / depth)
    }
}
