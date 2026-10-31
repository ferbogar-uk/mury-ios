import SwiftUI
import UIKit

enum BrandTheme: String, CaseIterable, Identifiable {
    case tiffany, pink

    static let storageKey = "brandTheme"
    var id: String { rawValue }
    var label: String { self == .pink ? "Pink" : "Tiffany Blue" }
    private var assetPrefix: String { self == .pink ? "Pink" : "Tiffany" }

    var accent: Color { Color(assetPrefix + "Accent") }
    var onAccent: Color { Color(assetPrefix + "OnAccent") }
    var tint: Color { Color(assetPrefix + "Tint") }
    var canvas: Color { Color(assetPrefix + "Canvas") }
    var surface: Color { Color(assetPrefix + "Surface") }
    var ink: Color { Color(assetPrefix + "Ink") }
    var muted: Color { Color(assetPrefix + "Muted") }
    var border: Color { Color(assetPrefix + "Border") }

    func uiColor(_ role: String, for scheme: ColorScheme) -> UIColor {
        guard let color = UIColor(named: assetPrefix + role) else {
            preconditionFailure("Missing brand asset: \(assetPrefix + role)")
        }
        return color.resolvedColor(with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light))
    }

    func shareStyle(for scheme: ColorScheme) -> ShareStyle {
        ShareStyle(route: uiColor("Accent", for: scheme), backdrop: uiColor("Canvas", for: .dark), interfaceStyle: scheme == .dark ? .dark : .light)
    }
}

struct ShareStyle {
    let route: UIColor
    let backdrop: UIColor
    let interfaceStyle: UIUserInterfaceStyle
}

private struct BrandThemeKey: EnvironmentKey {
    static let defaultValue = BrandTheme.tiffany
}

extension EnvironmentValues {
    var brandTheme: BrandTheme {
        get { self[BrandThemeKey.self] }
        set { self[BrandThemeKey.self] = newValue }
    }
}
