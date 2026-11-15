import MapKit
import UIKit

/// Asks MapKit itself where a coordinate lands on a map picture, so the route in a rendered flyover sits exactly
/// where the map shows it. It sets the same camera on a real `MKMapView` (kept behind the render screen, never
/// seen) and converts coordinates with MapKit's own perspective maths, including the clamping MapKit applies to
/// pitch and distance. `FlyoverProjection` (an assumed field of view) stays as the fallback when this cannot be
/// trusted.
@MainActor
final class MapProjector {
    private let mapView: MKMapView
    private let size: CGSize
    private var ready = false

    init(size: CGSize) {
        self.size = size
        mapView = MKMapView(frame: CGRect(origin: .zero, size: size))
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = configuration
        mapView.isUserInteractionEnabled = false
        // In the window (behind everything) so MapKit lays it out like a real, visible map.
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        window?.insertSubview(mapView, at: 0)
    }

    func detach() {
        mapView.removeFromSuperview()
    }

    /// Sets the camera for the frame about to be drawn. Returns false when MapKit does not answer sensibly
    /// (the camera's own centre must land on the middle of the picture), and the caller falls back.
    func prepare(camera: MKMapCamera) -> Bool {
        mapView.setCamera(camera, animated: false)
        mapView.layoutIfNeeded()
        let centre = mapView.convert(camera.centerCoordinate, toPointTo: mapView)
        ready = centre.x.isFinite && centre.y.isFinite
            && abs(centre.x - size.width / 2) < 4 && abs(centre.y - size.height / 2) < 4
        return ready
    }

    /// Picture position in points, or nil when MapKit gives no usable answer.
    func point(latitude: Double, longitude: Double) -> CGPoint? {
        guard ready else { return nil }
        let p = mapView.convert(CLLocationCoordinate2D(latitude: latitude, longitude: longitude), toPointTo: mapView)
        return p.x.isFinite && p.y.isFinite ? p : nil
    }
}
