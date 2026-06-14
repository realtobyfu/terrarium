//
//  AnchorViewModel.swift
//  Terrarium — AnchorFeature
//
//  Wave-0 skeleton (Stream H). Holds the injected Explore providers and exposes
//  the seam Stream D builds the concierge screen + terrarium handoff on (US-D1,
//  US-D2). Deliberately minimal — just enough to make `makeAnchorViewModel`
//  compile and surface one pick offline. Stream D owns the real flow.
//

import Foundation
import Observation

@Observable
@MainActor
final class AnchorViewModel {
    /// The current top Anchor pick, if any.
    private(set) var pick: POI?

    let catalog: POICatalogProviding
    let weather: WeatherProviding
    let recommender: PlaceRecommending
    let location: LocationSessionProviding
    let discoveries: DiscoveryStore
    let preferences: UserPreferences

    /// Persistent store for the terrarium handoff (US-D2). Injected by container.
    var worldStore: WorldStore?

    init(catalog: POICatalogProviding,
         weather: WeatherProviding,
         recommender: PlaceRecommending,
         location: LocationSessionProviding,
         discoveries: DiscoveryStore,
         preferences: UserPreferences = .default) {
        self.catalog = catalog
        self.weather = weather
        self.recommender = recommender
        self.location = location
        self.discoveries = discoveries
        self.preferences = preferences
    }

    /// Assemble a context and ask the recommender for the best place.
    /// TODO(Stream D): use Stream B's ContextAssembler, add re-roll + Maps handoff.
    func refresh() async {
        let context = RecommendationContext(
            weather: await weather.current(),
            date: .now,
            timeOfDay: .afternoon,
            coordinate: await location.currentCoordinate(),
            preferences: preferences
        )
        pick = recommender.anchor(context)
    }
}
