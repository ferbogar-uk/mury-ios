import CoreLocation
import SwiftUI
import UIKit
import XCTest
@testable import larping

@MainActor
final class ShareImageComposerTests: XCTestCase {
    private let stats = ShareImageComposer.Stats(symbolName: "figure.run", sportLabel: "Run", distance: "5.25 km", duration: "0:30:00", paceOrSpeed: "5:30", date: "Jan 1, 2026")
    private let coordinates = [CLLocationCoordinate2D(latitude: 1, longitude: 1), CLLocationCoordinate2D(latitude: 1.001, longitude: 1.001)]

    func testClassicExportKeepsTransparentBackgroundForEveryTheme() throws {
        for theme in BrandTheme.allCases {
            for scheme in [ColorScheme.light, .dark] {
                let composer = ShareImageComposer(style: theme.shareStyle(for: scheme))
                let image = composer.compose(photo: nil, coordinates: coordinates, stats: stats)
                XCTAssertEqual(image.size, CGSize(width: 1080, height: 1920))
                XCTAssertEqual(try pixel(image, x: 0, y: 0)[3], 0)
            }
        }
    }

    func testRouteUsesExplicitPaletteRegardlessOfAmbientAppearance() throws {
        let fixtures: [(BrandTheme, ColorScheme, [Double])] = [
            (.mury, .light, [178, 14, 28]), (.mury, .dark, [178, 14, 28]),
        ]
        for (theme, scheme, expected) in fixtures {
            let composer = ShareImageComposer(style: theme.shareStyle(for: scheme))
            let image = composer.compose(photo: nil, coordinates: coordinates, stats: stats)
            let actual = try pixel(image, x: 540, y: 737)
            XCTAssertGreaterThan(actual[3], 230)
            for channel in 0..<3 {
                XCTAssertEqual(Double(actual[channel]) * 255 / Double(actual[3]), expected[channel], accuracy: 3)
            }
        }
    }

    func testWhiteCasingSeparatesRedRouteFromBackground() throws {
        for scheme in [ColorScheme.light, .dark] {
            let composer = ShareImageComposer(style: BrandTheme.mury.shareStyle(for: scheme))
            let classic = composer.compose(photo: nil, coordinates: coordinates, stats: stats)
            XCTAssertEqual(try pixel(classic, x: 554, y: 737), [255, 255, 255, 255])
            let map = composer.composeMapCard(snapshot: nil, coordinates: coordinates, stats: stats)
            XCTAssertEqual(try pixel(map, x: 554, y: 640), [255, 255, 255, 255])
        }
    }

    func testMapFallbackIsOpaqueWithoutNetworkOrRoute() throws {
        for theme in BrandTheme.allCases {
            let image = ShareImageComposer(style: theme.shareStyle(for: .dark)).composeMapCard(snapshot: nil, coordinates: [], stats: stats)
            XCTAssertEqual(image.size, CGSize(width: 1080, height: 1920))
            XCTAssertEqual(try pixel(image, x: 0, y: 0)[3], 255)
        }
    }

    func testPaceAndSpeedLabelsPreserveTheirUnits() {
        let pace = ShareImageComposer.Stats(symbolName: "figure.run", sportLabel: "Run", distance: "5 km", duration: "0:30:00", paceOrSpeed: "6:00 /km", date: "")
        let speed = ShareImageComposer.Stats(symbolName: "bicycle", sportLabel: "Ride", distance: "20 km", duration: "1:00:00", paceOrSpeed: "20.0 km/h", date: "", usesPaceMetric: false)
        XCTAssertEqual(pace.metricLabel, "PACE")
        XCTAssertEqual(pace.paceOrSpeed, "6:00 /km")
        XCTAssertEqual(speed.metricLabel, "SPEED")
        XCTAssertEqual(speed.paceOrSpeed, "20.0 km/h")
    }

    func testClassicLogoHasNoFilledPlaque() throws {
        let composer = ShareImageComposer(style: BrandTheme.mury.shareStyle(for: .light))
        let image = composer.compose(photo: nil, coordinates: [], stats: stats)
        // Inside the old plaque, outside the actual logo pixels.
        XCTAssertEqual(try pixel(image, x: 540, y: 334)[3], 0)
    }

