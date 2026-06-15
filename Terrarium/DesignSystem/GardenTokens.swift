//
//  DiscoveryGlassTokens.swift
//  Terrarium — Prototypes
//
//  Token extensions for the "Magical Discovery / The Hidden Garden" prototype.
//  These EXTEND the existing `Theme` (Tokens.swift) — they do not replace it.
//  The cream/brown identity stays; we layer a moss "garden" palette pulled from
//  the discovery mockup plus a couple of larger radii for the editorial hero card.
//
//  Pure values only — no logic, no state. Mirrors Tokens.swift discipline.
//

import SwiftUI

extension Theme {

    /// "Hidden Garden" discovery palette — the moss/leaf greens from the mockup,
    /// living alongside `Theme.Palette` (accent teal · cream · brown).
    enum Garden {
        /// Primary CTA fill (mockup `primary`).
        static let moss          = Color(hex: "455528")
        /// Tactile bottom edge / pressed shade (mockup `on-primary-fixed-variant`).
        static let mossDeep      = Color(hex: "3D4C20")
        /// Lighter moss for gradients (mockup `primary-container`).
        static let mossLight     = Color(hex: "5D6D3E")
        /// Selected/leaf accent (mockup `primary-fixed-dim`).
        static let leaf          = Color(hex: "BBCD96")
        /// Pale leaf fill (mockup `primary-fixed`).
        static let leafFixed     = Color(hex: "D7EAB0")
        /// Deep pine (mockup `tertiary`) — the rewarding "arrival" accent.
        static let pine          = Color(hex: "2F5749")
        static let pineLight     = Color(hex: "476F60")
        /// Pale mint (mockup `tertiary-fixed`).
        static let mint          = Color(hex: "C0ECDA")
        /// Warm bloom (mockup `secondary-container`) for warm-mood pills.
        static let bloom         = Color(hex: "FEBB8E")
        static let petal         = Color(hex: "FFDCC6")
    }
}

extension Theme.Spacing {
    /// Fine 4pt step (the base scale starts at `s` = 8).
    static let xs: CGFloat = 4
}

extension Theme.Radius {
    /// Editorial discovery card (the tactile "island").
    static let hero: CGFloat      = 28
    /// Image well inside the hero card.
    static let heroInner: CGFloat = 22
    /// Floating glass panels (top bar, overlay name card, state cards).
    static let glass: CGFloat     = 24
}
