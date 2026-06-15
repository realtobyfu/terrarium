//
//  AnchorView.swift
//  Terrarium — Prototypes
//
//  A Liquid-Glass redesign of the Anchor concierge screen ("one great place"),
//  built to match the "Magical Discovery / The Hidden Garden" mockup. It is a
//  drop-in alternative to AnchorView: it drives the SAME `AnchorViewModel`
//  (pick · re-roll · Maps handoff · "I'm here" arrival · loading/empty) — only the
//  presentation changes.
//
//  iOS 26 APIs used: glassEffect / GlassEffectContainer (top bar, pills, name
//  card, state cards), .buttonStyle(.glass / .glassProminent) (actions),
//  .scrollEdgeEffectStyle for the floating bar, MeshGradient scenic art, plus
//  .symbolEffect for the reward beat.
//

import SwiftUI

struct AnchorView: View {
    @State var viewModel: AnchorViewModel
    /// Whether to draw this screen's own floating bottom nav. When hosted inside
    /// `ExploreShellView`, the shell supplies the real 3-tab nav, so it passes
    /// `showsNavBar: false` to avoid a duplicate bar. Defaults to `true` so the
    /// standalone screen and all previews are unchanged.
    var showsNavBar: Bool = true
    @State private var navSelection: DiscoveryNavItem = .explore

