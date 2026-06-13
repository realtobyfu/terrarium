//
//  SolarSkyStateProviderTests.swift
//  TerrariumTests
//
//  The real sky provider composes solar elevation + a formatted local time,
//  deterministically given an injected clock.
//

import Testing
import Foundation
@testable import Terrarium

@Suite("SolarSkyStateProvider")
struct SolarSkyStateProviderTests {

    private func fixedDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    @Test("current() elevation matches the solar calc for the same instant")
    func elevationMatchesSolarCalc() {
        let date = fixedDate(2025, 6, 21, 20, 0) // 20:00 UTC = ~1pm PDT
        let provider = SolarSkyStateProvider(now: { date })
        let sky = provider.current()
        let expected = SolarPosition.compute(date: date,
                                             latitude: 37.7749, longitude: -122.4194)
        #expect(abs(sky.sunElevationDegrees - expected.elevationDegrees) < 1e-9)
        #expect(sky.locationName == "SF")
        #expect(sky.weather == .fog)
    }

    @Test("local time label is formatted in the provider's timezone")
    func timeLabelFormatting() {
        // 02:30 UTC → 19:30 (7:30pm) previous day in PDT.
        let date = fixedDate(2025, 6, 21, 2, 30)
        let label = SolarSkyStateProvider.timeLabel(
            for: date, in: TimeZone(identifier: "America/Los_Angeles")!
        )
        #expect(label == "7:30pm")
    }

    @Test("Sun is below the horizon at local midnight, above at local noon")
    func dayNightDiffers() {
        let tz = TimeZone(identifier: "America/Los_Angeles")!
        // 09:00 UTC ≈ 2am PDT (night); 20:00 UTC ≈ 1pm PDT (day).
        let night = SolarSkyStateProvider(timeZone: tz,
                                          now: { self.fixedDate(2025, 6, 21, 9, 0) }).current()
        let day = SolarSkyStateProvider(timeZone: tz,
                                        now: { self.fixedDate(2025, 6, 21, 20, 0) }).current()
        #expect(night.sunElevationDegrees < 0)
        #expect(day.sunElevationDegrees > 0)
    }
}
