//
//  PreferencesStoreTests.swift
//  TerrariumTests
//
//  Unit tests for `PreferencesStore` (Stream G / US-G1, FR-19).
//
//  Each test gets an isolated `UserDefaults` suite so tests never contaminate
//  `.standard` or each other. The suite is destroyed after each test.
//
//  Tests cover:
//  - load() returns .default when nothing is persisted
//  - save/load round-trip preserves all fields
//  - persona-radius pre-fills match the decisions table
//  - onboarding flag starts false, flips to true after markOnboardingComplete()
//  - OnboardingViewModel.defaultRadius(_:) matches the decisions table values
//

import Foundation
import Testing
@testable import Terrarium

@MainActor  // needed for OnboardingViewModel (which is @MainActor)
@Suite("PreferencesStore")
struct PreferencesStoreTests {

    // MARK: - Helpers

    /// Returns a store backed by a fresh, isolated UserDefaults suite.
    private func makeStore(suiteName: String = UUID().uuidString) -> (store: PreferencesStore, defaults: UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        // Clear any residual state from a previous test run with this name.
        defaults.removePersistentDomain(forName: suiteName)
        return (PreferencesStore(defaults: defaults), defaults)
    }

    // MARK: - load()

    @Test("load() returns UserPreferences.default when nothing has been saved")
    func loadReturnsDefaultWhenEmpty() {
        let (store, _) = makeStore()
        let loaded = store.load()
        #expect(loaded == .default)
        #expect(loaded.persona == .restlessLocal)
        #expect(loaded.travelRadiusMeters == 1500)
        #expect(loaded.interestCategories.isEmpty)
        #expect(loaded.preferredVibes.isEmpty)
    }

    // MARK: - save / load round-trip

    @Test("save then load round-trips UserPreferences with all fields intact")
    func saveLoadRoundTrip() {
        let (store, _) = makeStore()
        let original = UserPreferences(
            persona: .newcomer,
            interestCategories: [.coffee, .park, .museum],
            preferredVibes: [.cozy, .scenic],
            travelRadiusMeters: 1800
        )
        store.save(original)
        let loaded = store.load()
        #expect(loaded == original)
    }

    @Test("save then load preserves weekendDrifter persona and 2500 m radius")
    func roundTripWeekendDrifter() {
        let (store, _) = makeStore()
        let prefs = UserPreferences(
            persona: .weekendDrifter,
            interestCategories: [.viewpoint, .bar],
            preferredVibes: [.quirky],
            travelRadiusMeters: 2500
        )
        store.save(prefs)
        #expect(store.load() == prefs)
    }

    @Test("save overwrites a previously saved value")
    func saveOverwrites() {
        let (store, _) = makeStore()
        let first  = UserPreferences(persona: .newcomer, interestCategories: [], preferredVibes: [], travelRadiusMeters: 1200)
        let second = UserPreferences(persona: .restlessLocal, interestCategories: [.coffee], preferredVibes: [.lively], travelRadiusMeters: 2000)
        store.save(first)
        store.save(second)
        #expect(store.load() == second)
    }

    // MARK: - Onboarding flag

    @Test("hasCompletedOnboarding is false before markOnboardingComplete()")
    func onboardingFlagStartsFalse() {
        let (store, _) = makeStore()
        #expect(store.hasCompletedOnboarding == false)
    }

    @Test("markOnboardingComplete() sets hasCompletedOnboarding to true")
    func onboardingFlagFlipsTrue() {
        let (store, _) = makeStore()
        store.markOnboardingComplete()
        #expect(store.hasCompletedOnboarding == true)
    }

    @Test("hasCompletedOnboarding persists across store instances using the same defaults")
    func onboardingFlagPersistsAcrossInstances() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store1 = PreferencesStore(defaults: defaults)
        #expect(store1.hasCompletedOnboarding == false)
        store1.markOnboardingComplete()

        // Second store reading the same defaults suite
        let store2 = PreferencesStore(defaults: defaults)
        #expect(store2.hasCompletedOnboarding == true)
    }

    // MARK: - Persona radius defaults (per explore-decisions.md)

    @Test("defaultRadius for restlessLocal is 2000 m")
    func radiusRestlessLocal() {
        #expect(OnboardingViewModel.defaultRadius(for: .restlessLocal) == 2000)
    }

    @Test("defaultRadius for newcomer is 1200 m")
    func radiusNewcomer() {
        #expect(OnboardingViewModel.defaultRadius(for: .newcomer) == 1200)
    }

    @Test("defaultRadius for weekendDrifter is 2500 m")
    func radiusWeekendDrifter() {
        #expect(OnboardingViewModel.defaultRadius(for: .weekendDrifter) == 2500)
    }

    // MARK: - OnboardingViewModel persona → radius pre-fill

    @Test("selectPersona pre-fills travelRadiusMeters from the decisions table")
    func personaPreFillsRadius() {
        let (store, _) = makeStore()
        let vm = OnboardingViewModel(store: store)

        vm.selectPersona(.newcomer)
        #expect(vm.travelRadiusMeters == 1200)
        #expect(vm.selectedPersona == .newcomer)

        vm.selectPersona(.weekendDrifter)
        #expect(vm.travelRadiusMeters == 2500)
        #expect(vm.selectedPersona == .weekendDrifter)
    }

    // MARK: - OnboardingViewModel skip → persists defaults

    @Test("skip() persists Restless Local defaults and marks onboarding complete")
    func skipPersistsDefaults() {
        let (store, _) = makeStore()
        let vm = OnboardingViewModel(store: store)
        var completionCalled = false
        vm.onComplete = { completionCalled = true }

        vm.skip()

        #expect(store.hasCompletedOnboarding == true)
        #expect(completionCalled == true)
        // Default persona from skip is .restlessLocal (initial VM state)
        #expect(store.load().persona == .restlessLocal)
    }

    // MARK: - OnboardingViewModel toggle helpers

    @Test("toggleCategory adds then removes a category")
    func toggleCategoryAddRemove() {
        let (store, _) = makeStore()
        let vm = OnboardingViewModel(store: store)

        vm.toggleCategory(.coffee)
        #expect(vm.selectedCategories.contains(.coffee))

        vm.toggleCategory(.coffee)
        #expect(!vm.selectedCategories.contains(.coffee))
    }

    @Test("toggleVibe adds then removes a vibe")
    func toggleVibeAddRemove() {
        let (store, _) = makeStore()
        let vm = OnboardingViewModel(store: store)

        vm.toggleVibe(.cozy)
        #expect(vm.selectedVibes.contains(.cozy))

        vm.toggleVibe(.cozy)
        #expect(!vm.selectedVibes.contains(.cozy))
    }
}
