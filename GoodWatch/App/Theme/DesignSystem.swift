import SwiftUI

// MARK: - GoodWatch Design System
// Premium dark theme with gold accents

enum GWColors {
    // Base Palette
    static let black = Color(hex: "0A0A0A")           // Background
    static let darkGray = Color(hex: "1C1C1E")        // Surfaces
    static let white = Color.white                     // Primary text
    static let lightGray = Color(hex: "8E8E93")       // Secondary text
    static let gold = Color(hex: "D4AF37")            // ONLY for GoodScore + Primary CTA

    // Support Colors
    static let overlay = Color.black.opacity(0.75)
    static let surfaceBorder = Color.white.opacity(0.1)
}

enum GWTypography {
    // Score - 64px bold (GoodScore number only)
    static func score() -> Font {
        .system(size: 64, weight: .bold, design: .rounded)
    }

    // Title - 28px bold
    static func title() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }

    // Headline - 24px semibold
    static func headline() -> Font {
        .system(size: 24, weight: .semibold, design: .rounded)
    }

    // Button - 18px semibold
    static func button() -> Font {
        .system(size: 18, weight: .semibold, design: .rounded)
    }

    // Body - 16px regular/medium
    static func body(weight: Font.Weight = .regular) -> Font {
        .system(size: 16, weight: weight, design: .rounded)
    }

    // Small - 14px
    static func small(weight: Font.Weight = .regular) -> Font {
        .system(size: 14, weight: weight, design: .rounded)
    }

    // Tiny - 12px
    static func tiny(weight: Font.Weight = .semibold) -> Font {
        .system(size: 12, weight: weight, design: .rounded)
    }
}

enum GWSpacing {
    static let screenPadding: CGFloat = 24
    static let elementGap: CGFloat = 16
    static let sectionGap: CGFloat = 32
}

enum GWRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let full: CGFloat = 9999
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Gold Gradient for CTA
extension LinearGradient {
    static var goldGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "D4AF37"),
                Color(hex: "C9A227")
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
