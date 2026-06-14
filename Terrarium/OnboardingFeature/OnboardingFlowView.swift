//
//  OnboardingFlowView.swift
//  Terrarium — OnboardingFeature
//
//  Multi-step onboarding shell (US-G1 + US-G2). Hosts the five steps in a
//  `TabView` page-style container with a custom progress indicator and a
//  "Skip" affordance (except on the location priming step, where the choice
//  is inline).
//
//  The view is shown once (gated by `PreferencesStore.hasCompletedOnboarding`)
//  and drives `OnboardingViewModel` for all state mutations.
//

import SwiftUI

struct OnboardingFlowView: View {
    @State var viewModel: OnboardingViewModel

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color(hex: "F5EDD9").ignoresSafeArea()

            // Step content
            TabView(selection: Binding(
                get: { viewModel.currentStep.rawValue },
                set: { _ in } // navigation is VM-driven; swipe disabled via .tabViewStyle
            )) {
                PersonaPickerView(viewModel: viewModel)
                    .tag(OnboardingStep.persona.rawValue)

                InterestTagsView(viewModel: viewModel)
                    .tag(OnboardingStep.interestTags.rawValue)

                VibePickerView(viewModel: viewModel)
                    .tag(OnboardingStep.vibe.rawValue)

                RadiusPickerView(viewModel: viewModel)
                    .tag(OnboardingStep.radius.rawValue)

                LocationPrimingView(viewModel: viewModel)
                    .tag(OnboardingStep.locationPrime.rawValue)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.currentStep)

            // Top bar: progress + skip
            HStack {
                // Step dots
                HStack(spacing: 6) {
                    ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                        Capsule()
                            .fill(step == viewModel.currentStep ? Theme.Palette.accent : Theme.Palette.cardBorder)
                            .frame(width: step == viewModel.currentStep ? 20 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: viewModel.currentStep)
                    }
                }

                Spacer()

                // Skip (not shown on the location priming step — that step has its own "Not now")
                if viewModel.currentStep != .locationPrime {
                    Button("Skip") {
                        viewModel.skip()
                    }
                    .font(Theme.Typography.body(15))
                    .foregroundStyle(Theme.Palette.secondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.m)
        }
    }
}

#Preview {
    let store = PreferencesStore(defaults: UserDefaults(suiteName: "preview-onboarding")!)
    let vm = OnboardingViewModel(store: store)
    OnboardingFlowView(viewModel: vm)
}
