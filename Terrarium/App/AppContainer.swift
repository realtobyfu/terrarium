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
    let questSuggester: QuestSuggesting
    let modelContainer: ModelContainer?

    // MARK: Explore providers (Stream H contract; stubs until Wave 1 lands)
    let poiCatalog: POICatalogProviding
    let weatherProvider: WeatherProviding
    let locationSession: LocationSessionProviding
    let recommender: PlaceRecommending
    let discoveryStore: DiscoveryStore
    /// Persona/taste prefs; persistence + onboarding capture land in Stream G.
    let preferences: UserPreferences

    init(
        sky: SkyStateProviding = SolarSkyStateProvider(),
        quests: QuestSuggesting = StubQuestSuggester(),
        catalog: POICatalogProviding = StubPOICatalog(),
        weather: WeatherProviding = StubWeatherProvider(),
        location: LocationSessionProviding = StubLocationSession(),
        recommender: PlaceRecommending? = nil,
        discoveryStore: DiscoveryStore = InMemoryDiscoveryStore(),
        preferences: UserPreferences = .default,
        inMemory: Bool = false
    ) {
        self.skyProvider = sky
        self.questSuggester = quests
        self.poiCatalog = catalog
        self.weatherProvider = weather
        self.locationSession = location
        self.discoveryStore = discoveryStore
        self.preferences = preferences
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

    /// The persistent world store, when available (drives completion/journal).
    var worldStore: WorldStore? { worldProvider as? WorldStore }

    func makeHomeViewModel() -> HomeViewModel {
        let vm = HomeViewModel(sky: skyProvider, world: worldProvider, quests: questSuggester)
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
                                 preferences: preferences)
        vm.worldStore = worldStore
        return vm
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