    func testOverlayLayoutsPreserveAlphaThroughPNGExport() throws {
        let composer = ShareImageComposer(style: BrandTheme.mury.shareStyle(for: .dark))
        let values = [ShareImageComposer.OverlayValue(id: .duration, label: "TIME", value: "30:00")]
        for layout in ShareImageComposer.OverlayLayout.allCases {
            let image = composer.composeOverlay(layout: layout, coordinates: coordinates, stats: stats, metrics: values)
            let png = try ShareExportDocument(image: image)
            let decoded = try XCTUnwrap(UIImage(data: png.data))
            XCTAssertEqual(decoded.size, CGSize(width: 1080, height: 1920))
            XCTAssertEqual(try pixel(decoded, x: 0, y: 0)[3], 0)
            XCTAssertEqual(try pixel(decoded, x: 540, y: 150)[3], 0)
            XCTAssertEqual(try pixel(decoded, x: 70, y: 190)[3], 0)
            XCTAssertGreaterThan(try visiblePixelCount(decoded, rect: CGRect(x: 80, y: 190, width: 920, height: 92)), 1000)
        }
    }

    func testOverlaySupportsNoRouteOrSelectedMetrics() throws {
        let composer = ShareImageComposer(style: BrandTheme.mury.shareStyle(for: .light))
        for layout in ShareImageComposer.OverlayLayout.allCases {
            for route in [[], coordinates] {
                let image = composer.composeOverlay(layout: layout, coordinates: route, stats: stats, metrics: [])
                XCTAssertEqual(try visiblePixelCount(image, rect: CGRect(x: 0, y: 300, width: 1080, height: 1620)), 0)
            }
        }
    }

    func testOverlayMetricsUseOnlyAvailableSavedValuesAndCorrectUnits() {
        let activity = CDActivity()
        XCTAssertTrue(ShareImageComposer.overlayMetrics(for: activity).isEmpty)
        activity.sportType = .run
        activity.distanceMeters = 5000
        activity.durationSeconds = 1800
        activity.elevationGainMeters = 0
        activity.averageSpeedMps = 1000.0 / 360
        let a = CDTrackPoint()
        a.heartRateBpm = 120
        let b = CDTrackPoint()
        b.heartRateBpm = 160
        activity.trackPoints = [a, b]
        let values = ShareImageComposer.overlayMetrics(for: activity)
        XCTAssertEqual(values.map(\.id), [.distance, .duration, .paceOrSpeed, .elevation, .averageHeartRate, .maxHeartRate])
        XCTAssertEqual(values.first(where: { $0.id == .paceOrSpeed })?.label, "PACE")
        XCTAssertEqual(values.first(where: { $0.id == .paceOrSpeed })?.value, "6:00 /km")
        XCTAssertEqual(values.first(where: { $0.id == .elevation })?.value, "0 m")
        XCTAssertEqual(values.first(where: { $0.id == .averageHeartRate })?.value, "140 bpm")
        XCTAssertEqual(values.first(where: { $0.id == .maxHeartRate })?.value, "160 bpm")
        activity.sportType = .ride
        let speed = ShareImageComposer.overlayMetrics(for: activity).first(where: { $0.id == .paceOrSpeed })
        XCTAssertEqual(speed?.label, "SPEED")
        XCTAssertEqual(speed?.value, "10.0 km/h")
        activity.trackPoints = []
        XCTAssertFalse(ShareImageComposer.overlayMetrics(for: activity).contains { $0.id == .averageHeartRate || $0.id == .maxHeartRate })
    }


    func testClassicStacksCenteredBlueSymbolAboveWhiteWordmark() throws {
        let image = ShareImageComposer(style: BrandTheme.mury.shareStyle(for: .dark))
            .compose(photo: nil, coordinates: coordinates, stats: stats)
        let header = CGRect(x: 80, y: 150, width: 920, height: 340)
        let blue = try XCTUnwrap(coloredBounds(image, rect: header, color: [167, 216, 243]))
        let wordmark = try XCTUnwrap(coloredBounds(image, rect: header, color: [255, 255, 255]))
        XCTAssertLessThan(blue.maxY, wordmark.minY, "The blue symbol must sit above the white Mury wordmark")
        XCTAssertEqual(blue.midX, 540, accuracy: 8)
        XCTAssertEqual(wordmark.midX, 540, accuracy: 8)
    }

