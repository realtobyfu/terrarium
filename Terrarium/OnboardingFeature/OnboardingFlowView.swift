//
//  OnboardingFlowView.swift
//  Terrarium — Prototypes
//
//  A Liquid-Glass redesign of the 5-step onboarding flow (US-G1 + US-G2), in the
//  "Hidden Garden" language established by AnchorView. It is a drop-in
//  alternative to OnboardingFlowView: it drives the SAME `OnboardingViewModel`
//  (persona · interests · vibe · radius · location priming · Skip/Continue) — only
//  the presentation changes. No VM/logic edits.
//
//  Structure: a generative `GardenBackdrop`, a scrolling step body, and two
//  floating glass bars pinned with `.safeAreaInset` — a progress + Skip header and
//  a primary Continue / "Enable location" footer — so the CTA is always reachable
//  and content never hides behind the chrome.
//
//  iOS 26 APIs: glassEffect / GlassEffectContainer (chips, cards, bars),
//  .buttonStyle(.glassProminent) tinted Theme.Garden.moss (primary CTA),
//  .scrollEdgeEffectStyle for the floating header, MeshGradient backdrop.
//

import SwiftUI

struct OnboardingFlowView: View {
    @State var viewModel: OnboardingViewModel

    var body: some View {
        ZStack {
            GardenBackdrop()

            scrollContent
                .safeAreaInset(edge: .top) { topBar }
                .safeAreaInset(edge: .bottom) { bottomBar }
        }
        // Persona step is cut — interests is the first thing we ask. Persona stays
        // at its default (Restless Local) under the hood for the ranker.
        .task {
            if viewModel.currentStep == .persona { viewModel.advance() }
        }
    }

