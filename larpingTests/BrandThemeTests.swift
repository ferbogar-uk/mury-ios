import SwiftUI
import UIKit
import XCTest
@testable import larping

@MainActor
final class BrandThemeTests: XCTestCase {
    func testSingleMuryIdentityAndDefault() {
        XCTAssertEqual(BrandTheme.allCases, [.mury])
        XCTAssertEqual(EnvironmentValues().brandTheme, .mury)
        XCTAssertEqual(BrandTheme.storageKey, "brandTheme")
    }

    func testPreferenceResolutionAcceptsOnlyKnownOnboardingMarkers() {
        for value: String? in [nil, "", "unknown", "MURY", " pink "] {
            XCTAssertNil(BrandTheme.resolvePreference(value))
        }
        for value in ["pink", "tiffany", "mury"] {
            XCTAssertEqual(BrandTheme.resolvePreference(value), .mury)
        }
    }

    func testLegacyResolutionDoesNotWritePreferences() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("dark", forKey: "appearanceMode")
        defaults.set("Existing name", forKey: "displayName")
        defaults.set(Data([1, 2, 3]), forKey: "existingData")
        for marker in ["pink", "tiffany", "mury"] {
            defaults.set(marker, forKey: BrandTheme.storageKey)
            let before = defaults.dictionaryRepresentation()
            XCTAssertEqual(BrandTheme.resolvePreference(defaults.string(forKey: BrandTheme.storageKey)), .mury)
            XCTAssertEqual(defaults.dictionaryRepresentation() as NSDictionary, before as NSDictionary)
        }
    }

    func testSuppliedPaletteAndFixedRoute() {
        let theme = BrandTheme.mury
        assertRGB(theme.uiColor("Canvas", for: .light), [249, 250, 251])
        assertRGB(theme.uiColor("Surface", for: .dark), [31, 41, 55])
        assertRGB(theme.uiColor("Accent", for: .light), [178, 14, 28])
        assertRGB(theme.uiColor("Accent", for: .dark), [167, 216, 243])
        assertRGB(theme.uiColor("Navigation", for: .light), [167, 216, 243])
        for scheme in [ColorScheme.light, .dark] {
            assertRGB(theme.shareStyle(for: scheme).route, [178, 14, 28])
            assertRGB(theme.uiColor("RouteCasing", for: scheme), [255, 255, 255])
        }
    }

    func testBundledRubikFontsLoadAndScale() throws {
        for weight in [MuryTypography.Weight.regular, .semibold, .bold] {
            let font = MuryTypography.uiFont(size: 20, weight: weight)
            XCTAssertTrue(font.fontName.hasPrefix("Rubik"))
            let normal = UIFontMetrics(forTextStyle: .body).scaledFont(for: font, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
            let large = UIFontMetrics(forTextStyle: .body).scaledFont(for: font, compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
            XCTAssertGreaterThan(large.pointSize, normal.pointSize)
        }
    }

    func testThemesRoundTripWithoutChangingAppearance() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("dark", forKey: "appearanceMode")
        defaults.set("Existing name", forKey: "displayName")
        defaults.set("Existing bio", forKey: "bio")
        for theme in BrandTheme.allCases {
            defaults.set(theme.rawValue, forKey: BrandTheme.storageKey)
            XCTAssertEqual(BrandTheme(rawValue: defaults.string(forKey: BrandTheme.storageKey)!), theme)
            XCTAssertEqual(defaults.string(forKey: "appearanceMode"), "dark")
            XCTAssertEqual(defaults.string(forKey: "displayName"), "Existing name")
            XCTAssertEqual(defaults.string(forKey: "bio"), "Existing bio")
        }
        for mode in AppearanceMode.allCases {
            defaults.set(mode.rawValue, forKey: "appearanceMode")
            XCTAssertEqual(defaults.string(forKey: BrandTheme.storageKey), BrandTheme.allCases.last?.rawValue)
        }
    }

    func testEveryThemeHasReadableButtonTextAndBodyText() {
        for theme in BrandTheme.allCases {
            for scheme in [ColorScheme.light, .dark] {
                XCTAssertGreaterThanOrEqual(contrast(theme.uiColor("OnAccent", for: scheme), theme.uiColor("Accent", for: scheme)), 4.5)
                for surface in ["Canvas", "Surface"] {
                    for text in ["Ink", "Muted", "Tint"] {
                        XCTAssertGreaterThanOrEqual(contrast(theme.uiColor(text, for: scheme), theme.uiColor(surface, for: scheme)), 4.5, "\(theme) \(scheme) \(text)/\(surface)")
                    }
                }
            }
        }
    }

    private func assertRGB(_ color: UIColor, _ expected: [Double], file: StaticString = #filePath, line: UInt = #line) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha), file: file, line: line)
        for (actual, expected) in zip([red, green, blue], expected) {
            XCTAssertEqual(Double(actual), expected / 255, accuracy: 0.001, file: file, line: line)
        }
        XCTAssertEqual(alpha, 1, file: file, line: line)
    }

    private func contrast(_ first: UIColor, _ second: UIColor) -> Double {
        func luminance(_ color: UIColor) -> Double {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            let components = [red, green, blue].map { value -> Double in
                let value = Double(value)
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return components[0] * 0.2126 + components[1] * 0.7152 + components[2] * 0.0722
        }
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
