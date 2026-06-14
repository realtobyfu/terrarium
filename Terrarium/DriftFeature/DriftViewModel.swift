//
//  DriftViewModel.swift
//  Terrarium — DriftFeature
//
//  Wave-0 skeleton (Stream H). Holds the injected Explore providers and exposes
//  the seam Stream E builds the ramble lifecycle + fog-of-war on (US-E1, US-E2,
//  US-E3). Deliberately minimal — just enough to make `makeDriftViewModel`
//  compile and start/stop a session offline. Stream E owns the real flow.
//

import Foundation
import Observation

@Observable
@MainActor
final class DriftViewModel {
    /// The in-flight ramble, if one is running.
    private(set) var session: RambleSession?

    let location: LocationSessionProviding
    let recommender: PlaceRecommending
    let discoveries: DiscoveryStore
    let preferences: UserPreferences

    /// Persistent store for discovery → specimen growth (wired in Stream F).
    var worldStore: WorldStore?

    init(location: LocationSessionProviding,
         recommender: PlaceRecommending,
         discoveries: DiscoveryStore,
         preferences: UserPreferences = .default) {
        self.location = location
        self.recommender = recommender
        self.discoveries = discoveries
        self.preferences = preferences
    }

    /// Begin a ramble — requests/uses `When In Use` and starts breadcrumbs.
    /// TODO(Stream E): consume breadcrumbStream → cells, fog map, live stats.
    func startRamble() {
        location.start()
        session = RambleSession()
    }

    /// End the ramble and stop tracking.
    /// TODO(Stream E): finalise summary (cells lit, specimens earned).
    func endRamble() {
        location.stop()
        session?.endedAt = .now
    }
}
