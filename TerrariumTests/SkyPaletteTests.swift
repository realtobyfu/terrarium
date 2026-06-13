//
//  SkyPaletteTests.swift
//  TerrariumTests
//
//  Pure mapping from SkyState → gradient stops. No views instantiated.
//

import Testing
@testable import Terrarium

@Suite("SkyPalette")
struct SkyPaletteTests {

    /// A representative SkyState for each time of day (clear weather so the
    /// modulated output equals the base palette).
    private func clearSky(_ elevation: Double, _ label: String) -> SkyState {
        SkyState(sunElevationDegrees: elevation,
                 weather: .clear,
                 locationName: "SF",
                 localTimeLabel: label)
    }

    @Test("Each time of day maps to its base palette under clear weather",
          arguments: [
            (TimeOfDay.dawn, 2.0, "6:02am", 3),
            (TimeOfDay.midday, 70.0, "12:30pm", 3),
            (TimeOfDay.goldenHour, 6.0, "6:48pm", 4),
            (TimeOfDay.night, -20.0, "11:15pm", 3),
          ])
    func baseStopsForClearWeather(tod: TimeOfDay,
                                  elevation: Double,
                                  label: String,
                                  expectedCount: Int) throws {
        let sky = clearSky(elevation, label)
        let stops = SkyPalette.stops(for: sky)
        #expect(stops == SkyPalette.baseStops(for: tod))
        #expect(stops.count == expectedCount)
    }

    @Test("Golden hour's first stop matches the locked token #93ACD8")
    func goldenHourFirstStop() throws {
        let stops = SkyPalette.baseStops(for: .goldenHour)
        let first = try #require(stops.first)
        #expect(first == SkyPalette.Stop(hex: "93ACD8"))
    }

    @Test("Fog modulation changes the output deterministically")
    func fogModulation() {
        let clear = clearSky(6, "6:48pm")
        let foggy = SkyState(sunElevationDegrees: 6, weather: .fog,
                             locationName: "SF", localTimeLabel: "6:48pm")
        let clearStops = SkyPalette.stops(for: clear)
        let foggyStops = SkyPalette.stops(for: foggy)
        #expect(foggyStops != clearStops)
        // Deterministic: same input → same output.
        #expect(SkyPalette.stops(for: foggy) == foggyStops)
    }

    @Test("Rain modulation desaturates and differs from clear")
    func rainModulation() {
        let clear = clearSky(70, "12:30pm")
        let rainy = SkyState(sunElevationDegrees: 70, weather: .rain,
                             locationName: "SF", localTimeLabel: "12:30pm")
        #expect(SkyPalette.stops(for: rainy) != SkyPalette.stops(for: clear))
    }

    @Test("Stars appear at night in any weather, never during the day")
    func starVisibility() {
        let clearNight = clearSky(-20, "11:15pm")
        let foggyNight = SkyState(sunElevationDegrees: -20, weather: .fog,
                                  locationName: "SF", localTimeLabel: "11:15pm")
        let clearDay = clearSky(70, "12:30pm")
        #expect(SkyPalette.showsStars(for: clearNight))
        #expect(SkyPalette.showsStars(for: foggyNight))
        #expect(!SkyPalette.showsStars(for: clearDay))
    }
}
