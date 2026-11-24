import MapboxMaps
import SwiftUI
import UIKit

/// Mapbox's side of the comparison (test only, see MapTestView). Wraps Mapbox's UIKit `MapView`.
struct MapboxFlyoverMap: UIViewRepresentable {
    enum Style: String {
        case standard = "mapbox://styles/mapbox/standard"
        case satellite = "mapbox://styles/mapbox/satellite-streets-v12"
    }

    let style: Style
    let route: [CLLocationCoordinate2D]
    let state: FlyoverPlan.State
    /// The latest map loading error Mapbox reported (missing tiles, token or style problems), shown under the map.
    @Binding var loadingError: String?

    func makeUIView(context: Context) -> MapView {
        MapboxOptions.accessToken = MapboxConfig.accessToken
        let options = MapInitOptions(styleURI: StyleURI(rawValue: style.rawValue))
        let mapView = MapView(frame: .zero, mapInitOptions: options)
        mapView.isUserInteractionEnabled = false
        let manager = mapView.annotations.makePolylineAnnotationManager()
        var line = PolylineAnnotation(lineCoordinates: route)
        line.lineColor = StyleColor(UIColor(red: 178 / 255, green: 14 / 255, blue: 28 / 255, alpha: 1))
        line.lineWidth = 5
        manager.annotations = [line]
        context.coordinator.manager = manager
        let errorBinding = $loadingError
        context.coordinator.errorWatcher = mapView.mapboxMap.onMapLoadingError.observe { error in
            let text = "\(error.type): \(error.message)"
            DispatchQueue.main.async { errorBinding.wrappedValue = text }
        }
        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        let zoom = MapboxCameraMath.zoom(forDistanceMeters: state.distanceMeters, latitude: state.centerLatitude,
                                         viewHeightPoints: mapView.bounds.height > 0 ? Double(mapView.bounds.height) : 600)
        mapView.mapboxMap.setCamera(to: CameraOptions(
            center: CLLocationCoordinate2D(latitude: state.centerLatitude, longitude: state.centerLongitude),
            zoom: zoom, bearing: state.headingDegrees, pitch: state.pitchDegrees))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var manager: PolylineAnnotationManager?
        var errorWatcher: AnyCancelable?
    }
}
