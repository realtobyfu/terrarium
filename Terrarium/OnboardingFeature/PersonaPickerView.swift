//
//  PersonaPickerView.swift
//  Terrarium — OnboardingFeature
//
//  Step 1 of onboarding (US-G1): choose your explorer persona.
//  Selecting a persona pre-fills the travel radius per the decisions table.
//

import SwiftUI

struct PersonaPickerView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Theme.Spacing.m) {
                Text("Who are you\nexploring as?")
                    .font(Theme.Typography.display(30, weight: .medium))
                    .foregroundStyle(Theme.Palette.title)
                    .multilineTextAlignment(.center)

                Text("Your persona shapes which places we suggest.")
                    .font(Theme.Typography.body(15))
                    .foregroundStyle(Theme.Palette.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Theme.Spacing.xl)
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer(minLength: Theme.Spacing.xl)

            // Persona cards
            VStack(spacing: Theme.Spacing.m) {
                ForEach(PersonaKind.allCases, id: \.self) { persona in
                    PersonaCard(
                        persona: persona,
                        isSelected: viewModel.selectedPersona == persona,
                        onSelect: { viewModel.selectPersona(persona) }
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.l)

            Spacer(minLength: Theme.Spacing.xl)

            // Continue
            GlowButton(title: "Continue") {
                viewModel.advance()
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

// MARK: - PersonaCard

private struct PersonaCard: View {
    let persona: PersonaKind
    let isSelected: Bool
    let onSelect: () -> Void

    private var info: (title: String, subtitle: String, icon: String) {
        switch persona {
        case .restlessLocal:
            return ("Restless Local", "I know the city. Surprise me.", "figure.walk.motion")
        case .newcomer:
            return ("Newcomer", "I'm discovering the city for the first time.", "binoculars")
        case .weekendDrifter:
            return ("Weekend Drifter", "No plans — give me one good place.", "sun.horizon")
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Theme.Spacing.l) {
                Image(systemName: info.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : Theme.Palette.accent)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(info.title)
                        .font(Theme.Typography.body(16, weight: .medium))
                        .foregroundStyle(isSelected ? .white : Theme.Palette.title)

                    Text(info.subtitle)
                        .font(Theme.Typography.body(13))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : Theme.Palette.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding(Theme.Spacing.l)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(isSelected ? Theme.Palette.accent : Theme.Palette.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(
                        isSelected ? Theme.Palette.accent : Theme.Palette.cardBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: .black.opacity(isSelected ? 0.12 : 0.06), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

#Preview {
    ZStack {
        Color(hex: "F5EDD9").ignoresSafeArea()
        PersonaPickerView(viewModel: {
            let vm = OnboardingViewModel(store: PreferencesStore(defaults: .standard))
            return vm
        }())
    }
}
