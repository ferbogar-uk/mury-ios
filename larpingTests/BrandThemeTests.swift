import SwiftUI
import UIKit
import XCTest
@testable import larping

@MainActor
final class BrandThemeTests: XCTestCase {
    func testTiffanyIsPresentedFirst() {
        XCTAssertEqual(BrandTheme.allCases, [.tiffany, .pink])
        XCTAssertEqual(EnvironmentValues().brandTheme, .tiffany)
    }

    func testMasterCanvasAndDarkSurfaces() {
        assertRGB(BrandTheme.pink.uiColor("Canvas", for: .light), [255, 240, 246])
        assertRGB(BrandTheme.pink.uiColor("Surface", for: .dark), [74, 44, 58])
        assertRGB(BrandTheme.tiffany.uiColor("Surface", for: .dark), [11, 61, 74])
    }

    func testMissingAndUnknownPreferencesRequireSelection() {
        XCTAssertNil(BrandTheme(rawValue: ""))
        XCTAssertNil(BrandTheme(rawValue: "unknown"))
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
