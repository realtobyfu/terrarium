//
//  SpecimenMapping.swift
//  Terrarium — Domain
//
//  Pure mapping layer (US-F2, FR-21). Two responsibilities:
//
//  1. `kind(for:)` — maps a `POICategory` to a `WorldProp.Kind` per the pilot
//     contract (park/viewpoint → tree; coffee/restaurant/bookstore/market/
//     museum/bar → building; other → flowers).
//
//  2. `variant(for:)` — maps a `Weather` value to a specimen variant string key
//     (fog → "foggy"; everything else → "clear"). The variant is stored on
//     `WorldPropRecord` and consumed by `SpecimenFactory` to apply a subtle
//     visual difference (desaturated / paler foliage for foggy specimens).
//
//  Both functions are pure and deterministic — no device reads, no state,
//  safe to unit-test without any simulator.
//

import Foundation

enum SpecimenMapping {

    // MARK: - Category → kind (FR-21)

    /// Returns the `WorldProp.Kind` that a POI category grows in the terrarium.
    ///
    /// Pilot mapping (locked):
    /// - `park`, `viewpoint`                                     → `.tree`
    /// - `coffee`, `restaurant`, `bookstore`, `market`,
    ///   `museum`, `bar`                                          → `.building`
    /// - `other`                                                  → `.flowers`
    static func kind(for category: POICategory) -> WorldProp.Kind {
        switch category {
        case .park, .viewpoint:
            return .tree
        case .coffee, .restaurant, .bookstore, .market, .museum, .bar:
            return .building
        case .other:
            return .flowers
        }
    }

    // MARK: - Weather → variant string (decisions.md #5)

    /// Returns the specimen variant key for a given weather condition.
    ///
    /// Pilot ships 2 variants:
    /// - `.fog`      → `"foggy"`   (desaturated / paler appearance)
    /// - everything  → `"clear"`   (default vivid look)
    static func variant(for weather: Weather) -> String {
        switch weather {
        case .fog:
            return "foggy"
        case .clear, .cloudy, .rain, .snow:
            return "clear"
        }
    }
}
