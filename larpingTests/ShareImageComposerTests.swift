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
            (.pink, .light, [255, 79, 152]), (.pink, .dark, [255, 126, 185]),
            (.tiffany, .light, [0, 194, 204]), (.tiffany, .dark, [52, 217, 226]),
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

    func testMapFallbackIsOpaqueWithoutNetworkOrRoute() throws {
        for theme in BrandTheme.allCases {
            let image = ShareImageComposer(style: theme.shareStyle(for: .dark)).composeMapCard(snapshot: nil, coordinates: [], stats: stats)
            XCTAssertEqual(image.size, CGSize(width: 1080, height: 1920))
            XCTAssertEqual(try pixel(image, x: 0, y: 0)[3], 255)
        }
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
