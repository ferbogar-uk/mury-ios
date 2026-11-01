import SwiftUI
import UIKit

enum BrandTheme: String, CaseIterable, Identifiable {
    case mury

    static let storageKey = "brandTheme"
    var id: String { rawValue }
    var label: String { "MURY" }

    // Legacy values mark completed onboarding; resolving never rewrites stored preferences.
    static func resolvePreference(_ value: String?) -> BrandTheme? {
        guard let value, ["pink", "tiffany", "mury"].contains(value) else { return nil }
        return .mury
    }

    var accent: Color { Color("MuryAccent") }
    var onAccent: Color { Color("MuryOnAccent") }
    var tint: Color { Color("MuryTint") }
    var canvas: Color { Color("MuryCanvas") }
    var surface: Color { Color("MurySurface") }
    var ink: Color { Color("MuryInk") }
    var muted: Color { Color("MuryMuted") }
    var border: Color { Color("MuryBorder") }
    var navigation: Color { Color("MuryNavigation") }
    var route: Color { Color("MuryRoute") }
    var routeCasing: Color { Color("MuryRouteCasing") }

    func uiColor(_ role: String, for scheme: ColorScheme) -> UIColor {
        guard let color = UIColor(named: "Mury" + role) else {
            preconditionFailure("Missing brand asset: Mury" + role)
        }
        return color.resolvedColor(with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light))
    }

    func shareStyle(for scheme: ColorScheme) -> ShareStyle {
        ShareStyle(route: uiColor("Route", for: scheme), backdrop: uiColor("Canvas", for: .dark), interfaceStyle: scheme == .dark ? .dark : .light)
    }
}

struct ShareStyle {
    let route: UIColor
    let backdrop: UIColor
    let interfaceStyle: UIUserInterfaceStyle
}

private struct BrandThemeKey: EnvironmentKey {
    static let defaultValue = BrandTheme.mury
}

extension EnvironmentValues {
    var brandTheme: BrandTheme {
        get { self[BrandThemeKey.self] }
        set { self[BrandThemeKey.self] = newValue }
    }
}
