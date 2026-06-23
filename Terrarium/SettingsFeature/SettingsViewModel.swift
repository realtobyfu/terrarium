//
//  SettingsViewModel.swift
//  Terrarium — SettingsFeature
//
//  Backs the Settings sheet (gear on Home). Lets a returning user revisit the
//  preferences first captured in onboarding — transport mode, interests, vibes,
//  and travel radius — and writes them straight back to `PreferencesStore`.
//
//  Auto-save: each discrete edit persists immediately, and the view also calls
//  `save()` on dismiss to catch the continuous radius slider. Persona is not
//  edited here but is preserved so we never clobber it on write.
//

import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {

    // MARK: Editable state

    private(set) var transportMode: TransportMode
    var selectedCategories: Set<POICategory>
    var selectedVibes: Set<Vibe>
    var travelRadiusMeters: Double

    // MARK: Preserved (not edited in Settings)

    private let persona: PersonaKind

    // MARK: Private

    private let store: PreferencesStore

    // MARK: Init

    init(store: PreferencesStore) {
        self.store = store
        let prefs = store.load()
        self.persona = prefs.persona
        self.selectedCategories = Set(prefs.interestCategories)
        self.selectedVibes = Set(prefs.preferredVibes)
        self.travelRadiusMeters = prefs.travelRadiusMeters
        self.transportMode = store.loadTransportMode()
    }

    // MARK: Actions

    func selectTransportMode(_ mode: TransportMode) {
        transportMode = mode
        save()
    }

    func toggleCategory(_ category: POICategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        save()
    }

    func toggleVibe(_ vibe: Vibe) {
        if selectedVibes.contains(vibe) {
            selectedVibes.remove(vibe)
        } else {
            selectedVibes.insert(vibe)
        }
        save()
    }

    /// Persist the full current state. Called after each edit and on dismiss.
    func save() {
        let prefs = UserPreferences(
            persona: persona,
            interestCategories: Array(selectedCategories),
            preferredVibes: Array(selectedVibes),
            travelRadiusMeters: travelRadiusMeters
        )
        store.save(prefs)
        store.saveTransportMode(transportMode)
    }
}