    // MARK: Scrolling step body

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                stepContent
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.42, dampingFraction: 0.85), value: viewModel.currentStep)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        // Persona is skipped on appear; the fallback keeps the switch exhaustive.
        case .persona, .interestTags: interestsStep
        case .vibe:          vibeStep
        case .radius:        radiusStep
        case .locationPrime: primingStep
        }
    }

    // MARK: Steps

    private var interestsStep: some View {
        VStack(spacing: Theme.Spacing.xl) {
            OnboardingStepHeader(
                eyebrow: "Step One",
                title: "What do you\nlove to find?",
                subtitle: "Pick as many as you like — we'll lean toward them."
            )
            GlassEffectContainer(spacing: Theme.Spacing.m) {
                LazyVGrid(columns: Self.chipColumns, spacing: Theme.Spacing.m) {
                    ForEach(Self.interestCategories, id: \.self) { category in
                        SelectableChip(
                            label: category.onboardingLabel,
                            icon: category.onboardingIcon,
                            isSelected: viewModel.selectedCategories.contains(category),
                            action: { viewModel.toggleCategory(category) }
                        )
                    }
                }
            }
        }
        .transition(Self.stepTransition)
    }

    private var vibeStep: some View {
        VStack(spacing: Theme.Spacing.xl) {
            OnboardingStepHeader(
                eyebrow: "Step Two",
                title: "What's your\nkind of vibe?",
                subtitle: "Choose the moods that feel like you."
            )
            GlassEffectContainer(spacing: Theme.Spacing.m) {
                LazyVGrid(columns: Self.chipColumns, spacing: Theme.Spacing.m) {
                    ForEach(Vibe.allCases, id: \.self) { vibe in
                        SelectableChip(
                            label: vibe.onboardingLabel,
                            icon: vibe.onboardingIcon,
                            isSelected: viewModel.selectedVibes.contains(vibe),
                            action: { viewModel.toggleVibe(vibe) }
                        )
                    }
                }
            }
        }
        .transition(Self.stepTransition)
    }

    private var radiusStep: some View {
        VStack(spacing: Theme.Spacing.l) {
            OnboardingStepHeader(
                eyebrow: "Step Three",
                title: "How far will\nyou wander?",
                subtitle: "Places within your reach get a gentle boost. Change it anytime."
            )
            RadiusSlider(meters: $viewModel.travelRadiusMeters)
                .padding(.top, Theme.Spacing.s)
        }
        .transition(Self.stepTransition)
    }

    private var primingStep: some View {
        VStack(spacing: Theme.Spacing.xl) {
            OnboardingStepHeader(
                eyebrow: "One last thing",
                title: "Your walks\ndraw your map",
                subtitle: "Terrarium reveals the world as you move through it."
            )
            PrimingMapIllustration()
            PrimingReassurance()
        }
        .transition(Self.stepTransition)
    }

    // MARK: Chrome — progress + Skip header

    private var topBar: some View {
        HStack(spacing: Theme.Spacing.m) {
            OnboardingProgressBar(
                // Persona is cut, so the visible flow is 4 steps (interests, vibe,
                // radius, priming); offset the index past the hidden persona step.
                totalSteps: OnboardingStep.allCases.count - 1,
                currentIndex: max(0, viewModel.currentStep.rawValue - 1)
            )

            // The priming step offers "Maybe later" inline, so no Skip there.
            if viewModel.currentStep != .locationPrime {
                Button("Skip") { viewModel.skip() }
                    .font(Theme.Typography.body(15, weight: .medium))
                    .foregroundStyle(Theme.Palette.secondary)
                    .padding(.horizontal, Theme.Spacing.s)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: Chrome — primary footer (Continue / Enable location)

    private var bottomBar: some View {
        VStack(spacing: Theme.Spacing.s) {
            if viewModel.currentStep == .locationPrime {
                Button {
                    viewModel.proceedWithLocation()
                } label: {
                    Label("Enable location", systemImage: "location.fill")
                        .font(Theme.Typography.body(17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.Garden.moss)
                .controlSize(.large)

                Button("Maybe later") { viewModel.skip() }
                    .font(Theme.Typography.body(15, weight: .medium))
                    .foregroundStyle(Theme.Palette.secondary)
                    .frame(minHeight: 44)
            } else {
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                        viewModel.advance()
                    }
                } label: {
                    Label("Continue", systemImage: "arrow.right")
                        .font(Theme.Typography.body(17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.Garden.moss)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.s)
        .background(
            // Fade the scrolling content out behind the pinned footer.
            LinearGradient(
                colors: [Color(hex: "FBF2E0").opacity(0), Color(hex: "FBF2E0").opacity(0.92), Color(hex: "FBF2E0")],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    // MARK: Layout constants

    private static let interestCategories: [POICategory] =
        [.park, .coffee, .bookstore, .restaurant, .viewpoint, .market, .museum, .bar]

    private static let chipColumns = [
        GridItem(.flexible(), spacing: Theme.Spacing.m),
        GridItem(.flexible(), spacing: Theme.Spacing.m),
    ]

    /// Forward-sliding step transition (the flow only ever advances).
    private static let stepTransition: AnyTransition = .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
}

// MARK: - Previews

/// Build a VM already advanced to `step`, with optional pre-selected preferences,
/// so each step previews inside the full chrome. Uses the default `PreferencesStore`
/// per the stream brief (previews never call complete/skip, so nothing persists).
@MainActor
private func previewVM(
    step: OnboardingStep,
    persona: PersonaKind = .restlessLocal,
    categories: Set<POICategory> = [],
    vibes: Set<Vibe> = []
) -> OnboardingViewModel {
    let vm = OnboardingViewModel(store: PreferencesStore())
    vm.selectPersona(persona)
    categories.forEach { vm.toggleCategory($0) }
    vibes.forEach { vm.toggleVibe($0) }
    while vm.currentStep.rawValue < step.rawValue { vm.advance() }
    return vm
}

#Preview("Onboarding — Persona") {
    OnboardingFlowView(viewModel: previewVM(step: .persona))
}

#Preview("Onboarding — Interests") {
    OnboardingFlowView(viewModel: previewVM(step: .interestTags, categories: [.park, .coffee, .viewpoint]))
}

#Preview("Onboarding — Vibe") {
    OnboardingFlowView(viewModel: previewVM(step: .vibe, vibes: [.cozy, .scenic]))
}

#Preview("Onboarding — Radius") {
    OnboardingFlowView(viewModel: previewVM(step: .radius, persona: .weekendDrifter))
}

#Preview("Onboarding — Location priming") {
    OnboardingFlowView(viewModel: previewVM(step: .locationPrime))
}
