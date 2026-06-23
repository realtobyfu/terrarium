//
//  TransportMode.swift
//  Terrarium — Domain
//
//  The user's preferred way of getting to a place. Captured during onboarding
//  (and editable in Settings), it drives the distance/ETA shown on the Anchor
//  destination card.
//
//  Design notes:
//  - Pure value type: Foundation only, no MapKit. The `MKDirectionsTransportType`
//    mapping lives in `AnchorViewModel` (the only place that needs MapKit) so the
//    Domain layer stays dependency-free.
//  - Deliberately NOT part of `UserPreferences` (the frozen `ExploreModels.swift`
//    contract): transport mode does not feed the ranker, so it is persisted on its
//    own `PreferencesStore` key instead.
//  - `metersPerSecond` provides an offline fallback estimate when a real
//    `MKDirections` ETA is unavailable (offline, rate-limited, or — for cycling —
//    unsupported by Apple's routing).
//

import Foundation

/// How the user prefers to reach a recommended place.
enum TransportMode: String, Codable, CaseIterable, Equatable {
    case walk
    case cycle
    case transit
    case drive

    /// Sensible default for first launch and any decode failure.
    static let `default`: TransportMode = .walk

    /// Rough average speed used for the offline ETA estimate (m/s). These are
    /// door-to-door ballparks, not free-flow speeds — transit/drive bake in stops
    /// and city pace so the estimate reads sensibly without a routing call.
    var metersPerSecond: Double {
        switch self {
        case .walk:    return 1.4   // ~5 km/h
        case .cycle:   return 4.2   // ~15 km/h
        case .transit: return 8.0   // ~29 km/h, includes waits/stops
        case .drive:   return 11.0  // ~40 km/h city driving
        }
    }

    /// Short display label for chips and captions.
    var label: String {
        switch self {
        case .walk:    return "Walk"
        case .cycle:   return "Cycle"
        case .transit: return "Transit"
        case .drive:   return "Drive"
        }
    }

    /// SF Symbol used on the picker chips and the destination-card pill.
    var systemImage: String {
        switch self {
        case .walk:    return "figure.walk"
        case .cycle:   return "bicycle"
        case .transit: return "tram.fill"
        case .drive:   return "car.fill"
        }
    }

    /// Verb tail for the ETA label, e.g. "~10 min walk" / "~10 min by transit".
    var verb: String {
        switch self {
        case .walk:    return "walk"
        case .cycle:   return "ride"
        case .transit: return "by transit"
        case .drive:   return "drive"
        }
    }

    /// One-line caption shown above the value on the ticket-style card.
    var ticketCaption: String {
        switch self {
        case .walk:    return "ON FOOT"
        case .cycle:   return "BY BIKE"
        case .transit: return "BY TRANSIT"
        case .drive:   return "BY CAR"
        }
    }
}
