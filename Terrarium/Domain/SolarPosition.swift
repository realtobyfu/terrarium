//
//  SolarPosition.swift
//  Terrarium — Domain
//
//  Pure-Swift solar position (NOAA approximation). Given a UTC instant and a
//  geographic coordinate it returns the sun's elevation and azimuth in degrees.
//  No CoreLocation / device dependency, so it is fully unit-testable and lets
//  the sky reflect real local time even with no network or location permission.
//

import Foundation

enum SolarPosition {

    struct Result: Equatable {
        /// Degrees above the horizon (negative = below).
        let elevationDegrees: Double
        /// Degrees clockwise from true north (0...360).
        let azimuthDegrees: Double
    }

    /// NOAA solar position algorithm. `longitude` is degrees east (west < 0).
    static func compute(date: Date, latitude: Double, longitude: Double) -> Result {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let dc = cal.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                    from: date)
        let year = dc.year!, month = dc.month!, day = dc.day!
        let hour = Double(dc.hour!), minute = Double(dc.minute!), second = Double(dc.second!)

        // Julian Day / Century.
        var Y = Double(year), M = Double(month)
        if M <= 2 { Y -= 1; M += 12 }
        let A = floor(Y / 100)
        let B = 2 - A + floor(A / 4)
        let dayFraction = (hour + minute / 60 + second / 3600) / 24
        let jd = floor(365.25 * (Y + 4716)) + floor(30.6001 * (M + 1))
            + Double(day) + B - 1524.5 + dayFraction
        let t = (jd - 2451545.0) / 36525.0

        // Sun's mean longitude / anomaly, orbit eccentricity.
        let l0 = mod360(280.46646 + t * (36000.76983 + 0.0003032 * t))
        let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        let mRad = rad(m)
        let c = sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * mRad) * (0.019993 - 0.000101 * t)
            + sin(3 * mRad) * 0.000289

        let trueLong = l0 + c
        let appLong = trueLong - 0.00569 - 0.00478 * sin(rad(125.04 - 1934.136 * t))

        let meanObliq = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliqCorr = meanObliq + 0.00256 * cos(rad(125.04 - 1934.136 * t))

        let declination = deg(asin(sin(rad(obliqCorr)) * sin(rad(appLong))))

        // Equation of time (minutes).
        let y = pow(tan(rad(obliqCorr / 2)), 2)
        let eqTime = 4 * deg(
            y * sin(2 * rad(l0))
            - 2 * e * sin(mRad)
            + 4 * e * y * sin(mRad) * cos(2 * rad(l0))
            - 0.5 * y * y * sin(4 * rad(l0))
            - 1.25 * e * e * sin(2 * mRad)
        )

        // True solar time (minutes) in UTC, longitude-corrected.
        let minutesUTC = hour * 60 + minute + second / 60
        let trueSolarTime = (minutesUTC + eqTime + 4 * longitude).truncatingRemainder(dividingBy: 1440)
        let normalizedTST = trueSolarTime < 0 ? trueSolarTime + 1440 : trueSolarTime

        // Hour angle (degrees, -180...180).
        let hourAngle = normalizedTST / 4 - 180

        let latRad = rad(latitude)
        let decRad = rad(declination)
        let haRad = rad(hourAngle)

        let cosZenith = sin(latRad) * sin(decRad)
            + cos(latRad) * cos(decRad) * cos(haRad)
        let zenith = acos(max(-1, min(1, cosZenith)))
        let elevation = 90 - deg(zenith)

        // Azimuth (clockwise from north).
        let denom = cos(latRad) * sin(zenith)
        var azimuth: Double
        if abs(denom) < 1e-9 {
            azimuth = hourAngle > 0 ? 180 : 0
        } else {
            let cosAz = (sin(latRad) * cos(zenith) - sin(decRad)) / denom
            let azAcos = deg(acos(max(-1, min(1, cosAz))))
            azimuth = hourAngle > 0 ? mod360(azAcos + 180) : mod360(540 - azAcos)
        }

        return Result(elevationDegrees: elevation, azimuthDegrees: azimuth)
    }

    // MARK: - Helpers

    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }
    private static func mod360(_ x: Double) -> Double {
        let r = x.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }
}
