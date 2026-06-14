//
//  RootView.swift
//  Terrarium — App
//
//  Pulls the composition root from the environment and decides what to show:
//
//   • First launch → OnboardingFlowView (US-G1/G2). Shown once; persisted via
//     `PreferencesStore.hasCompletedOnboarding`. On completion or skip the flag
//     is set and `showOnboarding` flips to false.
//
//   • Returning launch → ExploreShellView (US-G3). Hosts Home (globe), Drift,
//     and Anchor as three tabs. The existing HomeView is tab 0, so the original
//     globe experience is always reachable.
//
//  Stream G edits: added `showOnboarding` state and the onboarding/shell branch.
//  The `ExploreShellView` is the new root for returning users; it owns HomeView
//  internally so the globe is always one tap away on the Home tab.
//
//  Keep edits minimal and additive so Wave-3 merge is clean.
//

import SwiftUI

struct RootView: View {
    @Environment(\.container) private var container

    /// Drives which root screen is showing. Read from the store on appear so
    /// re-installs or cleared UserDefaults always re-trigger onboarding.
    @State private var showOnboarding: Bool = false

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingFlowView(viewModel: makeOnboardingVM())
            } else {
                ExploreShellView(container: container)
            }
        }
        .onAppear {
            showOnboarding = !container.preferencesStore.hasCompletedOnboarding
        }
    }

    // MARK: - Factory

    private func makeOnboardingVM() -> OnboardingViewModel {
        let vm = OnboardingViewModel(store: container.preferencesStore)
        vm.onComplete = {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showOnboarding = false
            }
        }
        // Stream B will set onProceedWithLocationPermission here when it lands.
        // The seam is: vm.onProceedWithLocationPermission = { container.locationSession.requestPermission() }
        return vm
    }
}
