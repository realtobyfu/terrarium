//
//  SolarPositionTests.swift
//  TerrariumTests
//
//  Pure NOAA solar-position checks. We test peak (solar-noon) altitude over a
//  day, which is implementation-independent and has known physical values.
//

import Testing
import Foundation
@testable import Terrarium

@Suite("Solar position")
struct SolarPositionTests {

    private func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    /// Maximum elevation across a full day = solar-noon altitude.
    private func peakElevation(date: Date, latitude: Double, longitude: Double) -> SolarPosition.Result {
        var best = SolarPosition.Result(elevationDegrees: -100, azimuthDegrees: 0)
        for step in stride(from: 0, to: 24 * 60, by: 5) {
            let t = date.addingTimeInterval(Double(step) * 60)
            let r = SolarPosition.compute(date: t, latitude: latitude, longitude: longitude)
            if r.elevationDegrees > best.elevationDegrees { best = r }
        }
        return best
    }

    @Test("Equinox noon altitude ≈ 90 − |latitude|",
          arguments: [0.0, 40.0, -33.0])
    func equinoxNoonAltitude(latitude: Double) {
        // ~March equinox 2025.
        let peak = peakElevation(date: utc(2025, 3, 20), latitude: latitude, longitude: 0)
        #expect(abs(peak.elevationDegrees - (90 - abs(latitude))) < 2.0)
    }

    @Test("Northern summer solstice noon altitude rises by obliquity")
    func summerSolsticeAltitude() {
        let lat = 40.0
        let peak = peakElevation(date: utc(2025, 6, 21), latitude: lat, longitude: -105)
        // 90 − lat + 23.44
        #expect(abs(peak.elevationDegrees - (90 - lat + 23.44)) < 1.5)
    }

    @Test("Northern winter solstice noon altitude drops by obliquity")
    func winterSolsticeAltitude() {
        let lat = 40.0
        let peak = peakElevation(date: utc(2025, 12, 21), latitude: lat, longitude: -105)
        // 90 − lat − 23.44
        #expect(abs(peak.elevationDegrees - (90 - lat - 23.44)) < 1.5)
    }

    @Test("At solar noon the sun is due south in the northern hemisphere")
    func noonAzimuthSouth() {
        let peak = peakElevation(date: utc(2025, 3, 20), latitude: 40, longitude: -105)
        #expect(abs(peak.azimuthDegrees - 180) < 3.0)
    }

    @Test("Elevation stays within [−90, 90] and azimuth within [0, 360]")
    func ranges() {
        for h in stride(from: 0, to: 24, by: 1) {
            let r = SolarPosition.compute(date: utc(2025, 9, 1, h), latitude: 51.5, longitude: 0)
            #expect(r.elevationDegrees >= -90 && r.elevationDegrees <= 90)
            #expect(r.azimuthDegrees >= 0 && r.azimuthDegrees <= 360)
        }
    }
}
