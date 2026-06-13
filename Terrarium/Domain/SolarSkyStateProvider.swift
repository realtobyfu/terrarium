//
//  SolarSkyStateProvider.swift
//  Terrarium — Domain
//
//  Real (non-stub) sky: drives SkyState from the actual current time + the
//  NOAA solar position calc, so the gradient and world lighting track the real
//  sun. Location and weather degrade gracefully:
//    • no location permission → falls back to a default coordinate (§F).
//    • no WeatherKit          → falls back to a default condition.
//
//  CoreLocation + WeatherKit + CLGeocoder wiring is layered on top via an async
//  refresh that updates `coordinate` / `weather` / `locationName`.
//  // TODO(Phase 2 Loop 2 cont.): wire CLLocationManager (reducedAccuracy),
//  //   WeatherKit current condition, and CLGeocoder reverse-geocode here.
//

import Foundation

struct SolarSkyStateProvider: SkyStateProviding {

    /// Geographic coordinate used for the solar calc (degrees, east positive).
    var latitude: Double
    var longitude: Double
    /// Timezone used to render the local time label.
    var timeZone: TimeZone
    /// Short place label shown in the LocationChip.
    var locationName: String
    /// Current condition; defaults until WeatherKit is wired.
    var weather: Weather
    /// Injectable clock for deterministic tests.
    var now: () -> Date

    /// Defaults to coarse San Francisco so the app is fully functional offline
    /// and with location denied.
    init(latitude: Double = 37.7749,
         longitude: Double = -122.4194,
         timeZone: TimeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current,
         locationName: String = "SF",
         weather: Weather = .fog,
         now: @escaping () -> Date = Date.init) {
        self.latitude = latitude
        self.longitude = longitude
        self.timeZone = timeZone
        self.locationName = locationName
        self.weather = weather
        self.now = now
    }

    func current() -> SkyState {
        let date = now()
        let sun = SolarPosition.compute(date: date, latitude: latitude, longitude: longitude)
        return SkyState(
            sunElevationDegrees: sun.elevationDegrees,
            weather: weather,
            locationName: locationName,
            localTimeLabel: Self.timeLabel(for: date, in: timeZone)
        )
    }

    /// "6:48pm" style label.
    static func timeLabel(for date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "h:mma"
        return formatter.string(from: date).lowercased()
    }
}
