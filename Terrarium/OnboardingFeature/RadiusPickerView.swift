//
//  RadiusPickerView.swift
//  Terrarium — OnboardingFeature
//
//  Step 4 of onboarding (US-G1): confirm or adjust travel radius.
//  The value is pre-filled from the selected persona; the slider lets the user
//  override it before it lands in `UserPreferences.travelRadiusMeters`.
//

import SwiftUI

struct RadiusPickerView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var radiusKm: String {
        let km = viewModel.travelRadiusMeters / 1000
        return String(format: "%.1f km", km)
    }

    // Soft bounds — ranker penalty beyond radius, not a hard cutoff.
    private let range: ClosedRange<Double> = 500...5000

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Theme.Spacing.m) {
                Text("How far will\nyou wander?")
                    .font(Theme.Typography.display(30, weight: .medium))
                    .foregroundStyle(Theme.Palette.title)
                    .multilineTextAlignment(.center)

                Text("Suggestions within this range get a boost.\nYou can always change this later.")
                    .font(Theme.Typography.body(15))
                    .foregroundStyle(Theme.Palette.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Theme.Spacing.xl)
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer(minLength: Theme.Spacing.xl)

            // Radius display
            SoftPanel {
                VStack(spacing: Theme.Spacing.l) {
                    Text(radiusKm)
                        .font(Theme.Typography.display(48, weight: .medium))
                        .foregroundStyle(Theme.Palette.accent)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: viewModel.travelRadiusMeters)

                    Text("travel radius")
                        .font(Theme.Typography.body(15))
                        .foregroundStyle(Theme.Palette.secondary)

                    // Slider
                    Slider(
                        value: $viewModel.travelRadiusMeters,
                        in: range,
                        step: 100
                    )
                    .tint(Theme.Palette.accent)

                    // Range labels
                    HStack {
                        Text("500 m")
                        Spacer()
                        Text("5 km")
                    }
                    .font(Theme.Typography.body(12))
                    .foregroundStyle(Theme.Palette.label)
                }
                .padding(Theme.Spacing.xl)
            }
            .padding(.horizontal, Theme.Spacing.l)

            // Persona hint
            Text(personaHint)
                .font(Theme.Typography.body(13))
                .foregroundStyle(Theme.Palette.label)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.m)
                .padding(.horizontal, Theme.Spacing.xl)

            Spacer(minLength: Theme.Spacing.xl)

            // Continue
            GlowButton(title: "Continue") {
                viewModel.advance()
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    private var personaHint: String {
        switch viewModel.selectedPersona {
        case .restlessLocal:
            return "Restless Locals typically roam about 2 km — enough to stumble on something new."
        case .newcomer:
            return "Great for getting your bearings — 1.2 km keeps discoveries manageable."
        case .weekendDrifter:
            return "Weekend Drifters cast a wide net: 2.5 km means more surprises."
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "F5EDD9").ignoresSafeArea()
        RadiusPickerView(viewModel: {
            let vm = OnboardingViewModel(store: PreferencesStore())
            vm.selectPersona(.restlessLocal)
            return vm
        }())
    }
}
