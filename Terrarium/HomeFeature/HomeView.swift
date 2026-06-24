//
//  HomeView.swift
//  Terrarium — HomeFeature
//
//  The layered home screen: SkyLayer (back) → WorldView → OverlayLayer →
//  PresentationLayer (sheets). This composition is the whole point of Phase 1a.
//

import SwiftUI

struct HomeView: View {
    @State var viewModel: HomeViewModel
    @Environment(\.container) private var container

    var body: some View {
        ZStack {
            // 1. Sky
            SkyLayer(state: viewModel.sky)

            // 2. World (3D globe). Keyed on a world signature so it rebuilds when
            // the garden grows (new props) or lushens (vitality), since WorldView
            // only builds its entities once.
            //
            // Skipped under UI testing: RealityKit on a GPU-less CI simulator can
            // hang the accessibility snapshot (and the whole app), which made the
            // screenshot UI test time out. The sky layer behind keeps the frame
            // looking right without the 3D scene.
            if !Self.isUITesting {
                WorldView(world: viewModel.world, sky: viewModel.sky,
                          onTapSpecimen: { viewModel.openSpecimen(propID: $0) })
                    .id(viewModel.globeSignature)
                    .ignoresSafeArea()
            }

            // 3. Bottom reward surface (garden progress).
            VStack {
                Spacer()
                GardenProgressCard(
                    points: viewModel.points,
                    tier: viewModel.tier,
                    progress: viewModel.tierProgress,
                    toNext: viewModel.pointsToNextTier,
                    onOpenLog: viewModel.openGrowthLog
                )
            }
            .padding()
        }
        // Shared glass top bar — same chrome as Drift & Anchor (leaf + weather).
        .safeAreaInset(edge: .top) {
            DiscoveryTopBar(
                weatherSystemImage: viewModel.sky.weather.homeGlyph,
                weatherText: "\(viewModel.sky.weather.homeLabel) · \(viewModel.sky.localTimeLabel)",
                trailing: {
                    GlassIconButton(systemImage: "gearshape.fill",
                                    accessibilityLabel: "Settings",
                                    action: { viewModel.openSettings() })
                        .accessibilityIdentifier("home.settingsButton")
                }
            )
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.s)
            // Hidden debug affordance preserved: long-press the bar cycles the sky.
            .onLongPressGesture(minimumDuration: 0.6) {
                withAnimation { viewModel.cycleSky() }
            }
        }
        .task { viewModel.refresh() }
        // 4. Presentation
        .sheet(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .growthLog:
                GrowthLogView()
            case .specimenJournal(let propID):
                if let reflection = viewModel.reflection(forPropID: propID) {
                    SpecimenJournalView(reflection: reflection)
                }
            case .settings:
                SettingsView(viewModel: container.makeSettingsViewModel())
            }
        }
    }

    /// True when launched by the screenshot UI test, which passes this flag to
    /// suppress the RealityKit globe (see comment at the WorldView site).
    private static let isUITesting =
        ProcessInfo.processInfo.arguments.contains("UITEST_DISABLE_GLOBE")
}

// MARK: - Weather display (file-scoped, mirrors the Explore top bars)

private extension Weather {
    var homeGlyph: String {
        switch self {
        case .clear:  return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .fog:    return "cloud.fog.fill"
        case .rain:   return "cloud.rain.fill"
        case .snow:   return "cloud.snow.fill"
        }
    }
    var homeLabel: String {
        switch self {
        case .clear:  return "Clear"
        case .cloudy: return "Cloudy"
        case .fog:    return "Foggy"
        case .rain:   return "Rainy"
        case .snow:   return "Snowy"
        }
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel(
        sky: StubSkyStateProvider(),
        world: StubWorldStateProvider()
    ))
}
