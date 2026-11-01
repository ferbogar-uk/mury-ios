import SwiftUI
import UIKit

enum MuryTypography {
    enum Weight: String {
        case regular = "Rubik-Regular"
        case semibold = "Rubik-SemiBold"
        case bold = "Rubik-Bold"
    }

    static func font(_ style: Font.TextStyle, size: CGFloat, weight: Weight = .regular) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }

    // Export canvases use fixed pixel sizes; on-screen text scales through relativeTo.
    static func uiFont(size: CGFloat, weight: Weight = .regular) -> UIFont {
        UIFont(name: weight.rawValue, size: size) ?? UIFont.systemFont(ofSize: size)
    }
}
