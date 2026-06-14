//
//  WeatherMappingTests.swift
//  TerrariumTests
//
//  US-B1: Unit tests for `WeatherMapping.map(_:)`. We test the mapping table
//  directly, with representative `WeatherCondition` inputs, without needing a
//  WeatherKit entitlement or network. `WeatherKitProvider` wraps the mapping in
//  a do/catch fallback, so the important invariant is that `WeatherMapping` is
//  correct and exhaustive for known inputs.
//
//  Naming note: WeatherKit also exports a type named `Weather`, which collides
//  with the app's `Weather` enum. All references to our enum are qualified as
//  `AppWeather` (a local typealias) so the compiler resolves them unambiguously.
//

import Testing
import WeatherKit
@testable import Terrarium

// WeatherKit exports its own `Weather` type; alias ours to avoid ambiguity.
private typealias AppWeather = Terrarium.Weather

@Suite("WeatherMapping")
struct WeatherMappingTests {

    // MARK: Clear / sunny

    @Test("clear → .clear")
    func clearCondition() {
        #expect(WeatherMapping.map(.clear) == AppWeather.clear)
    }

    @Test("mostlyClear → .clear")
    func mostlyClearCondition() {
        #expect(WeatherMapping.map(.mostlyClear) == AppWeather.clear)
    }

    @Test("hot → .clear")
    func hotCondition() {
        #expect(WeatherMapping.map(.hot) == AppWeather.clear)
    }

    // MARK: Cloudy

    @Test("partlyCloudy → .cloudy")
    func partlyCloudy() {
        #expect(WeatherMapping.map(.partlyCloudy) == AppWeather.cloudy)
    }

    @Test("mostlyCloudy → .cloudy")
    func mostlyCloudy() {
        #expect(WeatherMapping.map(.mostlyCloudy) == AppWeather.cloudy)
    }

    @Test("cloudy → .cloudy")
    func cloudy() {
        #expect(WeatherMapping.map(.cloudy) == AppWeather.cloudy)
    }

    @Test("windy → .cloudy")
    func windy() {
        #expect(WeatherMapping.map(.windy) == AppWeather.cloudy)
    }

    // MARK: Fog

    @Test("foggy → .fog")
    func foggy() {
        #expect(WeatherMapping.map(.foggy) == AppWeather.fog)
    }

    @Test("haze → .fog")
    func haze() {
        #expect(WeatherMapping.map(.haze) == AppWeather.fog)
    }

    @Test("smoky → .fog")
    func smoky() {
        #expect(WeatherMapping.map(.smoky) == AppWeather.fog)
    }

    @Test("blowingDust → .fog")
    func blowingDust() {
        #expect(WeatherMapping.map(.blowingDust) == AppWeather.fog)
    }

    @Test("blowingSnow → .fog (visually fog-like, zero visibility)")
    func blowingSnow() {
        #expect(WeatherMapping.map(.blowingSnow) == AppWeather.fog)
    }

    // MARK: Rain

    @Test("drizzle → .rain")
    func drizzle() {
        #expect(WeatherMapping.map(.drizzle) == AppWeather.rain)
    }

    @Test("rain → .rain")
    func rain() {
        #expect(WeatherMapping.map(.rain) == AppWeather.rain)
    }

    @Test("heavyRain → .rain")
    func heavyRain() {
        #expect(WeatherMapping.map(.heavyRain) == AppWeather.rain)
    }

    @Test("freezingDrizzle → .rain")
    func freezingDrizzle() {
        #expect(WeatherMapping.map(.freezingDrizzle) == AppWeather.rain)
    }

    @Test("freezingRain → .rain")
    func freezingRain() {
        #expect(WeatherMapping.map(.freezingRain) == AppWeather.rain)
    }

    @Test("thunderstorms → .rain")
    func thunderstorms() {
        #expect(WeatherMapping.map(.thunderstorms) == AppWeather.rain)
    }

    @Test("scatteredThunderstorms → .rain")
    func scatteredThunderstorms() {
        #expect(WeatherMapping.map(.scatteredThunderstorms) == AppWeather.rain)
    }

    @Test("strongStorms → .rain")
    func strongStorms() {
        #expect(WeatherMapping.map(.strongStorms) == AppWeather.rain)
    }

    @Test("tropicalStorm → .rain")
    func tropicalStorm() {
        #expect(WeatherMapping.map(.tropicalStorm) == AppWeather.rain)
    }

    @Test("hurricane → .rain")
    func hurricane() {
        #expect(WeatherMapping.map(.hurricane) == AppWeather.rain)
    }

    @Test("hail → .rain")
    func hail() {
        #expect(WeatherMapping.map(.hail) == AppWeather.rain)
    }

    @Test("sleet → .rain")
    func sleet() {
        #expect(WeatherMapping.map(.sleet) == AppWeather.rain)
    }

    @Test("wintryMix → .rain")
    func wintryMix() {
        #expect(WeatherMapping.map(.wintryMix) == AppWeather.rain)
    }

    @Test("sunShowers → .rain")
    func sunShowers() {
        #expect(WeatherMapping.map(.sunShowers) == AppWeather.rain)
    }

    // MARK: Snow

    @Test("snow → .snow")
    func snow() {
        #expect(WeatherMapping.map(.snow) == AppWeather.snow)
    }

    @Test("heavySnow → .snow")
    func heavySnow() {
        #expect(WeatherMapping.map(.heavySnow) == AppWeather.snow)
    }

    @Test("flurries → .snow")
    func flurries() {
        #expect(WeatherMapping.map(.flurries) == AppWeather.snow)
    }

    // MARK: Edge / other

    @Test("frigid → .clear (cold clear day, no precipitation)")
    func frigid() {
        #expect(WeatherMapping.map(.frigid) == AppWeather.clear)
    }

    @Test("breezy → .clear")
    func breezy() {
        #expect(WeatherMapping.map(.breezy) == AppWeather.clear)
    }

    // MARK: Output range

    @Test("All known WeatherConditions map to a valid Weather value")
    func allConditionsMap() {
        // Spot-check the output type — every result must be one of our five cases.
        let validValues: Set<AppWeather> = [.clear, .cloudy, .fog, .rain, .snow]
        let sampleConditions: [WeatherCondition] = [
            .clear, .mostlyClear, .partlyCloudy, .mostlyCloudy, .cloudy,
            .foggy, .haze, .smoky, .blowingDust,
            .drizzle, .rain, .heavyRain, .freezingRain, .thunderstorms, .sleet, .wintryMix, .hail,
            .snow, .heavySnow, .flurries, .blowingSnow,
            .windy, .breezy, .frigid, .hot, .tropicalStorm, .hurricane
        ]
        for condition in sampleConditions {
            #expect(validValues.contains(WeatherMapping.map(condition)),
                    "Unexpected result for \(condition)")
        }
    }
}
