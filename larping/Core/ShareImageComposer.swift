import CoreText
import CoreLocation
import MapKit
import UIKit

/// Builds the shareable activity cards:
///
/// 1. `compose` — classic template. The recorded route as an accent-color line
///    over either a custom photo (full-bleed, dimmed) or a *transparent* PNG
///    (so the plain card can be pasted onto any backdrop — the dark text
///    shadows keep the white content readable over light pastes too).
/// 2. `composeMapCard` — map templates (share image + video). A real MapKit
///    snapshot fills the whole canvas as the background, with the route
///    overlaid in the accent color and a bottom card carrying title/date/
///    stats/logo/URL. `routeRevealFraction` lets the video composer reveal the
///    route in recorded order frame-by-frame over the same map.
///
/// Supplied Rubik typography throughout. The photo-less classic card is transparent; the map
/// card is self-contained (map background + card). The route line always uses
/// the fixed MURY red route, independently of the selected action tint.
struct ShareImageComposer {
    let style: ShareStyle
    static let canvasSize = CGSize(width: 1080, height: 1920) // Instagram Story ratio

    private let white = UIColor.white
    private var spaceBlack: UIColor { style.backdrop }
    private var routeColor: UIColor { style.route }

    struct Stats {
        let symbolName: String
        let sportLabel: String
        let title: String
        let distance: String
        let duration: String
        let paceOrSpeed: String
        let date: String
        let usesPaceMetric: Bool
        var metricLabel: String { usesPaceMetric ? "PACE" : "SPEED" }

        init(symbolName: String, sportLabel: String, distance: String, duration: String, paceOrSpeed: String, date: String, title: String = "", usesPaceMetric: Bool = true) {
            self.symbolName = symbolName
            self.sportLabel = sportLabel
            self.title = title
            self.distance = distance
            self.duration = duration
            self.paceOrSpeed = paceOrSpeed
            self.date = date
            self.usesPaceMetric = usesPaceMetric
        }
    }


    enum OverlayLayout: String, CaseIterable, Identifiable {
        case column = "Statistics", compact = "Compact", route = "Route + stats"
        var id: String { rawValue }
    }

    enum OverlayMetric: String, CaseIterable {
        case distance, duration, paceOrSpeed, elevation, averageHeartRate, maxHeartRate
    }

    struct OverlayValue: Identifiable {
        let id: OverlayMetric
        let label: String
        let value: String
    }

    static func overlayMetrics(for activity: CDActivity) -> [OverlayValue] {
        var values: [OverlayValue] = []
        if let distance = activity.distanceMeters, distance >= 0 {
            values.append(.init(id: .distance, label: "DISTANCE", value: Formatters.distance(meters: Double(distance))))
        }
        if let duration = activity.durationSeconds, duration >= 0 {
            values.append(.init(id: .duration, label: "TIME", value: Formatters.duration(seconds: duration)))
        }
        let pace = Formatters.paceOrSpeed(sportType: activity.sportType,
                                         averagePaceSecondsPerKm: activity.averagePaceSecondsPerKm,
                                         averageSpeedMps: activity.averageSpeedMps)
        if pace != "–" {
            values.append(.init(id: .paceOrSpeed, label: activity.sportType.usesPaceMetric ? "PACE" : "SPEED", value: pace))
        }
        if let elevation = activity.elevationGainMeters, elevation >= 0 {
            values.append(.init(id: .elevation, label: "ELEVATION GAIN", value: Formatters.elevation(meters: Double(elevation))))
        }
        if let heartRate = activity.averageHeartRateBpm, heartRate > 0 {
            values.append(.init(id: .averageHeartRate, label: "AVG HEART RATE", value: "\(heartRate) bpm"))
        }
        if let heartRate = activity.maxHeartRateBpm, heartRate > 0 {
            values.append(.init(id: .maxHeartRate, label: "MAX HEART RATE", value: "\(heartRate) bpm"))
        }
        return values
    }

