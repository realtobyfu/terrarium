//
//  PreferencesStore.swift
//  Terrarium — Domain
//
//  A thin UserDefaults-backed store for `UserPreferences`. The store is the
//  single source of truth for persona, interest categories, vibes, and travel
//  radius; it is injected into `AppContainer` (Stream G / US-G1, FR-19).
//
//  Design notes:
//  - `Codable` round-trip via JSONEncoder/Decoder: keeps the store forward-
//    compatible if new fields land (unrecognised keys are ignored on decode).
//  - `load()` returns `.default` on any failure so the app is always runnable
//    on first launch or after a corrupt write — no crashing, no guard-let chains
//    at call sites.
//  - `save(_:)` is synchronous on the calling thread (always `@MainActor` in
//    practice); UserDefaults writes are themselves atomic on iOS.
//  - `hasCompletedOnboarding` / `markOnboardingComplete()` separate the
//    "did the user see onboarding?" flag from the preferences payload so the
//    two can evolve independently.
//

import Foundation

// MARK: - PreferencesStore

/// Persists `UserPreferences` and the onboarding-seen flag to `UserDefaults`.
/// Inject this into `AppContainer`; never import it in Domain tests (keep Domain pure).
///
/// Thread-safety: all mutations go through `UserDefaults` which is itself
/// thread-safe. No `@MainActor` isolation is required; callers may use this
/// from any context. In practice the app always calls it from `@MainActor`
/// (container + view models), but keeping it nonisolated lets it be passed
/// as a default argument in `AppContainer.init`.
final class PreferencesStore {

    // MARK: Keys

    private enum Keys {
        static let preferences         = "terrarium.userPreferences.v1"
        static let onboardingCompleted = "terrarium.onboardingCompleted.v1"
    }

    // MARK: Init

    private let defaults: UserDefaults

    /// Designated init. Pass `.standard` in production; pass a named suite in
    /// unit tests to avoid cross-test contamination.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Preferences

    /// Load persisted preferences. Returns `UserPreferences.default` on first
    /// launch or if the stored data cannot be decoded.
    func load() -> UserPreferences {
        guard
            let data = defaults.data(forKey: Keys.preferences),
            let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data)
        else {
            return .default
        }
        return prefs
    }

    /// Persist `preferences`. Silently no-ops on encoding failure (in practice
    /// `UserPreferences` is always encodable since every field is a primitive or
    /// another `Codable`).
    func save(_ preferences: UserPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: Keys.preferences)
    }

    // MARK: Onboarding flag

    /// True once `markOnboardingComplete()` has been called and persisted.
    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: Keys.onboardingCompleted)
    }

    /// Call when the user finishes or skips onboarding.
    func markOnboardingComplete() {
        defaults.set(true, forKey: Keys.onboardingCompleted)
    }
}
