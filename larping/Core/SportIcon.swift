import SwiftUI
import UIKit

/// Sport icons that are not SF Symbols. Today only strength: a thin figure holding a barbell with plates,
/// the pose of Apple Health's strength icon drawn in MURY's own line style (Ricardo's design, build 43).
/// `SportType.symbolName` returns `SportIcon.strengthName` for it; every place that draws a sport icon goes
/// through `SportSymbol` (SwiftUI) or `SportIcon.uiImage` (Core Graphics) instead of `Image(systemName:)`.
enum SportIcon {
    /// Must equal what `SportType.strength.symbolName` returns (that file is Foundation-only, so it holds the text).
    static let strengthName = "mury.strength"

    static func isCustom(_ name: String) -> Bool { name == strengthName }

    /// Lines of the figure on a 48 x 48 grid: barbell, plates, arms, body and legs.
    static let strengthLines: [[CGPoint]] = [
        [CGPoint(x: 3, y: 27), CGPoint(x: 45, y: 27)],
        [CGPoint(x: 8, y: 21), CGPoint(x: 8, y: 33)],
        [CGPoint(x: 40, y: 21), CGPoint(x: 40, y: 33)],
        [CGPoint(x: 4, y: 23), CGPoint(x: 4, y: 31)],
        [CGPoint(x: 44, y: 23), CGPoint(x: 44, y: 31)],
        [CGPoint(x: 19, y: 17), CGPoint(x: 15, y: 27)],
        [CGPoint(x: 29, y: 17), CGPoint(x: 33, y: 27)],
        [CGPoint(x: 24, y: 16), CGPoint(x: 24, y: 31)],
        [CGPoint(x: 24, y: 31), CGPoint(x: 19, y: 45)],
        [CGPoint(x: 24, y: 31), CGPoint(x: 29, y: 45)],
    ]
    static let strengthHead = CGRect(x: 20, y: 4, width: 8, height: 8)
    static let strengthLineWidth: CGFloat = 3

    /// The icon as a template image of `pointSize` x `pointSize`, so `withTintColor` colours it like an SF Symbol.
    /// Ordinary SF Symbol names go through `UIImage(systemName:)`.
    static func uiImage(named name: String, pointSize: CGFloat, weight: UIImage.SymbolWeight) -> UIImage? {
        guard isCustom(name) else {
            return UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight))
        }
        let unit = pointSize / 48
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: pointSize, height: pointSize))
        let image = renderer.image { context in
            let cg = context.cgContext
            cg.setStrokeColor(UIColor.black.cgColor)
            cg.setFillColor(UIColor.black.cgColor)
            cg.setLineWidth(strengthLineWidth * unit)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            for line in strengthLines {
                guard let first = line.first else { continue }
                cg.move(to: CGPoint(x: first.x * unit, y: first.y * unit))
                for point in line.dropFirst() { cg.addLine(to: CGPoint(x: point.x * unit, y: point.y * unit)) }
            }
            cg.strokePath()
            cg.fillEllipse(in: CGRect(x: strengthHead.minX * unit, y: strengthHead.minY * unit,
                                      width: strengthHead.width * unit, height: strengthHead.height * unit))
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}

/// Drop-in for `Image(systemName:)` for a sport's `symbolName`. `size` is the point size of the glyph.
struct SportSymbol: View {
    let name: String
    var size: CGFloat?
    @ScaledMetric(relativeTo: .body) private var defaultSize: CGFloat = 17

    init(_ name: String, size: CGFloat? = nil) {
        self.name = name
        self.size = size
    }

    var body: some View {
        if SportIcon.isCustom(name) {
            let side = size ?? defaultSize
            StrengthFigure(side: side)
        } else {
            Image(systemName: name)
        }
    }
}

/// `Label` with a sport symbol.
struct SportLabel: View {
    let title: String
    let symbol: String

    init(_ title: String, symbol: String) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        Label { Text(title) } icon: { SportSymbol(symbol) }
    }
}

private struct StrengthFigureLines: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = rect.width / 48
        var path = Path()
        for line in SportIcon.strengthLines {
            guard let first = line.first else { continue }
            path.move(to: CGPoint(x: first.x * unit, y: first.y * unit))
            for point in line.dropFirst() { path.addLine(to: CGPoint(x: point.x * unit, y: point.y * unit)) }
        }
        return path
    }
}

private struct StrengthFigure: View {
    let side: CGFloat

    var body: some View {
        let unit = side / 48
        ZStack(alignment: .topLeading) {
            StrengthFigureLines()
                .stroke(style: StrokeStyle(lineWidth: SportIcon.strengthLineWidth * unit, lineCap: .round, lineJoin: .round))
            Circle()
                .frame(width: SportIcon.strengthHead.width * unit, height: SportIcon.strengthHead.height * unit)
                .offset(x: SportIcon.strengthHead.minX * unit, y: SportIcon.strengthHead.minY * unit)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}
