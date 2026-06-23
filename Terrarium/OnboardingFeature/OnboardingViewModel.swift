//
//  OnboardingViewModel.swift
//  Terrarium — OnboardingFeature
//
//  Observable view model for the persona/preference onboarding flow (US-G1).
//  Drives multi-step navigation and writes the final `UserPreferences` to
//  `PreferencesStore` on completion or skip.
//
//  Steps:
//   1. PersonaPicker   — choose Restless Local / Newcomer / Weekend Drifter
//   2. InterestTags    — pick POICategory interests (multi-select)
//   3. VibePicker      — pick preferred Vibes (multi-select)
//   4. RadiusPicker    — confirm / adjust travel radius
//   5. LocationPriming — explain location use before any system prompt (US-G2)
//
//  Persona pre-fills the radius per the decisions table:
//   Restless Local  → 2000 m
//   Newcomer        → 1200 m
//   Weekend Drifter → 2500 m
//

import Foundation
import Observation

// MARK: - Onboarding step

enum OnboardingStep: Int, CaseIterable {
    case persona       = 0
    case interestTags  = 1
    case vibe          = 2
    case radius        = 3
    case transport     = 4
    case locationPrime = 5
}

// MARK: - OnboardingViewModel

@Observable
@MainActor
final class OnboardingViewModel {

    // MARK: Step management

    private(set) var currentStep: OnboardingStep = .persona

    var isLastStep: Bool { currentStep == .locationPrime }

    // MARK: Draft preferences (mutated through each step)

    /// Selected persona. Pre-selecting in `selectPersona(_:)` also updates radius.
    private(set) var selectedPersona: PersonaKind = .restlessLocal
    var selectedCategories: Set<POICategory> = []
    var selectedVibes: Set<Vibe> = []
    var travelRadiusMeters: Double = 2000

    /// Preferred way of getting to a place; drives the Anchor card's ETA.
    private(set) var selectedTransportMode: TransportMode = .walk

    // MARK: Location priming callback

    /// Set by the app layer. Called after the user taps "Continue" on the
    /// location priming screen — fires the system CLLocationManager prompt.
    /// Stream B wires the real implementation; this is the ordering seam.
    var onProceedWithLocationPermission: (() -> Void)?

    // MARK: Completion callback

    /// Called after preferences are persisted and onboarding is complete.
    var onComplete: (() -> Void)?

    // MARK: Private

    private let store: PreferencesStore

    // MARK: Init

    init(store: PreferencesStore) {
        self.store = store
    }

    // MARK: - Actions

    /// Set the persona and pre-fill the radius from the decisions table.
    func selectPersona(_ persona: PersonaKind) {
        selectedPersona = persona
        travelRadiusMeters = Self.defaultRadius(for: persona)
    }

    /// Toggle a POI category interest tag.
    func toggleCategory(_ category: POICategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    /// Set the preferred transport mode (single-select).
    func selectTransportMode(_ mode: TransportMode) {
        selectedTransportMode = mode
    }

    /// Toggle a vibe preference.
    func toggleVibe(_ vibe: Vibe) {
        if selectedVibes.contains(vibe) {
            selectedVibes.remove(vibe)
        } else {
            selectedVibes.insert(vibe)
        }
    }

    // MARK: - Navigation

    /// Advance to the next step, or complete if already on the last step.
    func advance() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            complete()
            return
        }
        currentStep = next
    }

    /// Skip the rest of onboarding; persist defaults and finish.
    func skip() {
        persist()
        store.markOnboardingComplete()
        onComplete?()
    }

    /// Called when the user taps through the location priming screen.
    /// Fires the location permission hook, then completes onboarding.
    func proceedWithLocation() {
        onProceedWithLocationPermission?()
        complete()
    }

    // MARK: - Private helpers

    private func complete() {
        persist()
        store.markOnboardingComplete()
        onComplete?()
    }

    private func persist() {
        let prefs = UserPreferences(
            persona: selectedPersona,
            interestCategories: Array(selectedCategories),
            preferredVibes: Array(selectedVibes),
            travelRadiusMeters: travelRadiusMeters
        )
        store.save(prefs)
        store.saveTransportMode(selectedTransportMode)
    }

    // MARK: - Radius defaults (per explore-decisions.md)

    static func defaultRadius(for persona: PersonaKind) -> Double {
        switch persona {
        case .restlessLocal:  return 2000
        case .newcomer:       return 1200
        case .weekendDrifter: return 2500
        }
    }
}