    func composeOverlay(layout: OverlayLayout, coordinates: [CLLocationCoordinate2D],
                        stats: Stats, metrics: [OverlayValue]) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: Self.canvasSize, format: format).image { _ in
            if let logo = UIImage(named: "LogoBlueWhite") {
                let height: CGFloat = 92
                let width = logo.size.width * height / logo.size.height
                logo.draw(in: CGRect(x: (Self.canvasSize.width - width) / 2, y: 190, width: width, height: height))
            }
            guard !metrics.isEmpty else { return }
            drawOverlayText(displayTitle(stats), in: CGRect(x: 80, y: 340, width: 920, height: 80), size: 42, weight: .semibold)
            drawOverlayText(stats.date, in: CGRect(x: 80, y: 420, width: 920, height: 60), size: 28, weight: .regular)
            if layout == .route {
                drawRoute(coordinates, canvasWidth: Self.canvasSize.width,
                          availableRect: CGRect(x: 100, y: 540, width: 880, height: 500))
            }
            for (index, metric) in metrics.prefix(6).enumerated() {
                let column = layout == .column
                let x: CGFloat = column ? 80 : 80 + CGFloat(index % 2) * 470
                let y: CGFloat = column ? 570 + CGFloat(index) * 172 : 1140 + CGFloat(index / 2) * 174
                let width: CGFloat = column ? 920 : 450
                drawOverlayText(metric.label, in: CGRect(x: x, y: y, width: width, height: 42), size: 25, weight: .semibold)
                drawOverlayText(metric.value, in: CGRect(x: x, y: y + 44, width: width, height: 90), size: column ? 66 : 50, weight: .bold)
            }
        }
    }

    private func drawOverlayText(_ text: String, in rect: CGRect, size: CGFloat, weight: MuryTypography.Weight) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        var attributes = textAttributes(white, size: size, weight: weight, soft: true)
        attributes[.paragraphStyle] = paragraph
        NSAttributedString(string: text, attributes: attributes).draw(in: rect)
    }

    /// Classic template. `photo == nil` leaves the background transparent so
    /// the output PNG can be pasted anywhere; `soft == true` (no photo) adds
    /// dark shadows under the white foreground so it stays legible on light
    /// targets.
    func compose(
        photo: UIImage?,
        coordinates: [CLLocationCoordinate2D],
        stats: Stats,
        routeRevealFraction: Double = 1
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: Self.canvasSize, format: format)

        let width = Self.canvasSize.width
        let softShadow = photo == nil

        return renderer.image { context in
            let bounds = CGRect(origin: .zero, size: Self.canvasSize)
            let cgContext = context.cgContext

            if let photo {
                draw(photo, filling: bounds)
                UIColor.black.withAlphaComponent(0.48).setFill()
                cgContext.fill(bounds)
            } else {
                // Leave the background transparent — nothing is drawn here, so
                // the renderer's clear canvas becomes a transparent PNG.
            }

            drawHeader(stats, canvasWidth: width, soft: softShadow)
            drawRoute(coordinates, canvasWidth: width, revealFraction: routeRevealFraction)
            drawStats(stats, canvasWidth: width, soft: softShadow)
            drawFooter(stats, canvasWidth: width, soft: softShadow)
        }
    }

    /// Map templates (static image + every video frame). Full-bleed real map
    /// snapshot as the background, route overlaid on it, and one bottom card
    /// holding the activity info. If no snapshot is available (offline), falls
    /// back to a space-black background with the route drawn above the card.
    func composeMapCard(snapshot: MKMapSnapshotter.Snapshot?, coordinates: [CLLocationCoordinate2D], stats: Stats, routeRevealFraction: Double = 1) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: Self.canvasSize, format: format)

        let width = Self.canvasSize.width

        return renderer.image { context in
            let bounds = CGRect(origin: .zero, size: Self.canvasSize)
            let cgContext = context.cgContext

            if let snapshot {
                snapshot.image.draw(in: bounds)
                UIColor.black.withAlphaComponent(0.32).setFill()
                cgContext.fill(bounds)
                drawScrim(in: bounds, using: cgContext)
                drawRoute(onto: snapshot, coordinates: coordinates, routeRevealFraction: routeRevealFraction)
            } else {
                spaceBlack.setFill()
                cgContext.fill(bounds)
                drawRoute(
                    coordinates,
                    canvasWidth: width,
                    availableRect: CGRect(x: 54, y: 200, width: width - 108, height: 880),
                    revealFraction: routeRevealFraction
                )
            }

            drawTopRightLogo(canvasWidth: width)
            drawTopLeftIcon(stats)
            drawInfoCard(stats, canvasWidth: width)
        }
    }

    /// Snapshots the route's bounding box into map tiles. `size` defaults to
    /// the full canvas so `snapshot.point(for:)` maps 1:1 onto canvas
    /// coordinates (no scaling needed when drawing the route back on top).
    func mapSnapshot(coordinates: [CLLocationCoordinate2D], size: CGSize = ShareImageComposer.canvasSize) async -> MKMapSnapshotter.Snapshot? {
        guard coordinates.count > 1 else { return nil }
        let lats = coordinates.map(\.latitude)
        let lngs = coordinates.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLng = lngs.min()!, maxLng = lngs.max()!
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.004),
            longitudeDelta: max((maxLng - minLng) * 1.3, 0.004)
        )

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: center, span: span)
        options.size = size
        options.scale = 1
        options.mapType = .standard
        options.showsBuildings = false
        options.traitCollection = UITraitCollection(userInterfaceStyle: style.interfaceStyle)

        return try? await MKMapSnapshotter(options: options).start()
    }

    private func draw(_ image: UIImage, filling rect: CGRect) {
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        image.draw(in: CGRect(origin: origin, size: size))
    }

    // MARK: - Classic template drawing

    /// Small sport icon at the top with the wordmark (now the more prominent
    /// element, not the icon) beneath it — no event title/date here (moved to
    /// the footer). Extra top padding leaves room for Instagram Story's own
    /// UI (profile chip, close button) when shared there.
    private func drawHeader(_ stats: Stats, canvasWidth: CGFloat, soft: Bool) {
        let iconBox: CGFloat = 130
        var cursorY: CGFloat = 190

        if let glyph = UIImage(systemName: stats.symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: iconBox, weight: .bold)) {
            let tinted = glyph.withTintColor(white)
            let glyphSize = tinted.size
            let scale = min(iconBox / glyphSize.width, iconBox / glyphSize.height)
            let size = CGSize(width: glyphSize.width * scale, height: glyphSize.height * scale)
            let rect = CGRect(
                x: canvasWidth / 2 - size.width / 2,
                y: cursorY,
                width: size.width,
                height: size.height
            )
            if soft {
                let backing = glyph.withTintColor(UIColor.black.withAlphaComponent(0.8))
                backing.draw(in: rect.offsetBy(dx: 0, dy: 8))
            }
            tinted.draw(in: rect)
            cursorY = rect.maxY + 24
        }

        if let logo = UIImage(named: "LogoBlueWhite") {
            let height: CGFloat = 110
            let size = CGSize(width: logo.size.width * (height / logo.size.height), height: height)
            let rect = CGRect(x: (canvasWidth - size.width) / 2, y: cursorY, width: size.width, height: size.height)
            logo.draw(in: rect)
        }
    }

    /// Draws the recorded route as a stroked accent-color line, scaled to fit a
    /// region whose aspect exactly matches the route's own bounding box, so the
    /// path is always centered with symmetric margins on all four sides — never
    /// shifted toward one edge — no matter how big or small the route is.
    /// `revealFraction` (0...1) draws only the leading portion in recorded point
    /// order, for the animated video export… and the classic template's route
    /// (pass 1 at rest). No endpoint markers when fully revealed.
    private func drawRoute(_ coordinates: [CLLocationCoordinate2D], canvasWidth: CGFloat, availableRect: CGRect = CGRect(x: 54, y: 504, width: 972, height: 466), revealFraction: Double = 1) {
        guard coordinates.count > 1 else { return }

        let lats = coordinates.map(\.latitude)
        let lngs = coordinates.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLng = lngs.min()!, maxLng = lngs.max()!
        let latSpan = max(maxLat - minLat, 0.0001)
        let lngSpan = max(maxLng - minLng, 0.0001)

        let available = availableRect
        let routeAspect = lngSpan / latSpan
        let availableAspect = available.width / available.height
        var region = available
        if routeAspect > availableAspect {
            region.size.height = available.width / routeAspect
            region.origin.y = available.midY - region.height / 2
            region.size.width = available.width
        } else {
            region.size.width = available.height * routeAspect
            region.origin.x = available.midX - region.width / 2
            region.size.height = available.height
        }

        let scale = region.width / lngSpan // == region.height / latSpan
        let points = coordinates.map { coordinate -> CGPoint in
            CGPoint(
                x: region.minX + (coordinate.longitude - minLng) * scale,
                y: region.minY + (maxLat - coordinate.latitude) * scale
            )
        }

        let revealCount = max(2, Int(Double(points.count) * revealFraction))
        let visiblePoints = Array(points.prefix(revealCount))

        let path = UIBezierPath()
        path.move(to: visiblePoints[0])
        visiblePoints.dropFirst().forEach { path.addLine(to: $0) }
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = 24
        white.setStroke()
        path.stroke()
        path.lineWidth = 16
        routeColor.setStroke()
        path.stroke()

        // Leading dot marks the current tip while the route is still being
        // revealed (video export); the finished static image has none.
        if revealFraction < 1, let tip = visiblePoints.last {
            let dotRect = CGRect(x: tip.x - 14, y: tip.y - 14, width: 28, height: 28)
            routeColor.setFill()
            UIBezierPath(ovalIn: dotRect).fill()
            let outline = UIBezierPath(ovalIn: dotRect)
            outline.lineWidth = 3
            white.setStroke()
            outline.stroke()
        }
    }

    /// Stats rendered as one centered column — three rows of label + value.
    private func drawStats(_ stats: Stats, canvasWidth: CGFloat, startY: CGFloat = 1020, soft: Bool) {
        let rows: [(String, String)] = [
            ("DISTANCE", stats.distance),
            ("DURATION", stats.duration),
            (stats.metricLabel, stats.paceOrSpeed),
        ]

        var y: CGFloat = startY
        for row in rows {
            drawCentered(NSAttributedString(string: row.0, attributes: textAttributes(white.withAlphaComponent(0.62), size: 34, weight: .semibold, soft: soft)), atY: y, canvasWidth: canvasWidth)
            let value = NSAttributedString(string: row.1, attributes: valueAttributes(64, soft: soft))
            drawCentered(value, atY: y + 42, canvasWidth: canvasWidth)
            y += 42 + value.size().height + 46
        }
    }

    /// Date, raised above Instagram Story's reply input area — replaces the
    /// repo URL that used to live here (removed; the wordmark up top under
    /// the sport icon is branding enough).
    private func drawFooter(_ stats: Stats, canvasWidth: CGFloat, soft: Bool) {
        let date = NSAttributedString(string: stats.date, attributes: textAttributes(white.withAlphaComponent(0.72), size: 30, weight: .semibold, soft: soft))
        drawCentered(date, atY: 1610, canvasWidth: canvasWidth)
    }

    // MARK: - Map card drawing

    /// Wordmark floated top-right over the map itself, separate from the info
    /// card; preserve the supplied light-blue symbol and white wordmark.
    private func drawTopRightLogo(canvasWidth: CGFloat) {
        guard let logo = UIImage(named: "LogoBlueWhite") else { return }
        let height: CGFloat = 52
        let size = CGSize(width: logo.size.width * (height / logo.size.height), height: height)
        let rect = CGRect(x: canvasWidth - size.width - 54, y: 170, width: size.width, height: size.height)
        logo.draw(in: rect)
    }

    /// Sport icon floated top-left over the map, mirroring the wordmark's
    /// top-right placement — keeps the info card's title/date flush left
    /// instead of indented past an icon.
    private func drawTopLeftIcon(_ stats: Stats) {
        guard let glyph = UIImage(systemName: stats.symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .bold)) else { return }
        let rect = CGRect(x: 54, y: 170, width: glyph.size.width, height: glyph.size.height)
        glyph.withTintColor(UIColor.black.withAlphaComponent(0.75)).draw(in: rect.offsetBy(dx: 0, dy: 5))
        glyph.withTintColor(white).draw(in: rect)
    }

    private func drawScrim(in bounds: CGRect, using cgContext: CGContext) {
        let colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.62).cgColor,
        ] as CFArray
        let locations: [CGFloat] = [0.35, 1.0]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else { return }
        cgContext.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: bounds.height * 0.2),
            end: CGPoint(x: 0, y: bounds.height),
            options: []
        )
    }

    /// Draws the route over an already-rendered map snapshot. Works because the
    /// snapshot was requested at canvas size, so `point(for:)` already yields
    /// canvas coordinates.
    private func drawRoute(onto snapshot: MKMapSnapshotter.Snapshot, coordinates: [CLLocationCoordinate2D], routeRevealFraction: Double = 1) {
        guard coordinates.count > 1 else { return }
        let points = coordinates.map { snapshot.point(for: $0) }
        let count = max(2, Int(Double(points.count) * routeRevealFraction))
        let visible = Array(points.prefix(count))

        let path = UIBezierPath()
        path.move(to: visible[0])
        visible.dropFirst().forEach { path.addLine(to: $0) }
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = 22
        white.setStroke()
        path.stroke()
        path.lineWidth = 14
        routeColor.setStroke()
        path.stroke()

        if routeRevealFraction < 1, let tip = visible.last {
            let dotRect = CGRect(x: tip.x - 16, y: tip.y - 16, width: 32, height: 32)
            routeColor.setFill()
            UIBezierPath(ovalIn: dotRect).fill()
            let outline = UIBezierPath(ovalIn: dotRect)
            outline.lineWidth = 4
            white.setStroke()
            outline.stroke()
        } else if routeRevealFraction >= 1 {
            drawRouteEndpoint(at: points[0], symbolName: "flag.circle.fill")
            drawRouteEndpoint(at: points[points.count - 1], symbolName: "checkered.flag")
        }
    }

    /// Small labeled flag badge for the route's start/finish points on the
    /// finished map card — only shown once the route is fully drawn in.
    private func drawRouteEndpoint(at point: CGPoint, symbolName: String) {
        guard let glyph = UIImage(systemName: symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)) else { return }
        let badgeRadius: CGFloat = 22
        let badgeRect = CGRect(x: point.x - badgeRadius, y: point.y - badgeRadius, width: badgeRadius * 2, height: badgeRadius * 2)
        white.setFill()
        UIBezierPath(ovalIn: badgeRect).fill()
        let outline = UIBezierPath(ovalIn: badgeRect)
        outline.lineWidth = 3
        routeColor.setStroke()
        outline.stroke()
        let tinted = glyph.withTintColor(spaceBlack)
        let iconRect = CGRect(x: point.x - tinted.size.width / 2, y: point.y - tinted.size.height / 2, width: tinted.size.width, height: tinted.size.height)
        tinted.draw(in: iconRect)
    }

    /// Bottom card over the map: event title + date and the three stats — no
    /// icon (moved top-left over the map) or repo URL, and sized to its own
    /// content instead of leaving empty space below.
    private func drawInfoCard(_ stats: Stats, canvasWidth: CGFloat) {
        let card = CGRect(x: 54, y: 1180, width: canvasWidth - 108, height: 380)
        UIColor.black.withAlphaComponent(0.5).setFill()
        UIBezierPath(roundedRect: card, cornerRadius: 48)
            .fill()

        let title = NSAttributedString(string: displayTitle(stats), attributes: textAttributes(white, size: 56, weight: .bold, soft: false))
        let date = NSAttributedString(string: stats.date, attributes: textAttributes(white.withAlphaComponent(0.72), size: 30, weight: .semibold, soft: false))
        let textX = card.minX + 44
        var y: CGFloat = card.minY + 44
        title.draw(at: CGPoint(x: textX, y: y))
        y += title.size().height + 10
        date.draw(at: CGPoint(x: textX, y: y))

        // Three stats across one row.
        let rows: [(String, String)] = [
            ("DISTANCE", stats.distance),
            ("DURATION", stats.duration),
            (stats.metricLabel, stats.paceOrSpeed),
        ]
        let colWidth = (card.width - 88) / 3
        for (index, row) in rows.enumerated() {
            let centerX = card.minX + 44 + colWidth * CGFloat(index) + colWidth / 2
            drawCentered(NSAttributedString(string: row.0, attributes: textAttributes(white.withAlphaComponent(0.6), size: 24, weight: .semibold, soft: false)), atY: card.minY + 224, centerX: centerX)
            drawCentered(NSAttributedString(string: row.1, attributes: valueAttributes(50, soft: false)), atY: card.minY + 260, centerX: centerX)
        }
    }

    // MARK: - Helpers

    private func displayTitle(_ stats: Stats) -> String {
        let trimmed = stats.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "MURY \(stats.sportLabel)" : trimmed
    }

    private func textAttributes(_ color: UIColor, size: CGFloat, weight: MuryTypography.Weight, soft: Bool) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: MuryTypography.uiFont(size: size, weight: weight),
            .foregroundColor: color,
        ]
        if soft {
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.8)
            shadow.shadowBlurRadius = 16
            shadow.shadowOffset = CGSize(width: 0, height: 2)
            attributes[.shadow] = shadow
        }
        return attributes
    }

    private func valueAttributes(_ size: CGFloat, soft: Bool) -> [NSAttributedString.Key: Any] {
        let descriptor = MuryTypography.uiFont(size: size, weight: .bold).fontDescriptor.addingAttributes([
            .featureSettings: [[
                UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
            ]],
        ])
        var attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(descriptor: descriptor, size: size),
            .foregroundColor: white,
        ]
        if soft {
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.8)
            shadow.shadowBlurRadius = 16
            shadow.shadowOffset = CGSize(width: 0, height: 2)
            attributes[.shadow] = shadow
        }
        return attributes
    }

    private func drawCentered(_ string: NSAttributedString, atY y: CGFloat, canvasWidth: CGFloat) {
        let size = string.size()
        string.draw(at: CGPoint(x: (canvasWidth - size.width) / 2, y: y))
    }

    private func drawCentered(_ string: NSAttributedString, atY y: CGFloat, centerX: CGFloat) {
        string.draw(at: CGPoint(x: centerX - string.size().width / 2, y: y))
    }
}