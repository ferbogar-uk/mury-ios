import MapKit
import SwiftUI

/// The new Render in app (build 39): one real Apple 3D map view, kept on screen under the render cover,
/// is moved to each frame's camera and copied straight into the video. No screen recording (so no
/// permission prompt) and no new map snapshot per frame (each snapshot kept memory the engine never gave back).
@MainActor
final class DirectMapCapture: NSObject, MKMapViewDelegate {
    let mapView: MKMapView
    private var rendered: CheckedContinuation<Void, Never>?
    /// Counts frames, so a late timeout from one frame can never end the wait for the next.
    private var frameToken = 0

    /// How long one frame may wait for the map to finish drawing before it is copied as it is.
    static let frameWaitSeconds: Double = 3

    init(size: CGSize) {
        mapView = MKMapView(frame: CGRect(origin: .zero, size: size))
        super.init()
        let configuration = MKHybridMapConfiguration(elevationStyle: .realistic)
        configuration.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = configuration
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isUserInteractionEnabled = false
        mapView.delegate = self
    }

    /// True once the map view sits in a window; it does not draw before that.
    var isOnScreen: Bool { mapView.window != nil }

    /// Moves the map to the frame's camera, waits for it to draw (bounded), and copies it.
    func capture(state: FlyoverPlan.State, reduceMotion: Bool) async -> UIImage {
        let camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: state.centerLatitude, longitude: state.centerLongitude),
            fromDistance: state.distanceMeters,
            pitch: reduceMotion ? 0 : state.pitchDegrees,
            heading: reduceMotion ? 0 : state.headingDegrees)
        frameToken += 1
        let token = frameToken
        await withCheckedContinuation { continuation in
            rendered?.resume()
            rendered = continuation
            mapView.setCamera(camera, animated: false)
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.frameWaitSeconds))
                guard let self, self.frameToken == token else { return }
                self.finishWaiting()
            }
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = FlyoverRenderer.scale
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: mapView.bounds, format: format).image { _ in
            _ = mapView.drawHierarchy(in: mapView.bounds, afterScreenUpdates: true)
        }
    }

    private func finishWaiting() {
        rendered?.resume()
        rendered = nil
    }

    nonisolated func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
        guard fullyRendered else { return }
        MainActor.assumeIsolated { finishWaiting() }
    }

    /// The known risk of copying Apple's 3D map: on some phones the copy comes out black.
    /// Looks at a grid of pixels; true when nearly all are close to black.
    static func looksBlack(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return true }
        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return true }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        var dark = 0
        var offset = 0
        while offset < pixels.count {
            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            let blue = Int(pixels[offset + 2])
            if red + green + blue < 30 { dark += 1 }
            offset += 4
        }
        let threshold = side * side * 95 / 100
        return dark > threshold
    }
}

/// Puts the capture's map view on screen (it has to be in a window to draw). The render cover sits on top.
struct DirectMapHost: UIViewRepresentable {
    let capture: DirectMapCapture
    func makeUIView(context: Context) -> MKMapView { capture.mapView }
    func updateUIView(_ uiView: MKMapView, context: Context) {}
}
