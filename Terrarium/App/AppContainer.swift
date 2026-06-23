//
//  AppContainer.swift
//  Terrarium — App
//
//  The single composition root. Built once in TerrariumApp, it owns the
//  SwiftData container + providers and vends view models via constructor
//  injection. Surfaced to the view tree through a custom Environment value.
//  No DI library.
//

import SwiftUI
import SwiftData

@MainActor
final class AppContainer {
    let skyProvider: SkyStateProviding
    let worldProvider: WorldStateProviding
    let modelContainer: ModelContainer?

    // MARK: Explore providers (Stream H contract; stubs until Wave 1 lands)
    let poiCatalog: POICatalogProviding
    let weatherProvider: WeatherProviding
    let locationSession: LocationSessionProviding
    let recommender: PlaceRecommending
    let discoveryStore: DiscoveryStore
    /// Persona/taste prefs — loaded from `preferencesStore` on init (Stream G).
    let preferences: UserPreferences
    /// UserDefaults-backed persistence for `UserPreferences` and the
    /// onboarding-seen flag. Injected so unit tests can pass a clean suite.
    let preferencesStore: PreferencesStore

    init(
        sky: SkyStateProviding = SolarSkyStateProvider(),
        catalog: POICatalogProviding = StubPOICatalog(),
        weather: WeatherProviding = StubWeatherProvider(),
        location: LocationSessionProviding = StubLocationSession(),
        recommender: PlaceRecommending? = nil,
        discoveryStore: DiscoveryStore = InMemoryDiscoveryStore(),
        preferencesStore: PreferencesStore = PreferencesStore(),
        inMemory: Bool = false
    ) {
        self.skyProvider = sky
        self.poiCatalog = catalog
        self.weatherProvider = weather
        self.locationSession = location
        self.discoveryStore = discoveryStore
        self.preferencesStore = preferencesStore
        // Load persisted preferences so the ranker immediately reflects
        // whatever the user set during onboarding (Stream G / US-G1, FR-19).
        self.preferences = preferencesStore.load()
        // The recommender reads the catalog + discovery store; default to the
        // stub wired to whatever catalog/store we were given (Stream C swaps it).
        self.recommender = recommender ?? StubRecommender(catalog: catalog, discoveries: discoveryStore)

        // SwiftData is the source of truth for the world (§G). Degrade to the
        // in-memory stub if the store can't be opened.
        do {
            let container = try ModelContainer(
                for: WorldStateRecord.self, WorldPropRecord.self,
                     CompletedQuest.self, JournalEntry.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
            )
            self.modelContainer = container
            self.worldProvider = WorldStore(context: container.mainContext)
        } catch {
            self.modelContainer = nil
            self.worldProvider = StubWorldStateProvider()
        }
    }

    /// Production composition: the real Explore providers wired together.
    /// Used by `TerrariumApp`. The `init` defaults stay as offline stubs so
    /// tests, previews and the `@Entry` default never touch WeatherKit or the
    /// location-permission prompt. The recommender and the container share one
    /// `DiscoveryStore` instance so novelty reflects recorded discoveries.
    static func live() -> AppContainer {
        let catalog = BundledPOICatalog()
        let discoveryStore = InMemoryDiscoveryStore()
        let recommender = RulesRecommender(catalog: catalog, discoveryStore: discoveryStore)
        return AppContainer(
            catalog: catalog,
            weather: WeatherKitProvider(),
            location: LocationSessionManager(),
            recommender: recommender,
            discoveryStore: discoveryStore
        )
    }

    /// The persistent world store, when available (drives completion/journal).
    var worldStore: WorldStore? { worldProvider as? WorldStore }

    func makeHomeViewModel() -> HomeViewModel {
        let vm = HomeViewModel(sky: skyProvider, world: worldProvider)
        vm.worldStore = worldStore
        return vm
    }

    // MARK: Explore view models (Stream D/E flesh these out)

    func makeAnchorViewModel() -> AnchorViewModel {
        let vm = AnchorViewModel(catalog: poiCatalog,
                                 weather: weatherProvider,
                                 recommender: recommender,
                                 location: locationSession,
                                 discoveries: discoveryStore,
                                 preferences: preferences,
                                 preferencesStore: preferencesStore)
        vm.worldStore = worldStore
        // US-F1: inject the real LocationVerifier so Anchor arrival is
        // geofence-verified (with honor-mode fallback when location is
        // unavailable). The verifier reads the same catalog and location
        // session already wired into the VM.
        vm.arrivalVerifier = LocationVerifier(catalog: poiCatalog,
                                              location: locationSession)
        return vm
    }

    /// Settings sheet (gear on Home). Edits transport mode + onboarding prefs,
    /// persisting straight to `preferencesStore`.
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(store: preferencesStore)
    }

    func makeDriftViewModel() -> DriftViewModel {
        let vm = DriftViewModel(location: locationSession,
                                recommender: recommender,
                                discoveries: discoveryStore,
                                preferences: preferences)
        vm.worldStore = worldStore
        return vm
    }
}

// MARK: - Environment plumbing

extension EnvironmentValues {
    /// Any view can pull the composition root from the environment.
    @Entry var container: AppContainer = AppContainer()
}
