import SwiftUI
import UIKit

/// One place that draws a sport's icon. Every sport uses an SF Symbol from `SportType.symbolName`
/// (strength is Apple's own `figure.strengthtraining.traditional`, the same as on Apple Watch).
/// Build 43 drew a custom thin strength figure here; Ricardo preferred Apple's, so build 44 went back.
/// The wrappers stay so every icon site keeps one entry point if a custom icon is ever needed again.
enum SportIcon {
    /// The icon as a template image of `pointSize`, so `withTintColor` colours it.
    static func uiImage(named name: String, pointSize: CGFloat, weight: UIImage.SymbolWeight) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight))
    }
}

/// Drop-in for `Image(systemName:)` for a sport's `symbolName`. `size` is the point size of the glyph.
struct SportSymbol: View {
    let name: String
    var size: CGFloat?

    init(_ name: String, size: CGFloat? = nil) {
        self.name = name
        self.size = size
    }

    var body: some View {
        // `size` is kept for the call sites; SF Symbols size themselves from the surrounding font.
        Image(systemName: name)
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
        Label(title, systemImage: symbol)
    }
}
