//
//  SkyLightingTests.swift
//  TerrariumTests
//
//  Pure SkyState → sun-light mapping. No RealityKit instantiated.
//

import Testing
import simd
@testable import Terrarium

@Suite("Sky → light mapping")
struct SkyLightingTests {

    private func sky(_ elevation: Double, _ label: String, _ weather: Weather = .clear) -> SkyState {
        SkyState(sunElevationDegrees: elevation, weather: weather,
                 locationName: "SF", localTimeLabel: label)
    }

    @Test("Golden hour: warm colour, low sun angle")
    func goldenHour() {
        let c = WorldLighting.keyConfig(for: sky(6, "6:48pm"))
        // Warmer in red than blue.
        #expect(c.color.x > c.color.z)
        // Sun just above the horizon → small positive elevation component.
        #expect(c.sunDirection.y > 0)
        #expect(c.sunDirection.y < 0.3)
    }

    @Test("Midday: bright, neutral, high sun")
    func midday() {
        let c = WorldLighting.keyConfig(for: sky(70, "12:30pm"))
        #expect(c.intensity > 3000)
        #expect(c.sunDirection.y > 0.8)
        // Neutral: red and blue close together.
        #expect(abs(c.color.x - c.color.z) < 0.1)
    }

    @Test("Night: cool colour, dim, below horizon")
    func night() {
        let c = WorldLighting.keyConfig(for: sky(-20, "11:15pm"))
        #expect(c.color.z > c.color.x)        // cooler
        #expect(c.intensity < 700)             // dim
        #expect(c.sunDirection.y < 0)          // below horizon
    }

    @Test("Intensity rises monotonically with sun elevation")
    func intensityMonotonic() {
        let elevations = [-30.0, -6.0, 5.0, 20.0, 45.0, 80.0]
        let intensities = elevations.map {
            WorldLighting.keyConfig(for: sky($0, "12:00pm")).intensity
        }
        for i in 1..<intensities.count {
            #expect(intensities[i] >= intensities[i - 1])
        }
    }

    @Test("Sun direction is a unit vector")
    func unitDirection() {
        for e in [-20.0, 0.0, 30.0, 90.0] {
            let c = WorldLighting.keyConfig(for: sky(e, "12:00pm"))
            #expect(abs(simd_length(c.sunDirection) - 1) < 1e-4)
        }
    }
}