    func testClassicSportGlyphMovesBelowRouteBeforeStatistics() throws {
        let composer = ShareImageComposer(style: BrandTheme.mury.shareStyle(for: .dark))
        let withoutSport = ShareImageComposer.Stats(symbolName: "", sportLabel: stats.sportLabel,
            distance: stats.distance, duration: stats.duration, paceOrSpeed: stats.paceOrSpeed, date: stats.date)
        let image = composer.compose(photo: nil, coordinates: coordinates, stats: stats)
        let noGlyph = composer.compose(photo: nil, coordinates: coordinates, stats: withoutSport)
        // Route ends at 970 (+12 casing); old statistics start at 1020.
        // Compare glyph-on/off pixels here so old statistic pixels cannot satisfy this check.
        let sportBand = CGRect(x: 430, y: 984, width: 220, height: 36)
        let white = try XCTUnwrap(coloredBounds(image, rect: sportBand, color: [255, 255, 255]),
            "A white sport glyph must begin below the route and above the statistics")
        XCTAssertGreaterThan(white.width, 4)
        XCTAssertNotEqual(try croppedPNG(image, rect: sportBand),
                          try croppedPNG(noGlyph, rect: sportBand))
        let header = CGRect(x: 80, y: 150, width: 920, height: 340)
        XCTAssertEqual(try croppedPNG(image, rect: header),
                       try croppedPNG(noGlyph, rect: header),
                       "The Classic header must contain only the stacked identity, independent of sport")
    }

    func testOverlayMenuKeepsExistingNamesAndAddsReferenceLayouts() {
        XCTAssertEqual(ShareImageComposer.OverlayLayout.allCases.map(\.rawValue),
                       ["Statistics", "Chips", "Route + stats", "Ticket", "Edge", "Receipt"])
        XCTAssertNil(ShareImageComposer.OverlayLayout(rawValue: "Compact"))
    }

    func testEveryExpectedOverlayKeepsLogoOnlyWhenNoMetricsAreSelected() throws {
        let composer = ShareImageComposer(style: BrandTheme.mury.shareStyle(for: .light))
        for name in ["Statistics", "Chips", "Route + stats", "Ticket", "Edge", "Receipt"] {
            guard let layout = ShareImageComposer.OverlayLayout(rawValue: name) else {
                XCTFail("Missing overlay layout: \(name)")
                continue
            }
            for route in [[], coordinates] {
                let image = composer.composeOverlay(layout: layout, coordinates: route, stats: stats, metrics: [])
                XCTAssertGreaterThan(try visiblePixelCount(image, rect: CGRect(x: 80, y: 190, width: 920, height: 92)), 1000, name)
                XCTAssertEqual(try visiblePixelCount(image, rect: CGRect(x: 0, y: 300, width: 1080, height: 1620)), 0, name)
                for corner in [(0, 0), (1079, 0), (0, 1919), (1079, 1919)] {
                    XCTAssertEqual(try pixel(image, x: corner.0, y: corner.1)[3], 0, name)
                }
            }
        }
    }

    private func croppedPNG(_ image: UIImage, rect: CGRect) throws -> Data {
        let crop = try XCTUnwrap(image.cgImage?.cropping(to: rect))
        return try XCTUnwrap(UIImage(cgImage: crop).pngData())
    }

    private func coloredBounds(_ image: UIImage, rect: CGRect, color: [Int]) throws -> CGRect? {
        let source = try XCTUnwrap(image.cgImage?.cropping(to: rect))
        let width = source.width
        let height = source.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        var bounds = CGRect.null
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                guard bytes[offset + 3] > 230 else { continue }
                let alpha = Double(bytes[offset + 3])
                guard (0..<3).allSatisfy({ abs(Double(bytes[offset + $0]) * 255 / alpha - Double(color[$0])) <= 3 }) else { continue }
                bounds = bounds.union(CGRect(x: rect.minX + CGFloat(x), y: rect.minY + CGFloat(y), width: 1, height: 1))
            }
        }
        return bounds.isNull ? nil : bounds
    }

    private func visiblePixelCount(_ image: UIImage, rect: CGRect) throws -> Int {
        let source = try XCTUnwrap(image.cgImage?.cropping(to: rect))
        let width = source.width
        let height = source.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 3, to: bytes.count, by: 4).filter { bytes[$0] > 0 }.count
    }

    private func pixel(_ image: UIImage, x: Int, y: Int) throws -> [UInt8] {
        let source = try XCTUnwrap(image.cgImage)
        let crop = try XCTUnwrap(source.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return bytes
    }
}
