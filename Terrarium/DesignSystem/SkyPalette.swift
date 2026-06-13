//
//  SkyPalette.swift
//  Terrarium — DesignSystem
//
//  Pure mapping from SkyState to a vertical gradient (top→bottom).
//  All math is deterministic and view-free so it can be unit tested without
//  a device: `stops(for:)` returns plain RGB triples; `gradient(for:)` wraps
//  them into SwiftUI. `weather` modulates the base palette via pure functions.
//

import SwiftUI

enum SkyPalette {

    /// A device-independent RGB stop. Equatable for deterministic tests.
    struct Stop: Equatable {
        var red: Double
        var green: Double
        var blue: Double

        init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        /// Build from a 6-digit hex string.
        init(hex: String) {
            let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            var value: UInt64 = 0
            Scanner(string: cleaned).scanHexInt64(&value)
            self.red = Double((value & 0xFF0000) >> 16) / 255
            self.green = Double((value & 0x00FF00) >> 8) / 255
            self.blue = Double(value & 0x0000FF) / 255
        }

        var color: Color {
            Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
        }

        /// Perceptual-ish luminance (Rec. 601).
        var luminance: Double {
            0.299 * red + 0.587 * green + 0.114 * blue
        }
    }

    // MARK: - Base palettes (top → bottom)

    static func baseStops(for tod: TimeOfDay) -> [Stop] {
        switch tod {
        case .dawn:
            return ["C9B6E0", "F0BCB6", "FBE6C2"].map(Stop.init(hex:))
        case .midday:
            return ["5AA6E8", "A9D2F2", "E6F3FB"].map(Stop.init(hex:))
        case .goldenHour:
            return ["93ACD8", "D3A3BD", "F5CB9C", "FCE4C4"].map(Stop.init(hex:))
        case .night:
            // Deep, dark night so the background reads as truly nighttime.
            return ["020109", "060616", "0C0B26"].map(Stop.init(hex:))
        }
    }

    // MARK: - Public mapping

    /// The modulated stop set for a given sky state.
    static func stops(for sky: SkyState) -> [Stop] {
        let tod = DebugSkyCycler.timeOfDay(forElevation: sky.sunElevationDegrees,
                                           label: sky.localTimeLabel)
        let base = baseStops(for: tod)
        return modulate(base, for: sky.weather, night: tod == .night)
    }

    /// The SwiftUI gradient for a given sky state (top → bottom).
    static func gradient(for sky: SkyState) -> LinearGradient {
        LinearGradient(
            colors: stops(for: sky).map(\.color),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Whether it is night (sun below the horizon).
    static func isNight(for sky: SkyState) -> Bool {
        DebugSkyCycler.timeOfDay(forElevation: sky.sunElevationDegrees,
                                 label: sky.localTimeLabel) == .night
    }

    /// Stars (and shooting stars) appear at night, in any weather. Pure
    /// predicate so the view can stay dumb.
    static func showsStars(for sky: SkyState) -> Bool {
        isNight(for: sky)
    }

    // MARK: - Weather modulation (pure)

    private static func modulate(_ stops: [Stop], for weather: Weather, night: Bool) -> [Stop] {
        switch weather {
        case .clear:
            return stops
        case .fog:
            // Lower contrast then lighten — but only gently at night, so a foggy
            // night still reads as dark rather than washing out to grey.
            return lighten(lowerContrast(stops, by: night ? 0.25 : 0.45),
                           toward: night ? 0.08 : 0.30)
        case .snow:
            return lighten(stops, toward: night ? 0.10 : 0.35)
        case .cloudy:
            return desaturate(stops, by: 0.45)
        case .rain:
            return desaturate(stops, by: 0.65)
        }
    }

    /// Blend every stop toward the set's mean color by `amount` (0...1).
    private static func lowerContrast(_ stops: [Stop], by amount: Double) -> [Stop] {
        guard !stops.isEmpty else { return stops }
        let mean = Stop(
            red: stops.map(\.red).reduce(0, +) / Double(stops.count),
            green: stops.map(\.green).reduce(0, +) / Double(stops.count),
            blue: stops.map(\.blue).reduce(0, +) / Double(stops.count)
        )
        return stops.map { blend($0, toward: mean, amount: amount) }
    }

    /// Blend every stop toward white by `amount` (0...1).
    private static func lighten(_ stops: [Stop], toward amount: Double) -> [Stop] {
        let white = Stop(red: 1, green: 1, blue: 1)
        return stops.map { blend($0, toward: white, amount: amount) }
    }

    /// Pull every stop toward its own grayscale luminance by `amount` (0...1).
    private static func desaturate(_ stops: [Stop], by amount: Double) -> [Stop] {
        stops.map { stop in
            let gray = Stop(red: stop.luminance, green: stop.luminance, blue: stop.luminance)
            return blend(stop, toward: gray, amount: amount)
        }
    }

    private static func blend(_ a: Stop, toward b: Stop, amount t: Double) -> Stop {
        Stop(
            red: a.red + (b.red - a.red) * t,
            green: a.green + (b.green - a.green) * t,
            blue: a.blue + (b.blue - a.blue) * t
        )
    }
}
