//
//  InterestTagsView.swift
//  Terrarium — OnboardingFeature
//
//  Step 2 of onboarding (US-G1): pick POI category interest tags.
//  Multi-select; any combination is valid (empty = no bias / all categories).
//

import SwiftUI

struct InterestTagsView: View {
    @Bindable var viewModel: OnboardingViewModel

    // Grid layout — two flexible columns.
    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.m),
        GridItem(.flexible(), spacing: Theme.Spacing.m),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Theme.Spacing.m) {
                Text("What do you\nlove to find?")
                    .font(Theme.Typography.display(30, weight: .medium))
                    .foregroundStyle(Theme.Palette.title)
                    .multilineTextAlignment(.center)

                Text("Pick as many as you like. We'll bias suggestions toward them.")
                    .font(Theme.Typography.body(15))
                    .foregroundStyle(Theme.Palette.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Theme.Spacing.xl)
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer(minLength: Theme.Spacing.l)

            // Tag grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
                    ForEach(POICategory.allCases, id: \.self) { category in
                        CategoryTag(
                            category: category,
                            isSelected: viewModel.selectedCategories.contains(category),
                            onToggle: { viewModel.toggleCategory(category) }
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
            }

            Spacer(minLength: Theme.Spacing.l)

            // Continue (always enabled — empty = no preference)
            GlowButton(title: "Continue") {
                viewModel.advance()
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

// MARK: - CategoryTag

private struct CategoryTag: View {
    let category: POICategory
    let isSelected: Bool
    let onToggle: () -> Void

    private var label: String {
        switch category {
        case .park:       return "Parks"
        case .coffee:     return "Coffee"
        case .bookstore:  return "Bookstores"
        case .restaurant: return "Restaurants"
        case .viewpoint:  return "Viewpoints"
        case .market:     return "Markets"
        case .museum:     return "Museums"
        case .bar:        return "Bars"
        case .other:      return "Hidden gems"
        }
    }

    private var icon: String {
        switch category {
        case .park:       return "leaf"
        case .coffee:     return "cup.and.saucer"
        case .bookstore:  return "books.vertical"
        case .restaurant: return "fork.knife"
        case .viewpoint:  return "eye"
        case .market:     return "basket"
        case .museum:     return "building.columns"
        case .bar:        return "wineglass"
        case .other:      return "sparkles"
        }
    }

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: Theme.Spacing.s) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : Theme.Palette.accent)

                Text(label)
                    .font(Theme.Typography.body(13, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Theme.Palette.title)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.l)
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
        InterestTagsView(viewModel: OnboardingViewModel(store: PreferencesStore()))
    }
}
