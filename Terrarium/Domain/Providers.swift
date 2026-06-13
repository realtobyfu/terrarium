//
//  Providers.swift
//  Terrarium — Domain
//
//  Provider protocols and their Phase 1a stub implementations.
//  Every provider is a plain protocol with a stub conforming type so the
//  app runs fully offline. Real implementations land in Phase 1b.
//

import Foundation
import simd

// MARK: - Protocols

protocol SkyStateProviding {
    func current() -> SkyState
}

protocol WorldStateProviding {
    func current() -> WorldState
}

protocol QuestSuggesting {
    func suggestion() -> Quest
}

// MARK: - Stubs

/// Fixed golden-hour / foggy state so the layered UI is provable offline.
struct StubSkyStateProvider: SkyStateProviding {
    // TODO(Phase 1b): real solar position + weather + reverse-geocoded location.
    func current() -> SkyState {
        SkyState(
            sunElevationDegrees: 4,        // just above horizon → golden hour band
            weather: .fog,
            locationName: "SF",
            localTimeLabel: "6:48pm"
        )
    }
}

/// Three placeholder props scattered across the globe.
struct StubWorldStateProvider: WorldStateProviding {
    // TODO(Phase 1b): SwiftData persistence + vitality derived from karma.
    func current() -> WorldState {
        WorldState(
            props: [
                WorldProp(kind: .tree,
                          sphereCoordinate: SIMD2<Float>(0.16, -0.07)),
                WorldProp(kind: .building,
                          sphereCoordinate: SIMD2<Float>(0.09, 0.06)),
                WorldProp(kind: .flowers,
                          sphereCoordinate: SIMD2<Float>(0.13, 0.00)),
            ],
            vitality: 0.6
        )
    }
}

/// The Ocean Beach quest from the mockup.
struct StubQuestSuggester: QuestSuggesting {
    // TODO(Phase 1b): location-aware + LLM-generated prompts.
    func suggestion() -> Quest {
        Quest(
            title: "Ocean Beach at dusk",
            prompt: "Walk the shore, name three sounds",
            placeName: "Ocean Beach",
            poiRef: "poi.ocean-beach.sf",
            suggestedKind: .flowers
        )
    }
}
