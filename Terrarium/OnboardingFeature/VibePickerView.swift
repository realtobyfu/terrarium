//
//  VibePickerView.swift
//  Terrarium — OnboardingFeature
//
//  Step 3 of onboarding (US-G1): pick preferred Vibes (multi-select).
//  Vibe tags are the shared vocabulary between the POI catalog and onboarding.
//

import SwiftUI

struct VibePickerView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Theme.Spacing.m) {
                Text("What's your\nkind of vibe?")
                    .font(Theme.Typography.display(30, weight: .medium))
                    .foregroundStyle(Theme.Palette.title)
                    .multilineTextAlignment(.center)

                Text("Select all that feel like you.")
                    .font(Theme.Typography.body(15))
                    .foregroundStyle(Theme.Palette.secondary)
            }
            .padding(.top, Theme.Spacing.xl)
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer(minLength: Theme.Spacing.xl)

            // Vibe chips — wrap layout via flexible HStack rows
            VStack(spacing: Theme.Spacing.m) {
                ForEach(Vibe.allCases, id: \.self) { vibe in
                    VibeChip(
                        vibe: vibe,
                        isSelected: viewModel.selectedVibes.contains(vibe),
                        onToggle: { viewModel.toggleVibe(vibe) }
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

// MARK: - VibeChip

private struct VibeChip: View {
    let vibe: Vibe
    let isSelected: Bool
    let onToggle: () -> Void

    private var info: (label: String, icon: String, description: String) {
        switch vibe {
        case .quiet:  return ("Quiet",  "waveform.slash",    "A place where you can breathe")
        case .lively: return ("Lively", "person.3",          "Energy, buzz, the city humming")
        case .cozy:   return ("Cozy",   "flame",             "Warm, unhurried, settle-in spots")
        case .scenic: return ("Scenic", "mountain.2",        "Worth stopping just to look")
        case .quirky: return ("Quirky", "sparkle.magnifyingglass", "Unexpected, off-the-beaten-path")
        }
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: info.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : Theme.Palette.accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(info.label)
                        .font(Theme.Typography.body(16, weight: .medium))
                        .foregroundStyle(isSelected ? .white : Theme.Palette.title)
                    Text(info.description)
                        .font(Theme.Typography.body(13))
                        .foregroundStyle(isSelected ? .white.opacity(0.75) : Theme.Palette.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .white : Theme.Palette.label)
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
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2), value: isSelected)
    }
}

#Preview {
    ZStack {
        Color(hex: "F5EDD9").ignoresSafeArea()
        VibePickerView(viewModel: OnboardingViewModel(store: PreferencesStore()))
    }
}
