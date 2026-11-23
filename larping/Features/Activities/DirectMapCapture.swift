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

    /// How long the first frames may wait for the map to finish drawing before they are copied as they are.
    static let firstFrameWaitSeconds: Double = 3
    /// Later frames wait this long for the map's "finished" report (0.7 s up to build 45: if the map never reports
    /// "finished" on this phone, 3 s a frame made a 30 s clip take close to an hour and looked like a hang, build 39).
    static let frameWaitSeconds: Double = 0.25
    /// After that wait the map is sampled small, again after `settleStepSeconds`; while it still changes (3D tiles
    /// arriving) the render waits another step, at most `maxSettleRounds` times (build 46).
    static let settleStepSeconds: Double = 0.2
    static let maxSettleRounds = 4
    private var framesCaptured = 0
    /// Camera of the frame just captured; `project` uses it to drop points that are behind the camera or past the horizon.
    private var capturedCenter = CLLocationCoordinate2D()
    private var capturedDistance: CLLocationDistance = 1000

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

    /// Points the map at a frame's camera without waiting or copying, so `project` answers for that frame.
    func moveCamera(state: FlyoverPlan.State, reduceMotion: Bool) {
        let camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: state.centerLatitude, longitude: state.centerLongitude),
            fromDistance: state.distanceMeters,
            pitch: reduceMotion ? 0 : state.pitchDegrees,
            heading: reduceMotion ? 0 : state.headingDegrees)
        capturedCenter = camera.centerCoordinate
        capturedDistance = state.distanceMeters
        mapView.setCamera(camera, animated: false)
    }

    /// Moves the map to the frame's camera, waits for it to draw (bounded, and until it stops changing), and copies it.
    func capture(state: FlyoverPlan.State, reduceMotion: Bool) async -> UIImage {
        frameToken += 1
        let token = frameToken
        let wait = framesCaptured < 3 ? Self.firstFrameWaitSeconds : Self.frameWaitSeconds
        framesCaptured += 1
        await withCheckedContinuation { continuation in
            rendered?.resume()
            rendered = continuation
            moveCamera(state: state, reduceMotion: reduceMotion)
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(wait))
                guard let self, self.frameToken == token else { return }
                self.finishWaiting()
            }
        }
        // 3D tiles often arrive after the map's own "finished" report; wait while a small sample still changes.
        var previous = smallSample()
        for _ in 0..<Self.maxSettleRounds {
            try? await Task.sleep(for: .seconds(Self.settleStepSeconds))
            let current = smallSample()
            let settled = MapFrameSchedule.isSettled(difference: MapFrameSchedule.meanDifference(previous, current))
            previous = current
            if settled { break }
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = FlyoverRenderer.scale
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: mapView.bounds, format: format).image { _ in
            _ = mapView.drawHierarchy(in: mapView.bounds, afterScreenUpdates: true)
        }
    }

    private static let sampleWidth = 36
    private static let sampleHeight = 64

    /// A 36 x 64 copy of the map as RGBA bytes, cheap enough to compare twice per frame.
    private func smallSample() -> [UInt8] {
        let width = Self.sampleWidth, height = Self.sampleHeight
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { _ in
            _ = mapView.drawHierarchy(in: CGRect(x: 0, y: 0, width: width, height: height), afterScreenUpdates: true)
        }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let cg = image.cgImage,
              let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return pixels }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    /// An even mix of two copies, for the frame halfway between them.
    static func halfway(_ first: UIImage, _ second: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = first.scale
        format.opaque = true
        let bounds = CGRect(origin: .zero, size: first.size)
        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { _ in
            first.draw(in: bounds)
            second.draw(in: bounds, blendMode: .normal, alpha: 0.5)
        }
    }

    /// Where a coordinate sits on the frame just captured, in the same points as the copied picture. Uses the map
    /// view's own projection (real field of view and tilt), so the route lands where the map shows it. Nil when the
    /// point is far behind the camera or past the horizon, where the projection is meaningless.
    func project(latitude: Double, longitude: Double) -> CGPoint? {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        let reach = max(capturedDistance * 6, 3000)
        guard MKMapPoint(coordinate).distance(to: MKMapPoint(capturedCenter)) <= reach else { return nil }
        let point = mapView.convert(coordinate, toPointTo: mapView)
        guard point.x.isFinite, point.y.isFinite, abs(point.x) < 6000, abs(point.y) < 6000 else { return nil }
        return point
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
