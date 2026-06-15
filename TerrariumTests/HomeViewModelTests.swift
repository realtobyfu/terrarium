//
//  HomeViewModelTests.swift
//  TerrariumTests
//
//  Navigation/state transitions on HomeViewModel with mock providers injected
//  directly through the initializer — no environment, no graph.
//

import Testing
import simd
@testable import Terrarium

@Suite("HomeViewModel")
@MainActor
struct HomeViewModelTests {

    // MARK: - Mocks

    private struct MockSky: SkyStateProviding {
        func current() -> SkyState {
            SkyState(sunElevationDegrees: 6, weather: .fog,
                     locationName: "SF", localTimeLabel: "6:48pm")
        }
    }

    private struct MockWorld: WorldStateProviding {
        func current() -> WorldState {
            WorldState(props: [], vitality: 0.6)
        }
    }

    private func makeViewModel() -> HomeViewModel {
        HomeViewModel(sky: MockSky(), world: MockWorld())
    }

    // MARK: - Tests

    @Test("Starts with no active sheet")
    func startsWithNoSheet() {
        let vm = makeViewModel()
        #expect(vm.activeSheet == nil)
    }

    @Test("Pulls initial render state from the providers")
    func seedsFromProviders() {
        let vm = makeViewModel()
        #expect(vm.sky.locationName == "SF")
    }

    @Test("openGrowthLog presents the growth-log sheet")
    func openGrowthLog() {
        let vm = makeViewModel()
        vm.openGrowthLog()
        #expect(vm.activeSheet == .growthLog)
    }

    @Test("dismissSheet clears the active sheet")
    func dismissSheet() {
        let vm = makeViewModel()
        vm.openGrowthLog()
        vm.dismissSheet()
        #expect(vm.activeSheet == nil)
    }

    @Test("cycleSky advances the time of day, preserving location & weather")
    func cycleSky() {
        let vm = makeViewModel()
        let before = vm.sky
        vm.cycleSky()
        #expect(vm.sky != before)
        #expect(vm.sky.locationName == before.locationName)
        #expect(vm.sky.weather == before.weather)
    }
}
