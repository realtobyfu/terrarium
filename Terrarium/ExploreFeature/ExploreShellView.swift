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
//   Tab 1 — Drift             → DriftPlaceholderView (Stream E will replace)
//   Tab 2 — Anchor            → AnchorPlaceholderView (Stream D will replace)
//
//  The Drift/Anchor view models are created once by the container and held in
//  `ExploreShellView` state so model state survives tab switches. Streams D and
//  E will swap the placeholder bodies for the real screens; the view model refs
//  remain stable.
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

                DriftPlaceholderView(viewModel: driftVM)
                    .opacity(selectedTab == .drift ? 1 : 0)
                    .allowsHitTesting(selectedTab == .drift)

                AnchorPlaceholderView(viewModel: anchorVM)
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

// MARK: - Drift placeholder (Stream E will replace the body)

struct DriftPlaceholderView: View {
    @State var viewModel: DriftViewModel

    var body: some View {
        ZStack {
            // Sky-tinted background
            LinearGradient(
                colors: [Color(hex: "B8D4E8"), Color(hex: "E8F4F8")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.Palette.accent)

                VStack(spacing: Theme.Spacing.m) {
                    Text("Drift")
                        .font(Theme.Typography.display(32, weight: .medium))
                        .foregroundStyle(Theme.Palette.title)

                    Text("Start a ramble — your map fills in as you go.")
                        .font(Theme.Typography.body(16))
                        .foregroundStyle(Theme.Palette.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }

                // Session state preview
                if viewModel.session?.isActive == true {
                    SoftPanel {
                        HStack(spacing: Theme.Spacing.m) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text("Ramble in progress")
                                .font(Theme.Typography.body(14, weight: .medium))
                                .foregroundStyle(Theme.Palette.title)
                        }
                        .padding(Theme.Spacing.m)
                    }
                    .padding(.horizontal, Theme.Spacing.l)

                    GlowButton(title: "End Ramble") {
                        viewModel.endRamble()
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                } else {
                    GlowButton(title: "Start a Ramble") {
                        viewModel.startRamble()
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                }

                Spacer()
                // Space for tab bar
                Spacer().frame(height: 80)
            }
        }
    }
}

// MARK: - Anchor placeholder (Stream D will replace the body)

struct AnchorPlaceholderView: View {
    @State var viewModel: AnchorViewModel

    var body: some View {
        ZStack {
            // Warm amber background
            LinearGradient(
                colors: [Color(hex: "F2E2C4"), Color(hex: "FBF2E0")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.Palette.accent)

                VStack(spacing: Theme.Spacing.m) {
                    Text("Anchor")
                        .font(Theme.Typography.display(32, weight: .medium))
                        .foregroundStyle(Theme.Palette.title)

                    Text("No plans? We'll find you one great place to go.")
                        .font(Theme.Typography.body(16))
                        .foregroundStyle(Theme.Palette.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }

                // Show current pick if loaded
                if let pick = viewModel.pick {
                    SoftPanel(cornerRadius: Theme.Radius.card) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                            Text(pick.neighborhood.uppercased())
                                .font(Theme.Typography.body(11, weight: .medium))
                                .tracking(1.2)
                                .foregroundStyle(Theme.Palette.label)

                            Text(pick.name)
                                .font(Theme.Typography.display(22, weight: .medium))
                                .foregroundStyle(Theme.Palette.title)

                            Text(pick.vibe.map(\.rawValue).joined(separator: " · "))
                                .font(Theme.Typography.body(14))
                                .foregroundStyle(Theme.Palette.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.l)
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                }

                GlowButton(title: viewModel.pick == nil ? "Find My Anchor" : "New suggestion") {
                    Task { await viewModel.refresh() }
                }
                .padding(.horizontal, Theme.Spacing.l)

                Spacer()
                // Space for tab bar
                Spacer().frame(height: 80)
            }
        }
        .task {
            // Pre-load a pick when the view appears
            await viewModel.refresh()
        }
    }
}

// MARK: - Preview

#Preview {
    let container = AppContainer()
    ExploreShellView(container: container)
        .environment(\.container, container)
}
