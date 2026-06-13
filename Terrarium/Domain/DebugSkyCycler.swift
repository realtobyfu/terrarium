//
//  DebugSkyCycler.swift
//  Terrarium — Domain
//
//  Debug-only helper that steps SkyState through the four canonical times of
//  day so the dynamic SkyLayer is provably working without real solar/weather
//  data. Wired to a hidden long-press in HomeView.
//

import Foundation

/// The canonical times of day the palette is keyed off of.
enum TimeOfDay: CaseIterable, Equatable {
    case dawn, midday, goldenHour, night

    /// Representative sun elevation for this phase (degrees).
    var sunElevationDegrees: Double {
        switch self {
        case .dawn:       return 2
        case .midday:     return 70
        case .goldenHour: return 6
        case .night:      return -20
        }
    }

    var localTimeLabel: String {
        switch self {
        case .dawn:       return "6:02am"
        case .midday:     return "12:30pm"
        case .goldenHour: return "6:48pm"
        case .night:      return "11:15pm"
        }
    }
}

/// Steps a SkyState through dawn → midday → goldenHour → night → dawn …
/// Pure and deterministic so it is trivially testable.
struct DebugSkyCycler {
    /// Produces the next state, advancing one step around the cycle while
    /// preserving `weather` and `locationName`.
    func next(after state: SkyState) -> SkyState {
        let current = Self.timeOfDay(forElevation: state.sunElevationDegrees,
                                     label: state.localTimeLabel)
        let all = TimeOfDay.allCases
        let idx = all.firstIndex(of: current) ?? 0
        let nextTOD = all[(idx + 1) % all.count]
        return SkyState(
            sunElevationDegrees: nextTOD.sunElevationDegrees,
            weather: state.weather,
            locationName: state.locationName,
            localTimeLabel: nextTOD.localTimeLabel
        )
    }

    /// Classify an arbitrary SkyState back onto the cycle. We disambiguate
    /// dawn vs golden hour (both low, positive elevations) using the time label.
    static func timeOfDay(forElevation elevation: Double, label: String) -> TimeOfDay {
        if elevation < 0 { return .night }
        if elevation >= 30 { return .midday }
        // Low positive elevation: morning labels → dawn, otherwise golden hour.
        let lowered = label.lowercased()
        if lowered.contains("am") { return .dawn }
        return .goldenHour
    }
}
