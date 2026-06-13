//
//  Tokens.swift
//  Terrarium — DesignSystem
//
//  Color / radius / type tokens matching the agreed mockup. No business logic.
//

import SwiftUI

extension Color {
    /// Hex initializer (RGB, 6 digits). Falls back to black on bad input.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

/// Design tokens. Namespaced under `Theme` to keep call sites legible.
enum Theme {
    enum Palette {
        // Accent / crystal
        static let accent       = Color(hex: "2A9D8F")
        static let atmosphere    = Color(hex: "9FE8EF")

        // Surfaces (cream)
        static let cardSurface  = Color(hex: "FFF8EE")
        static let chipSurface  = Color(hex: "FBF2E0")
        static let cardBorder   = Color(hex: "ECD2AB")

        // Text
        static let title        = Color(hex: "56392C")
        static let secondary    = Color(hex: "917A64")
        static let label        = Color(hex: "B08A66")
    }

    enum Radius {
        static let card: CGFloat  = 18
        static let chip: CGFloat  = 12
        static let panel: CGFloat = 16
    }

    enum Spacing {
        static let s: CGFloat  = 8
        static let m: CGFloat  = 12
        static let l: CGFloat  = 16
        static let xl: CGFloat = 24
    }

    enum Typography {
        /// Serif display for wordmark + quest titles.
        static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .serif)
        }
        /// Rounded sans for body + labels.
        static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
    }
}
