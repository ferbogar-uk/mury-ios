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
        // Beside the stacked identity, inside the former plaque footprint.
        XCTAssertEqual(try pixel(image, x: 360, y: 334)[3], 0)
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
            let identityRegion: CGRect
            switch layout {
            case .column, .route: identityRegion = CGRect(x: 80, y: 190, width: 920, height: 92)
            case .compact: identityRegion = CGRect(x: 150, y: 650, width: 780, height: 550)
            case .ticket: identityRegion = CGRect(x: 330, y: 680, width: 420, height: 70)
            case .edge: identityRegion = CGRect(x: 115, y: 115, width: 270, height: 60)
            case .receipt: identityRegion = CGRect(x: 115, y: 1580, width: 270, height: 60)
            }
            XCTAssertNotNil(try coloredBounds(decoded, rect: identityRegion, color: [167, 216, 243]), layout.rawValue)
            XCTAssertGreaterThan(try visiblePixelCount(decoded, rect: identityRegion), 500, layout.rawValue)
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
        let fullGlyph = try XCTUnwrap(coloredBounds(image, rect: CGRect(x: 430, y: 984, width: 220, height: 120), color: [255, 255, 255]))
        XCTAssertGreaterThanOrEqual(fullGlyph.minY, 990)
        XCTAssertLessThanOrEqual(fullGlyph.maxY, 1071)
        XCTAssertGreaterThan(fullGlyph.height, 50)
        XCTAssertEqual(fullGlyph.midX, 540, accuracy: 8)
        XCTAssertEqual(try visiblePixelCount(image, rect: CGRect(x: 430, y: 1088, width: 220, height: 22)), 0,
                       "The complete sport glyph must finish before statistics start")
        XCTAssertNotEqual(try croppedPNG(image, rect: sportBand),
                          try croppedPNG(noGlyph, rect: sportBand))
        let header = CGRect(x: 80, y: 150, width: 920, height: 340)
        XCTAssertEqual(try croppedPNG(image, rect: header),
                       try croppedPNG(noGlyph, rect: header),
                       "The Classic header must contain only the stacked identity, independent of sport")
    }

    func testClassicCaptionPreservesTitleAndBoundsLongTitles() throws {
        let composer = ShareImageComposer(style: BrandTheme.mury.shareStyle(for: .dark))
        func image(_ title: String) -> UIImage {
            let fixture = ShareImageComposer.Stats(symbolName: stats.symbolName, sportLabel: stats.sportLabel,
                distance: stats.distance, duration: stats.duration, paceOrSpeed: stats.paceOrSpeed,
                date: stats.date, title: title)
            return composer.compose(photo: nil, coordinates: coordinates, stats: fixture)
        }
        let empty = image("")
        let morning = image("Morning route")
        let evening = image("Evening route")
        let caption = CGRect(x: 54, y: 1610, width: 972, height: 60)
        XCTAssertNotEqual(try croppedPNG(morning, rect: caption), try croppedPNG(evening, rect: caption))
        XCTAssertGreaterThan(try visiblePixelCount(morning, rect: caption), 0)
        XCTAssertEqual(empty.pngData(), image(" \n ").pngData())
        XCTAssertEqual(morning.pngData(), image("  Morning route  ").pngData())
        let long = image(String(repeating: "Caminhada de quarta-feira — ", count: 20))
        XCTAssertGreaterThan(try visiblePixelCount(long, rect: caption), 0)
        let legacyDate = CGRect(x: 0, y: 1610, width: 1080, height: 60)
        XCTAssertGreaterThan(try visiblePixelCount(empty, rect: legacyDate), 0)
        for candidate in [morning, evening, long] {
            XCTAssertEqual(try croppedPNG(candidate, rect: CGRect(x: 0, y: 0, width: 1080, height: 1590)),
                           try croppedPNG(empty, rect: CGRect(x: 0, y: 0, width: 1080, height: 1590)))
            XCTAssertEqual(try croppedPNG(candidate, rect: CGRect(x: 0, y: 1700, width: 1080, height: 60)),
                           try croppedPNG(empty, rect: legacyDate), "The date must retain its content")
            XCTAssertEqual(try visiblePixelCount(candidate, rect: CGRect(x: 0, y: 1610, width: 54, height: 60)), 0)
            XCTAssertEqual(try visiblePixelCount(candidate, rect: CGRect(x: 1026, y: 1610, width: 54, height: 60)), 0)
            XCTAssertEqual(try visiblePixelCount(candidate, rect: CGRect(x: 0, y: 1760, width: 1080, height: 160)), 0)
        }
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

    func testClassicUsesOriginalStackedAssetInHeader() throws {
        let logo = try XCTUnwrap(UIImage(named: "LogoStackedBlueWhite"))
        XCTAssertEqual(logo.size.width / logo.size.height, 220.41 / 227, accuracy: 0.01)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let expected = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1920), format: format).image { _ in
            let width = logo.size.width * 280 / logo.size.height
            logo.draw(in: CGRect(x: (1080 - width) / 2, y: 190, width: width, height: 280))
        }
        let actual = ShareImageComposer(style: BrandTheme.mury.shareStyle(for: .dark))
            .compose(photo: nil, coordinates: coordinates, stats: stats)
        let header = CGRect(x: 80, y: 150, width: 920, height: 340)
        XCTAssertEqual(try croppedPNG(actual, rect: header), try croppedPNG(expected, rect: header))
    }

    func testReferenceLayoutsDrawTheirDistinctTransparentGeometry() throws {
        let composer = ShareImageComposer(style: BrandTheme.mury.shareStyle(for: .dark))
        let values = [ShareImageComposer.OverlayValue(id: .duration, label: "TIME", value: "30:00")]
        let chips = composer.composeOverlay(layout: .compact, coordinates: [], stats: stats, metrics: values)
        XCTAssertGreaterThan(try visiblePixelCount(chips, rect: CGRect(x: 150, y: 700, width: 780, height: 520)), 2000)
        XCTAssertEqual(try visiblePixelCount(chips, rect: CGRect(x: 0, y: 1250, width: 1080, height: 670)), 0)
        let ticket = composer.composeOverlay(layout: .ticket, coordinates: [], stats: stats, metrics: values)
        XCTAssertGreaterThan(try pixel(ticket, x: 250, y: 650)[3], 200)
        XCTAssertEqual(try pixel(ticket, x: 300, y: 650)[3], 0, "Ticket outline must not become an opaque card")
        XCTAssertNotNil(try coloredBounds(ticket, rect: CGRect(x: 450, y: 800, width: 180, height: 180), color: [178, 14, 28]))
        let edge = composer.composeOverlay(layout: .edge, coordinates: [], stats: stats, metrics: values)
        XCTAssertGreaterThan(try visiblePixelCount(edge, rect: CGRect(x: 900, y: 190, width: 100, height: 1540)), 100)
        XCTAssertEqual(try visiblePixelCount(edge, rect: CGRect(x: 180, y: 300, width: 650, height: 1400)), 0)
        let receipt = composer.composeOverlay(layout: .receipt, coordinates: [], stats: stats, metrics: values)
        XCTAssertEqual(try visiblePixelCount(receipt, rect: CGRect(x: 0, y: 300, width: 1080, height: 1200)), 0)
        XCTAssertGreaterThan(try visiblePixelCount(receipt, rect: CGRect(x: 350, y: 1738, width: 300, height: 10)), 20,
                             "Receipt must connect its bottom label/value row with visible dots")
    }

    func testChipsPreservesSelectedTitleAndBoundsLongTitles() throws {
        let composer = ShareImageComposer(style: BrandTheme.mury.shareStyle(for: .dark))
        let values = [ShareImageComposer.OverlayValue(id: .duration, label: "TIME", value: "30:00")]
        func image(title: String, metrics: [ShareImageComposer.OverlayValue]) -> UIImage {
            let fixture = ShareImageComposer.Stats(symbolName: stats.symbolName, sportLabel: stats.sportLabel,
                distance: stats.distance, duration: stats.duration, paceOrSpeed: stats.paceOrSpeed,
                date: stats.date, title: title)
            return composer.composeOverlay(layout: .compact, coordinates: [], stats: fixture, metrics: metrics)
        }
        XCTAssertNotEqual(image(title: "Morning route", metrics: values).pngData(),
                          image(title: "Evening route", metrics: values).pngData())
        XCTAssertEqual(image(title: "", metrics: values).pngData(),
                       image(title: " \n ", metrics: values).pngData(), "Empty title adds no fallback sport pill")
        XCTAssertEqual(image(title: "Morning route", metrics: []).pngData(),
                       image(title: "Evening route", metrics: []).pngData(), "No selected metrics still means logo only")
        let long = image(title: String(repeating: "Caminhada de quarta-feira — ", count: 20), metrics: values)
        XCTAssertEqual(try pixel(long, x: 0, y: 0)[3], 0)
        XCTAssertEqual(try visiblePixelCount(long, rect: CGRect(x: 0, y: 0, width: 100, height: 1920)), 0)
        XCTAssertEqual(try visiblePixelCount(long, rect: CGRect(x: 980, y: 0, width: 100, height: 1920)), 0)
        XCTAssertEqual(try visiblePixelCount(long, rect: CGRect(x: 0, y: 1700, width: 1080, height: 220)), 0)
    }

    func testTicketUsesSuppliedWeekdayWithoutParsingDateText() throws {
        let composer = ShareImageComposer(style: BrandTheme.mury.shareStyle(for: .dark))
        let localized = ShareImageComposer.Stats(symbolName: "figure.run", sportLabel: "Corrida", distance: "5 km",
            duration: "30:00", paceOrSpeed: "6:00 /km", date: "31 de outubro", weekday: "sábado")
        let noWeekday = ShareImageComposer.Stats(symbolName: "figure.run", sportLabel: "Corrida", distance: "5 km",
            duration: "30:00", paceOrSpeed: "6:00 /km", date: "31 de outubro")
        XCTAssertEqual(noWeekday.weekday, "")
        let values = [ShareImageComposer.OverlayValue(id: .duration, label: "TEMPO", value: "30:00")]
        let withDay = composer.composeOverlay(layout: .ticket, coordinates: [], stats: localized, metrics: values)
        let withoutDay = composer.composeOverlay(layout: .ticket, coordinates: [], stats: noWeekday, metrics: values)
        let dayRegion = CGRect(x: 280, y: 1030, width: 520, height: 76)
        XCTAssertGreaterThan(try visiblePixelCount(withDay, rect: dayRegion), 100)
        XCTAssertEqual(try visiblePixelCount(withoutDay, rect: dayRegion), 0)
        XCTAssertEqual(try croppedPNG(withDay, rect: CGRect(x: 280, y: 1120, width: 520, height: 60)),
                       try croppedPNG(withoutDay, rect: CGRect(x: 280, y: 1120, width: 520, height: 60)))
    }

    func testAllOverlayLayoutsBoundLongLocalizedContentAndRenderOnlySixMetrics() throws {
        let composer = ShareImageComposer(style: BrandTheme.mury.shareStyle(for: .light))
        let long = String(repeating: "Última atividade de quarta-feira — ", count: 8)
        let localized = ShareImageComposer.Stats(symbolName: "bicycle", sportLabel: long, distance: "20 km",
            duration: "1:00:00", paceOrSpeed: "20.0 km/h", date: long, title: long, usesPaceMetric: false, weekday: long)
        let values = ShareImageComposer.OverlayMetric.allCases.map {
            ShareImageComposer.OverlayValue(id: $0, label: long, value: long + "20.0 km/h")
        }
        for layout in ShareImageComposer.OverlayLayout.allCases {
            let image = composer.composeOverlay(layout: layout, coordinates: [], stats: localized, metrics: values)
            let extra = composer.composeOverlay(layout: layout, coordinates: [], stats: localized,
                metrics: values + [.init(id: .duration, label: "EXTRA", value: "DO NOT DRAW")])
            XCTAssertEqual(image.pngData(), extra.pngData(), layout.rawValue)
            XCTAssertEqual(try visiblePixelCount(image, rect: CGRect(x: 0, y: 0, width: 60, height: 1920)), 0, layout.rawValue)
            XCTAssertEqual(try visiblePixelCount(image, rect: CGRect(x: 1020, y: 0, width: 60, height: 1920)), 0, layout.rawValue)
            XCTAssertEqual(try visiblePixelCount(image, rect: CGRect(x: 0, y: 1850, width: 1080, height: 70)), 0, layout.rawValue)
            let changed = composer.composeOverlay(layout: layout, coordinates: [], stats: localized,
                metrics: [.init(id: .duration, label: "TIME", value: "42:17")])
            XCTAssertNotEqual(image.pngData(), changed.pngData(), layout.rawValue)
        }
    }

    func testSegmentedMapKeepsFullProjectionAndDoesNotConnectGaps() throws {
        let composer = ShareImageComposer(style: BrandTheme.mury.shareStyle(for: .light))
        let segments: [[CLLocationCoordinate2D]] = [
            [.init(latitude: 0, longitude: 0), .init(latitude: 0, longitude: 0.0002)],
            [.init(latitude: 0.001, longitude: 0.0008), .init(latitude: 0.001, longitude: 0.001)]
        ]
        let full = segments.flatMap { $0 }
        func render(_ visible: [[CLLocationCoordinate2D]]) -> UIImage {
            composer.composeMapCard(snapshot: nil, coordinates: full, stats: stats,
                revealedSegments: visible, routeCoordinates: full)
        }
        let finished = render(segments)
        let partial = render([segments[0]])
        let firstSegment = CGRect(x: 95, y: 1065, width: 195, height: 30)
        XCTAssertEqual(try croppedPNG(partial, rect: firstSegment), try croppedPNG(finished, rect: firstSegment),
                       "Revealing more of the route must not rescale earlier segments")
        let center = CGRect(x: 510, y: 610, width: 60, height: 60)
        let connected = composer.composeMapCard(snapshot: nil, coordinates: full, stats: stats)
        XCTAssertNotEqual(try croppedPNG(finished, rect: center), try croppedPNG(connected, rect: center),
                          "A pause gap must not become a route stroke")
        let staticSingle = composer.composeMapCard(snapshot: nil, coordinates: full, stats: stats)
        XCTAssertEqual(staticSingle.pngData(), render([full]).pngData(),
                       "A complete single segment must preserve the existing static geometry")
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
