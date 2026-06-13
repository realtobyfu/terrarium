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

    init(
        sky: SkyStateProviding = SolarSkyStateProvider(),
        quests: QuestSuggesting = StubQuestSuggester(),
        inMemory: Bool = false
    ) {
        self.skyProvider = sky
        self.questSuggester = quests

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
}

// MARK: - Environment plumbing

extension EnvironmentValues {
    /// Any view can pull the composition root from the environment.
    @Entry var container: AppContainer = AppContainer()
}
