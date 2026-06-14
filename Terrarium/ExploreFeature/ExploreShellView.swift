//
//  ExploreShellView.swift
//  Terrarium — ExploreFeature
//
//  US-G3 / FR-20: hosts Drift and Anchor with a clear toggle/entry, integrated
//  into `RootView`. State is preserved when switching modes. The Home/globe
//  remains reachable via the tab bar.
//
//  Shell structure:
//   Tab 0 — Home (globe)      → HomeView (existing)
//   Tab 1 — Drift             → DriftView (Stream E)
//   Tab 2 — Anchor            → AnchorView (Stream D)
//
//  The Drift/Anchor view models are created once by the container and held in
//  `ExploreShellView` state so model state survives tab switches.
//
//  Design: minimal tab bar matching the existing cream/accent palette.
//

import SwiftUI

// MARK: - Shell tab

enum ExploreTab: Int, CaseIterable {
    case home   = 0
    case drift  = 1
    case anchor = 2

    var label: String {
        switch self {
        case .home:   return "Home"
        case .drift:  return "Drift"
        case .anchor: return "Anchor"
        }
    }

    var icon: String {
        switch self {
        case .home:   return "globe.americas.fill"
        case .drift:  return "figure.walk"
        case .anchor: return "mappin.circle.fill"
        }
    }
}

// MARK: - ExploreShellView

struct ExploreShellView: View {
    @Environment(\.container) private var container

    /// Active tab. Preserved across switches.
    @State private var selectedTab: ExploreTab = .home

    /// View models created once; state survives tab switching.
    @State private var homeVM: HomeViewModel
    @State private var driftVM: DriftViewModel
    @State private var anchorVM: AnchorViewModel

    init(container: AppContainer) {
        _homeVM   = State(wrappedValue: container.makeHomeViewModel())
        _driftVM  = State(wrappedValue: container.makeDriftViewModel())
        _anchorVM = State(wrappedValue: container.makeAnchorViewModel())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content area — ZStack so each tab can overlay safe areas freely
            ZStack {
                HomeView(viewModel: homeVM)
                    .opacity(selectedTab == .home ? 1 : 0)
                    // Keep HomeView alive (not removed from hierarchy) so the
                    // globe / sky state is preserved when switching tabs.
                    .allowsHitTesting(selectedTab == .home)

                DriftView(viewModel: driftVM)
                    .opacity(selectedTab == .drift ? 1 : 0)
                    .allowsHitTesting(selectedTab == .drift)

                AnchorView(viewModel: anchorVM)
                    .opacity(selectedTab == .anchor ? 1 : 0)
                    .allowsHitTesting(selectedTab == .anchor)
            }
            .ignoresSafeArea()

            // Custom tab bar
            ExploreTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - ExploreTabBar

private struct ExploreTabBar: View {
    @Binding var selectedTab: ExploreTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ExploreTab.allCases, id: \.rawValue) { tab in
                TabBarItem(tab: tab, isSelected: selectedTab == tab) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.Palette.chipSurface.opacity(0.97))
                .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Theme.Palette.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.s)
    }
}

private struct TabBarItem: View {
    let tab: ExploreTab
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: isSelected ? 22 : 20))
                    .foregroundStyle(isSelected ? Theme.Palette.accent : Theme.Palette.label)
                    .scaleEffect(isSelected ? 1.1 : 1.0)

                Text(tab.label)
                    .font(Theme.Typography.body(11, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Theme.Palette.accent : Theme.Palette.label)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    let container = AppContainer()
    ExploreShellView(container: container)
        .environment(\.container, container)
}
