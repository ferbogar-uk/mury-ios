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

    private func pixel(_ image: UIImage, x: Int, y: Int) throws -> [UInt8] {
        let source = try XCTUnwrap(image.cgImage)
        let crop = try XCTUnwrap(source.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return bytes
    }
}