    var body: some View {
        ZStack {
            backgroundWash.ignoresSafeArea()

            // Floating glass shell. safeAreaInset on the ScrollView keeps content
            // from ever hiding behind the bars (the CTA stays reachable) while the
            // content still slides under the glass with the soft scroll-edge effect.
            scrollContent
                .safeAreaInset(edge: .top) {
                    DiscoveryTopBar(
                        weatherSystemImage: (viewModel.context?.weather ?? .clear).glyph,
                        weatherText: weatherChipText
                    )
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.s)
                }
                .safeAreaInset(edge: .bottom) {
                    pinnedActions
                }
                .safeAreaInset(edge: .bottom) {
                    if showsNavBar {
                        DiscoveryTabBar(selection: $navSelection)
                            .padding(.bottom, Theme.Spacing.s)
                    }
                }
        }
        .task {
            if viewModel.pick == nil && viewModel.arrivalResult == nil {
                await viewModel.refresh()
            }
        }
    }

    // MARK: Scrolling content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                header

                Group {
                    if viewModel.isLoading {
                        LoadingHeroCard()
                    } else if let result = viewModel.arrivalResult {
                        ArrivalCard(
                            placeName: result.poi.name,
                            pointsEarned: result.pointsEarned,
                            tiersGained: result.tiersGained,
                            onAnother: { Task { await viewModel.refresh() } }
                        )
                    } else if let poi = viewModel.pick {
                        // Actions are pinned above the tab bar (see safeAreaInset)
                        // so the CTA is always reachable on this concierge screen.
                        DiscoveryHeroCard(
                            poiRef: poi.poiRef,
                            name: poi.name,
                            category: poi.category,
                            weather: viewModel.context?.weather ?? .clear,
                            eyebrow: "\(poi.category.label) · \(poi.neighborhood)",
                            description: viewModel.vibeLine,
                            openText: viewModel.pickIsLikelyOpen ? "Open Now" : "Hours vary",
                            walkText: viewModel.walkInfo.map { "\($0.walkMinutes) min" }
                        )
                    } else {
                        EmptyDiscoveryCard(onRetry: { Task { await viewModel.refresh() } })
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.l)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("Discovery")
                .font(Theme.Typography.body(13, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(Theme.Garden.mossLight)
            Text("The Hidden Garden")
                .font(Theme.Typography.display(30, weight: .bold))
                .foregroundStyle(Theme.Palette.title)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Actions

    /// Whether the concierge actions should be pinned (only when a pick is shown).
    private var showsActions: Bool {
        viewModel.pick != nil && !viewModel.isLoading && viewModel.arrivalResult == nil
    }

    @ViewBuilder
    private var pinnedActions: some View {
        if showsActions {
            actionArea
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.m)
                .background(
                    // Fade the scrolling content out behind the pinned actions.
                    LinearGradient(
                        colors: [Color(hex: "FBF2E0").opacity(0), Color(hex: "FBF2E0").opacity(0.92), Color(hex: "FBF2E0")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                )
        }
    }

    private var actionArea: some View {
        GlassEffectContainer(spacing: Theme.Spacing.m) {
            VStack(spacing: Theme.Spacing.m) {
                // Primary — Maps handoff (prominent glass, moss tinted).
                Button {
                    viewModel.openInMaps()
                } label: {
                    Label("Take me there", systemImage: "figure.walk")
                        .font(Theme.Typography.body(17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.Garden.moss)
                .controlSize(.large)

                HStack(spacing: Theme.Spacing.m) {
                    // Secondary — re-roll.
                    Button {
                        withAnimation(.smooth) { viewModel.rollAnother() }
                    } label: {
                        Label("Another", systemImage: "arrow.clockwise")
                            .font(Theme.Typography.body(15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glass)
                    .tint(Theme.Garden.mossLight)

                    // Rewarding action — arrival (pine tint sets it apart).
                    Button {
                        Task { await viewModel.arrive() }
                    } label: {
                        Label("I'm here", systemImage: "mappin.and.ellipse")
                            .font(Theme.Typography.body(15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glass)
                    .tint(Theme.Garden.pine)
                }
            }
        }
    }

    // MARK: Helpers

    private var backgroundWash: some View {
        LinearGradient(
            colors: [Color(hex: "F2E8D2"), Color(hex: "FBF2E0"), Color(hex: "EFF1E2")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var weatherChipText: String {
        guard let ctx = viewModel.context else { return "—" }
        return "\(ctx.weather.label) · \(ctx.timeOfDay.rawValue)"
    }
}

// MARK: - State cards

/// Celebratory arrival confirmation (US-D2) styled as a glass island. Frames the
/// reward as points earned (and a garden tier-up when one is crossed).
private struct ArrivalCard: View {
    let placeName: String
    let pointsEarned: Int
    let tiersGained: Int
    let onAnother: () -> Void

    private var grewTier: Bool { tiersGained > 0 }
    private var earned: Bool { pointsEarned > 0 }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: Theme.Spacing.l) {
                Image(systemName: grewTier ? "leaf.circle.fill" : (earned ? "star.circle.fill" : "checkmark.circle.fill"))
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.Garden.moss)
                    .symbolEffect(.bounce, value: pointsEarned)

                Text(grewTier ? "Your garden grew!" : (earned ? "+\(pointsEarned) points" : "You're here"))
                    .font(Theme.Typography.display(24, weight: .bold))
                    .foregroundStyle(Theme.Palette.title)
                    .multilineTextAlignment(.center)

                Text(grewTier
                     ? "\(placeName) pushed your garden to a new level. Tap the globe to see it grow."
                     : (earned
                        ? "Nice find at \(placeName). Keep exploring to grow your garden."
                        : "You've already been to \(placeName)."))
                    .font(Theme.Typography.body(15))
                    .foregroundStyle(Theme.Palette.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.tint(Theme.Garden.leaf.opacity(0.18)), in: .rect(cornerRadius: Theme.Radius.glass))

            Button(action: onAnother) {
                Label("Find another place", systemImage: "sparkles")
                    .font(Theme.Typography.body(17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.Garden.moss)
            .controlSize(.large)
        }
    }
}

/// Friendly empty state when the ranker finds nothing open.
private struct EmptyDiscoveryCard: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: Theme.Spacing.l) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.Garden.pineLight)

                Text("The garden is quiet")
                    .font(Theme.Typography.display(22, weight: .bold))
                    .foregroundStyle(Theme.Palette.title)

                Text("Nothing's open at this hour. Check back soon, or widen your radius in settings.")
                    .font(Theme.Typography.body(15))
                    .foregroundStyle(Theme.Palette.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.glass))

            Button(action: onRetry) {
                Label("Try again", systemImage: "arrow.clockwise")
                    .font(Theme.Typography.body(17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.Garden.moss)
            .controlSize(.large)
        }
    }
}

/// Skeleton while a pick is being assembled.
private struct LoadingHeroCard: View {
    @State private var shimmer = false

    var body: some View {
        SoftPanel(cornerRadius: Theme.Radius.hero) {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                RoundedRectangle(cornerRadius: Theme.Radius.heroInner, style: .continuous)
                    .fill(Theme.Palette.chipSurface)
                    .aspectRatio(4.0 / 5.0, contentMode: .fit)
                    .overlay {
                        VStack(spacing: Theme.Spacing.m) {
                            ProgressView().tint(Theme.Garden.moss)
                            Text("Finding your place…")
                                .font(Theme.Typography.body(15))
                                .foregroundStyle(Theme.Palette.secondary)
                        }
                    }
                    .opacity(shimmer ? 0.6 : 1.0)

                RoundedRectangle(cornerRadius: 6).fill(Theme.Palette.chipSurface).frame(height: 12).frame(maxWidth: 120)
                RoundedRectangle(cornerRadius: 6).fill(Theme.Palette.chipSurface).frame(height: 16)
            }
            .padding(Theme.Spacing.l)
        }
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: shimmer)
        .onAppear { shimmer = true }
    }
}

// MARK: - Weather / category display helpers (file-scoped)

private extension Weather {
    var glyph: String {
        switch self {
        case .clear:  return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .fog:    return "cloud.fog.fill"
        case .rain:   return "cloud.rain.fill"
        case .snow:   return "cloud.snow.fill"
        }
    }
    var label: String {
        switch self {
        case .clear:  return "Clear"
        case .cloudy: return "Cloudy"
        case .fog:    return "Foggy"
        case .rain:   return "Rainy"
        case .snow:   return "Snowy"
        }
    }
}

private extension POICategory {
    var label: String {
        switch self {
        case .park:       return "Park"
        case .coffee:     return "Coffee"
        case .bookstore:  return "Bookstore"
        case .restaurant: return "Restaurant"
        case .viewpoint:  return "Viewpoint"
        case .market:     return "Market"
        case .museum:     return "Museum"
        case .bar:        return "Bar"
        case .other:      return "Spot"
        }
    }
}

// MARK: - Previews

/// A preview-only location session so `walkInfo` resolves (the app stub returns nil).
private final class PreviewLocationSession: LocationSessionProviding {
    private(set) var isActive = false
    func start() { isActive = true }
    func stop() { isActive = false }
    func breadcrumbStream() -> AsyncStream<Coordinate> { AsyncStream { $0.finish() } }
    // ~1 km north of the Mission fixtures → a believable walk time.
    func currentCoordinate() async -> Coordinate? {
        Coordinate(latitude: 37.7686, longitude: -122.4269)
    }
}

private struct PreviewClearWeather: WeatherProviding {
    func current() async -> Weather { .clear }
}

private func makePreviewVM(weather: WeatherProviding, location: LocationSessionProviding) -> AnchorViewModel {
    let store = InMemoryDiscoveryStore()
    let catalog = StubPOICatalog()
    return AnchorViewModel(
        catalog: catalog,
        weather: weather,
        recommender: StubRecommender(catalog: catalog, discoveries: store),
        location: location,
        discoveries: store
    )
}

#Preview("Discovery — clear, with walk time") {
    AnchorView(viewModel: makePreviewVM(
        weather: PreviewClearWeather(),
        location: PreviewLocationSession()
    ))
}

#Preview("Discovery — foggy evening") {
    AnchorView(viewModel: makePreviewVM(
        weather: StubWeatherProvider(),       // returns .fog
        location: StubLocationSession()       // no coordinate → walk pill hidden
    ))
}

#Preview("Arrival — garden grew") {
    ZStack {
        LinearGradient(colors: [Color(hex: "F2E8D2"), Color(hex: "FBF2E0")],
                       startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        ArrivalCard(placeName: "Dolores Park", pointsEarned: 40, tiersGained: 1, onAnother: {})
            .padding()
    }
}

#Preview("Empty state") {
    ZStack {
        LinearGradient(colors: [Color(hex: "F2E8D2"), Color(hex: "FBF2E0")],
                       startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        EmptyDiscoveryCard(onRetry: {})
            .padding()
    }
}
