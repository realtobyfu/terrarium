//
//  ExploreShellView.swift
//  Terrarium — Prototypes (integration)
//
//  The integrated Liquid Glass app shell: one world, one frame. A floating glass
//  3-tab bar (Home · Drift · Anchor) hosts the existing HomeView and DriftView and
//  the new AnchorView (the "Hidden Garden" Anchor screen). The selection
//  highlight glides between tabs with `matchedGeometryEffect`, tabs cross-fade, and
//  the three view models are created once by the container so each tab's state
//  (globe, map camera, current pick) survives switching.
//
//  Replaces `ExploreShellView` as `RootView`'s returning-user surface.
//
//  The frozen kit (LiquidGlassKit / AnchorView / tokens) is *reused*, not
//  modified — the single exception is the additive, default-true `showsNavBar`
//  flag on AnchorView, so the shell can own the one real 3-tab nav without
//  the screen's demo nav doubling up. The generic 3-tab bar lives here (not in the
//  frozen kit) per the stream brief.
//
//  Chrome split across the heterogeneous screens:
//   • Home   — keeps its own identity header (Wordmark + globe); shell adds the nav.
//   • Drift  — gets the shared glass top bar (weather is relevant to a walk) + nav.
//   • Anchor — keeps its own DiscoveryTopBar (same component Drift uses, so the
//              header reads consistently); shell supplies the nav.
//
//  iOS 26: `GlassEffectContainer`-free single `.glassEffect` capsule for the bar
//  (one glass shape, no nesting); `matchedGeometryEffect` for the highlight, kept
//  off the glass so we never nest glass-in-glass.
//

import SwiftUI

// MARK: - Shell tab

enum ExploreTab: Int, CaseIterable, Identifiable {
    case home, drift, anchor
    var id: Int { rawValue }

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
        case .anchor: return "mappin.and.ellipse"
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

    /// Drives the gliding selection highlight in the tab bar.
    @Namespace private var tabHighlight

    init(container: AppContainer) {
        _homeVM   = State(wrappedValue: container.makeHomeViewModel())
        _driftVM  = State(wrappedValue: container.makeDriftViewModel())
        _anchorVM = State(wrappedValue: container.makeAnchorViewModel())
    }

    var body: some View {
        ZStack {
            // Home — its own Wordmark header + globe. Kept alive so the sky/globe
            // state is preserved when switching tabs.
            HomeView(viewModel: homeVM)
                .opacity(selectedTab == .home ? 1 : 0)
                .allowsHitTesting(selectedTab == .home)

            // Drift — the Hidden-Garden ramble + fog map; brings its own glass top
            // bar, the shell owns the nav.
            DriftView(viewModel: driftVM, showsNavBar: false)
                .opacity(selectedTab == .drift ? 1 : 0)
                .allowsHitTesting(selectedTab == .drift)

            // Anchor — the Hidden-Garden concierge; the shell owns the nav.
            AnchorView(viewModel: anchorVM, showsNavBar: false)
                .opacity(selectedTab == .anchor ? 1 : 0)
                .allowsHitTesting(selectedTab == .anchor)
        }
        // The one shared piece of chrome: a floating glass 3-tab bar. safeAreaInset
        // insets every tab's content above it so nothing hides behind the bar, while
        // each screen's full-bleed background (globe/map/wash) slides under the glass.
        .safeAreaInset(edge: .bottom) {
            ExploreTabBar(selection: $selectedTab, namespace: tabHighlight)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.s)
        }
        .ignoresSafeArea(.keyboard)
    }

}

// MARK: - ExploreTabBar

/// A floating Liquid-Glass 3-tab bar. The selected tab's highlight is a soft tinted
/// capsule that glides between items with `matchedGeometryEffect` (kept off the
/// glass so we never nest glass-in-glass). Each tab is a button carrying an
/// `accessibilityLabel` + `.isSelected` trait; hit targets are ≥44pt.
private struct ExploreTabBar: View {
    @Binding var selection: ExploreTab
    var namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ExploreTab.allCases) { tab in
                let isSelected = tab == selection
                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                        selection = tab
                    }
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isSelected ? Theme.Garden.moss
                                                    : Theme.Palette.secondary.opacity(0.7))
                        .frame(width: 72, height: 46)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(Theme.Garden.leaf.opacity(0.45))
                                    .matchedGeometryEffect(id: "glassShellHighlight", in: namespace)
                            }
                        }
                        .scaleEffect(isSelected ? 1.06 : 1)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }
}

// MARK: - Preview

#Preview("Glass Explore Shell") {
    let container = AppContainer()
    return ExploreShellView(container: container)
        .environment(\.container, container)
}
