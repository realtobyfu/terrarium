//
//  SettingsView.swift
//  Terrarium — SettingsFeature
//
//  The Settings sheet, opened from the gear on Home. Re-uses the onboarding
//  building blocks (SelectableChip, RadiusSlider, OnboardingStepHeader) so the
//  surface speaks the same "Hidden Garden" language. Edits auto-save through
//  `SettingsViewModel`; the view also saves on dismiss to catch the radius slider.
//

import SwiftUI

struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    transportSection
                        .accessibilityIdentifier("settings.transportSection")
                    interestsSection
                        .accessibilityIdentifier("settings.interestsSection")
                    vibesSection
                        .accessibilityIdentifier("settings.vibesSection")
                    radiusSection
                        .accessibilityIdentifier("settings.radiusSection")
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.l)
                .accessibilityIdentifier("settings.root")
            }
            .scrollIndicators(.hidden)
            .background(Color(hex: "FBF2E0").ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.Typography.body(16, weight: .semibold))
                }
            }
            .onDisappear { viewModel.save() }
        }
    }

    // MARK: Sections

    private var transportSection: some View {
        section(title: "Getting there",
                subtitle: "How we show distance and time to a place.") {
            chipGrid {
                ForEach(TransportMode.allCases, id: \.self) { mode in
                    SelectableChip(
                        label: mode.label,
                        icon: mode.systemImage,
                        isSelected: viewModel.transportMode == mode,
                        action: { viewModel.selectTransportMode(mode) }
                    )
                }
            }
        }
    }

    private var interestsSection: some View {
        section(title: "Interests",
                subtitle: "Places you love get a gentle boost.") {
            chipGrid {
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

    private var vibesSection: some View {
        section(title: "Vibes",
                subtitle: "The moods that feel like you.") {
            chipGrid {
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

    private var radiusSection: some View {
        section(title: "Travel radius",
                subtitle: "Places within your reach are favoured.") {
            RadiusSlider(meters: $viewModel.travelRadiusMeters)
        }
    }

    // MARK: Building blocks

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.display(22, weight: .semibold))
                    .foregroundStyle(Theme.Palette.title)
                Text(subtitle)
                    .font(Theme.Typography.body(14))
                    .foregroundStyle(Theme.Palette.secondary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func chipGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        GlassEffectContainer(spacing: Theme.Spacing.m) {
            LazyVGrid(columns: Self.chipColumns, spacing: Theme.Spacing.m) {
                content()
            }
        }
    }

    // MARK: Layout constants

    /// Mirrors the curated onboarding interest set.
    private static let interestCategories: [POICategory] =
        [.park, .coffee, .bookstore, .restaurant, .viewpoint, .market, .museum, .bar]

    private static let chipColumns = [
        GridItem(.flexible(), spacing: Theme.Spacing.m),
        GridItem(.flexible(), spacing: Theme.Spacing.m),
    ]
}

// MARK: - Preview

#Preview("Settings") {
    SettingsView(viewModel: SettingsViewModel(store: PreferencesStore()))
}
