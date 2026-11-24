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
    /// Where the athlete is at this moment (nil: no marker), and the sport's SF Symbol for it.
    var marker: CLLocationCoordinate2D?
    var markerSymbolName: String = "figure.run"
    /// The latest map loading error Mapbox reported (missing tiles, token or style problems), shown under the map.
    @Binding var loadingError: String?

    func makeUIView(context: Context) -> MapView {
        MapboxOptions.accessToken = MapboxConfig.accessToken
        let options = MapInitOptions(styleURI: StyleURI(rawValue: style.rawValue))
        let mapView = MapView(frame: .zero, mapInitOptions: options)
        mapView.isUserInteractionEnabled = false
        // Build 52: Mapbox answered the satellite flyover with HTTP 429 (too many tile requests per minute on the
        // free plan). Not loading tiles ahead of the camera and not tilting to the horizon cuts the requests a lot.
        mapView.mapboxMap.prefetchZoomDelta = 0
        let manager = mapView.annotations.makePolylineAnnotationManager()
        var line = PolylineAnnotation(lineCoordinates: route)
        line.lineColor = StyleColor(UIColor(red: 178 / 255, green: 14 / 255, blue: 28 / 255, alpha: 1))
        line.lineWidth = 5
        manager.annotations = [line]
        context.coordinator.manager = manager
        context.coordinator.markerManager = mapView.annotations.makePointAnnotationManager()
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
            zoom: zoom, bearing: state.headingDegrees,
            pitch: min(state.pitchDegrees, MapboxFlyoverMap.maxPitch(for: style))))
        context.coordinator.updateMarker(marker, symbolName: markerSymbolName)
    }

    /// Satellite tiles are raster and the plan's 72 degree tilt shows many of them near the horizon: 60 keeps them manageable.
    static func maxPitch(for style: Style) -> Double { style == .satellite ? 60 : 85 }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var manager: PolylineAnnotationManager?
        var errorWatcher: AnyCancelable?
        var markerManager: PointAnnotationManager?
        private var markerImageName: String?
        private var markerImage: UIImage?

        /// A red disc with the sport symbol in white. Moves with the athlete; removed when `coordinate` is nil.
        func updateMarker(_ coordinate: CLLocationCoordinate2D?, symbolName: String) {
            guard let markerManager else { return }
            guard let coordinate else { markerManager.annotations = []; return }
            if markerImageName != symbolName || markerImage == nil {
                markerImage = Coordinator.markerImage(symbolName: symbolName)
                markerImageName = symbolName
            }
            guard let markerImage else { return }
            var point = PointAnnotation(coordinate: coordinate)
            point.image = .init(image: markerImage, name: "marker-\(symbolName)")
            point.iconAnchor = .center
            markerManager.annotations = [point]
        }

        static func markerImage(symbolName: String) -> UIImage? {
            let size = CGSize(width: 40, height: 40)
            let glyph = SportIcon.uiImage(named: symbolName, pointSize: 20, weight: .bold)?.withTintColor(.white, renderingMode: .alwaysOriginal)
            return UIGraphicsImageRenderer(size: size).image { _ in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
                UIColor(red: 178 / 255, green: 14 / 255, blue: 28 / 255, alpha: 1).setFill()
                UIBezierPath(ovalIn: rect).fill()
                if let glyph {
                    glyph.draw(in: CGRect(x: (size.width - glyph.size.width) / 2, y: (size.height - glyph.size.height) / 2,
                                          width: glyph.size.width, height: glyph.size.height))
                }
            }
        }
    }
}
