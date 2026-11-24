import Foundation

/// Maps the flyover camera (a distance from the ground, in metres) onto Mapbox's zoom level.
/// A first estimate for the comparison test: flat ground, Mapbox's fixed 36.87 degree vertical field
/// of view, 512 pt tiles. Foundation-only so it is also tested on Linux CI.
enum MapboxCameraMath {
    static let metersPerPointAtZoomZero = 78271.517
    static let verticalFieldOfViewDegrees = 36.87
    static let zoomRange: ClosedRange<Double> = 0...22

    static func zoom(forDistanceMeters distance: Double, latitude: Double, viewHeightPoints: Double) -> Double {
        guard distance > 0, viewHeightPoints > 0 else { return zoomRange.lowerBound }
        let visibleHeight = 2 * distance * tan(verticalFieldOfViewDegrees / 2 * .pi / 180)
        let metersPerPoint = visibleHeight / viewHeightPoints
        let latitudeScale = max(cos(latitude * .pi / 180), 0.01)
        let zoom = log2(metersPerPointAtZoomZero * latitudeScale / metersPerPoint)
        return min(max(zoom, zoomRange.lowerBound), zoomRange.upperBound)
    }
}
