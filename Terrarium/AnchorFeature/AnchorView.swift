//
//  AnchorView.swift
//  Terrarium — AnchorFeature
//
//  US-D1 + US-D2: The Anchor concierge screen.
//
//  Layout:
//   • Background: warm amber gradient (matches existing shell palette)
//   • Header: "Anchor" wordmark + current weather/time chip
//   • Pick card: name, category, neighborhood, vibe line, walk time, open indicator
//   • Action row: [Another] (secondary) + [Take me there] (primary)
//   • "I'm here" confirmation card (US-D2) once the user has navigated there
//   • Empty state when the ranker finds nothing open
//   • Location-off state when permissions prevent coordinate use
//

import SwiftUI
import MapKit

struct AnchorView: View {
    @State var viewModel: AnchorViewModel

    var body: some View {
        ZStack {
            // Background
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerBar
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.l)

                Spacer()

                // Main content
                Group {
                    if viewModel.isLoading {
                        loadingState
                    } else if let result = viewModel.arrivalResult {
                        arrivalConfirmation(result)
                    } else if let poi = viewModel.pick {
                        pickCard(poi)
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)

                Spacer()

                // Bottom spacer for the tab bar (ExploreShellView renders it)
                Spacer().frame(height: 88)
            }
        }
        .task {
            if viewModel.pick == nil {
                await viewModel.refresh()
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Background
    // -------------------------------------------------------------------------

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(hex: "F2E2C4"), Color(hex: "FBF2E0")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // -------------------------------------------------------------------------
    // MARK: Header
    // -------------------------------------------------------------------------

    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Anchor")
                    .font(Theme.Typography.display(26, weight: .medium))
                    .foregroundStyle(Theme.Palette.title)
                Text("Your one great place.")
                    .font(Theme.Typography.body(13))
                    .foregroundStyle(Theme.Palette.secondary)
            }

            Spacer()

            if let ctx = viewModel.context {
                contextChip(weather: ctx.weather, timeOfDay: ctx.timeOfDay)
            }
        }
    }

    private func contextChip(weather: Weather, timeOfDay: DayPart) -> some View {
        HStack(spacing: 6) {
            Image(systemName: weatherIcon(weather))
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.accent)
            Text("\(weatherLabel(weather)) · \(timeOfDay.rawValue)")
                .font(Theme.Typography.body(12, weight: .medium))
                .foregroundStyle(Theme.Palette.secondary)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(
            Capsule().fill(Theme.Palette.chipSurface)
        )
        .overlay(
            Capsule().strokeBorder(Theme.Palette.cardBorder, lineWidth: 1)
        )
    }

    // -------------------------------------------------------------------------
    // MARK: Pick card (main state)
    // -------------------------------------------------------------------------

    private func pickCard(_ poi: POI) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            SoftPanel(cornerRadius: Theme.Radius.card) {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {

                    // Category + neighborhood eyebrow
                    HStack {
                        Text("\(categoryLabel(poi.category)) · \(poi.neighborhood)")
                            .font(Theme.Typography.body(12, weight: .medium))
                            .tracking(0.8)
                            .foregroundStyle(Theme.Palette.label)

                        Spacer()

                        openNowPill(poi)
                    }

                    // Place name
                    Text(poi.name)
                        .font(Theme.Typography.display(28, weight: .medium))
                        .foregroundStyle(Theme.Palette.title)
                        .fixedSize(horizontal: false, vertical: true)

                    // Vibe line (weather-aware)
                    if let vibe = viewModel.vibeLine {
                        Text(vibe)
                            .font(Theme.Typography.body(15))
                            .foregroundStyle(Theme.Palette.secondary)
                    }

                    // Walk info (only when coordinate is available)
                    if let walk = viewModel.walkInfo {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Palette.accent)
                            Text(walk.label)
                                .font(Theme.Typography.body(13, weight: .medium))
                                .foregroundStyle(Theme.Palette.secondary)
                        }
                    }

                    // Price + price tier
                    HStack(spacing: 6) {
                        Image(systemName: "tag")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Palette.label)
                        Text(poi.price.rawValue.isEmpty ? "free" : poi.price.rawValue)
                            .font(Theme.Typography.body(13))
                            .foregroundStyle(Theme.Palette.label)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.l)
            }

            // Action buttons
            actionRow
        }
    }

    private func openNowPill(_ poi: POI) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(poi.hoursRef != nil ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(poi.hoursRef != nil ? "Open now" : "Hours vary")
                .font(Theme.Typography.body(11, weight: .medium))
                .foregroundStyle(Theme.Palette.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Theme.Palette.chipSurface)
        )
        .overlay(
            Capsule().strokeBorder(Theme.Palette.cardBorder, lineWidth: 1)
        )
    }

    private var actionRow: some View {
        VStack(spacing: Theme.Spacing.m) {
            // Primary: Maps handoff
            GlowButton(title: "Take me there") {
                viewModel.openInMaps()
            }

            HStack(spacing: Theme.Spacing.m) {
                // Secondary: re-roll
                Button {
                    viewModel.rollAnother()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                        Text("Another")
                            .font(Theme.Typography.body(15, weight: .medium))
                    }
                    .foregroundStyle(Theme.Palette.accent)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.m)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.Palette.chipSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.Palette.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // US-D2 honour-mode arrival
                Button {
                    Task { await viewModel.arrive() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 14, weight: .medium))
                        Text("I'm here")
                            .font(Theme.Typography.body(15, weight: .medium))
                    }
                    .foregroundStyle(Theme.Palette.secondary)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.m)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.Palette.chipSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.Palette.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Arrival confirmation (US-D2)
    // -------------------------------------------------------------------------

    private func arrivalConfirmation(_ result: ArrivalResult) -> some View {
        VStack(spacing: Theme.Spacing.xl) {
            SoftPanel(cornerRadius: Theme.Radius.card) {
                VStack(spacing: Theme.Spacing.l) {
                    Image(systemName: result.specimenGrown ? "leaf.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.Palette.accent)

                    VStack(spacing: Theme.Spacing.s) {
                        Text(result.specimenGrown ? "Your terrarium grew!" : "Arrival recorded")
                            .font(Theme.Typography.display(22, weight: .medium))
                            .foregroundStyle(Theme.Palette.title)

                        Text(result.specimenGrown
                             ? "A new specimen has sprouted at \(result.poi.name)."
                             : "You've been to \(result.poi.name). Discovery logged.")
                            .font(Theme.Typography.body(15))
                            .foregroundStyle(Theme.Palette.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(Theme.Spacing.xl)
                .frame(maxWidth: .infinity)
            }

            GlowButton(title: "Find Another Place") {
                Task { await viewModel.refresh() }
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Empty state
    // -------------------------------------------------------------------------

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "mappin.slash.circle")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Palette.label)

            VStack(spacing: Theme.Spacing.m) {
                Text("Nothing open right now")
                    .font(Theme.Typography.display(22, weight: .medium))
                    .foregroundStyle(Theme.Palette.title)

                Text("The catalog is quiet at this hour. Check back soon, or expand your radius in settings.")
                    .font(Theme.Typography.body(15))
                    .foregroundStyle(Theme.Palette.secondary)
                    .multilineTextAlignment(.center)
            }

            GlowButton(title: "Try Again") {
                Task { await viewModel.refresh() }
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Loading state
    // -------------------------------------------------------------------------

    private var loadingState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Theme.Palette.accent)

            Text("Finding your place…")
                .font(Theme.Typography.body(16))
                .foregroundStyle(Theme.Palette.secondary)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Helpers
    // -------------------------------------------------------------------------

    private func weatherIcon(_ weather: Weather) -> String {
        switch weather {
        case .clear:  return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .fog:    return "cloud.fog.fill"
        case .rain:   return "cloud.rain.fill"
        case .snow:   return "cloud.snow.fill"
        }
    }

    private func weatherLabel(_ weather: Weather) -> String {
        switch weather {
        case .clear:  return "Clear"
        case .cloudy: return "Cloudy"
        case .fog:    return "Foggy"
        case .rain:   return "Rainy"
        case .snow:   return "Snowy"
        }
    }

    private func categoryLabel(_ category: POICategory) -> String {
        switch category {
        case .park:       return "Park"
        case .coffee:     return "Coffee"
        case .bookstore:  return "Bookstore"
        case .restaurant: return "Restaurant"
        case .viewpoint:  return "Viewpoint"
        case .market:     return "Market"
        case .museum:     return "Museum"
        case .bar:        return "Bar"
        case .other:      return "Other"
        }
    }
}

// -------------------------------------------------------------------------
// MARK: Preview
// -------------------------------------------------------------------------

#Preview("Anchor — pick loaded") {
    let vm = AnchorViewModel(
        catalog: StubPOICatalog(),
        weather: StubWeatherProvider(),
        recommender: StubRecommender(
            catalog: StubPOICatalog(),
            discoveries: InMemoryDiscoveryStore()
        ),
        location: StubLocationSession(),
        discoveries: InMemoryDiscoveryStore()
    )
    // Pre-seed state for the preview without async
    return AnchorView(viewModel: vm)
}

#Preview("Anchor — foggy morning") {
    let store = InMemoryDiscoveryStore()
    let catalog = StubPOICatalog()
    let vm = AnchorViewModel(
        catalog: catalog,
        weather: StubWeatherProvider(),   // returns .fog
        recommender: StubRecommender(catalog: catalog, discoveries: store),
        location: StubLocationSession(),
        discoveries: store
    )
    return AnchorView(viewModel: vm)
}
