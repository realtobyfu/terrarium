//
//  WeatherKitProvider.swift
//  Terrarium — Domain
//
//  US-B1 (FR-5): Real weather signal via WeatherKit, mapped onto the existing
//  `Weather` enum. The mapping is a pure, stateless function isolated in
//  `WeatherMapping` so it can be unit-tested without a WeatherKit entitlement
//  or network. The provider itself wraps the async fetch in do/catch and falls
//  back to `.clear` on any failure — the app must never block UI, never throw,
//  even when the entitlement is absent (deploy concern, not a code concern).
//
//  DEPLOY NOTE: WeatherKit requires
//    1. The WeatherKit capability enabled in the App ID on developer.apple.com.
//    2. "WeatherKit" added to the target's Capabilities tab in Xcode.
//  In builds without that entitlement the fetch always throws and the provider
//  returns the fallback. The unit tests exercise only `WeatherMapping` and never
//  call WeatherKit, so they compile and pass in any environment.
//

import Foundation
import WeatherKit
import CoreLocation

// MARK: - Condition → Weather mapping (pure, testable)

/// Pure mapping layer: WeatherKit conditions → our `Weather` enum.
/// Isolated in its own type so it can be tested without a device or entitlement.
enum WeatherMapping {

    // MARK: Public API

    /// Map a WeatherKit `WeatherCondition` to the app's `Weather` enum.
    ///
    /// Design decisions:
    /// - Fog-family conditions → `.fog` (matches SF's characteristic Karl).
    /// - Precipitation conditions → `.rain` unless they are clearly snow-class.
    /// - Snow-class conditions → `.snow`.
    /// - Heavy overcast without precip → `.cloudy`.
    /// - Everything unambiguously clear/sunny → `.clear`.
    /// - Unrecognised values (future WeatherKit additions) → `.clear` (safe default).
    static func map(_ condition: WeatherCondition) -> Weather {
        switch condition {
        // Clear / sunny
        case .clear, .mostlyClear, .hot:
            return .clear

        // Partly cloudy shades — lean clear so the sky still feels bright
        case .partlyCloudy, .mostlyCloudy:
            return .cloudy

        // Heavy overcast without precipitation
        case .cloudy, .windy:
            return .cloudy

        // Fog family (Karl the Fog deserves its own case)
        case .foggy, .haze, .smoky:
            return .fog

        // Dust / blowing dust — visually similar to fog
        case .blowingDust, .blowingSnow:
            return .fog

        // Drizzle / light rain
        case .drizzle, .sunShowers:
            return .rain

        // Standard rain
        case .rain, .heavyRain, .freezingDrizzle, .freezingRain:
            return .rain

        // Thunderstorm varieties → rain (no dedicated thunder enum in Weather)
        case .thunderstorms, .scatteredThunderstorms, .isolatedThunderstorms,
             .strongStorms, .tropicalStorm:
            return .rain

        // Sleet / wintry mix — precipitation but borderline; map to rain
        case .sleet, .wintryMix:
            return .rain

        // Pure snow conditions
        case .snow, .heavySnow, .flurries:
            return .snow

        // Frigid / ice without active precipitation → clear (cold clear day)
        case .frigid, .breezy:
            return .clear

        // Hurricane — extreme but map to rain (closest analog)
        case .hurricane:
            return .rain

        // Hail → rain
        case .hail:
            return .rain

        // Catch-all: future WeatherKit enum cases default to clear
        @unknown default:
            return .clear
        }
    }
}

// MARK: - Provider

/// Concrete `WeatherProviding` that fetches live data from WeatherKit.
///
/// `current()` returns the mapped `Weather` synchronously from the caller's
/// async context. On any failure (entitlement absent, network error, unknown
/// location) it returns the `fallback` value — default `.clear` — so the UI
/// is never blocked and never crashes.
struct WeatherKitProvider: WeatherProviding {

    // MARK: Configuration

    /// The location used for the weather fetch. Defaults to San Francisco
    /// (the pilot city). In production this should be the user's current
    /// location; the assembler (US-B3) can create a provider bound to the
    /// session coordinate.
    let location: CLLocation

    /// Returned on any fetch failure (entitlement missing, network offline, etc.)
    let fallback: Weather

    // MARK: Init

    init(
        location: CLLocation = CLLocation(latitude: 37.7749, longitude: -122.4194),
        fallback: Weather = .clear
    ) {
        self.location = location
        self.fallback = fallback
    }

    // MARK: WeatherProviding

    /// Fetches current weather from WeatherKit and maps the condition to
    /// `Weather`. Never throws; returns `fallback` on any error.
    func current() async -> Weather {
        do {
            let service = WeatherService.shared
            let weather = try await service.weather(for: location)
            return WeatherMapping.map(weather.currentWeather.condition)
        } catch {
            // WeatherKit entitlement absent, network failure, rate-limit, etc.
            // Fall through to the fallback so the UI always has a value.
            return fallback
        }
    }
}
