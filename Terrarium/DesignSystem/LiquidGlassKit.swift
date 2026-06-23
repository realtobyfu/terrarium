//
//  LiquidGlassKit.swift
//  Terrarium — Prototypes
//
//  The reusable chrome for the discovery prototype, built on the iOS 26 Liquid
//  Glass APIs (`glassEffect`, `GlassEffectContainer`, `glassEffectID`, the glass
//  button styles). These are the "semantic shell" pieces from the mockup:
//
//    • WashiTape           — the decorative taped-down sticker accent
//    • OrganicPill         — the "Open Now" / "12 min" status pills (glass)
//    • GlassIconButton     — circular glass icon button
//    • TactilePrimaryButtonStyle — the candy 3D press (alternative to glassProminent)
//    • DiscoveryTopBar     — floating glass app bar (leaf · wordmark · weather)
//    • DiscoveryTabBar     — floating glass bottom nav with a morphing selection
//
//  Min target is iOS 26 so the glass APIs are used directly (no #available gate).
//

import SwiftUI

// MARK: - WashiTape

/// A translucent strip of "washi tape" — the hand-placed sticker accent that
/// gives the cards their tactile, scrapbook feel.
struct WashiTape: View {
    var width: CGFloat = 96
    var height: CGFloat = 24
    var rotation: Angle = .degrees(-6)
    var opacity: Double = 0.85

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.95), Color(hex: "F1EEDD").opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
            )
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.12), radius: 2, x: 1, y: 1)
            .rotationEffect(rotation)
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - OrganicPill

/// A small glass status pill — icon + label. Used for "Open Now" and walk time.
/// Colour is conveyed *with* an icon + text so it never relies on hue alone (a11y).
struct OrganicPill: View {
    let systemImage: String
    let text: String
    var tint: Color = Theme.Palette.accent

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(Theme.Typography.body(13, weight: .semibold))
        }
        .foregroundStyle(Theme.Palette.title)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassEffect(.regular.tint(tint.opacity(0.22)), in: .capsule)
    }
}

// MARK: - GlassIconButton

/// A circular Liquid Glass icon button (top-bar affordances).
struct GlassIconButton: View {
    let systemImage: String
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.Garden.moss)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.glass)
        .clipShape(.circle)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - TactilePrimaryButtonStyle

/// The "candy" 3D button from the mockup: a solid moss capsule with a darker
/// bottom lip that compresses on press. Offered as an alternative to
/// `.buttonStyle(.glassProminent)` when the tactile look is wanted over glass.
struct TactilePrimaryButtonStyle: ButtonStyle {
    var fill: Color = Theme.Garden.moss
    var edge: Color = Theme.Garden.mossDeep

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(Theme.Typography.body(17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule(style: .continuous).fill(fill)
            )
            .overlay(alignment: .bottom) {
                // The 3D lip — thins as the button is pressed in.
                Capsule(style: .continuous)
                    .fill(edge)
                    .frame(height: pressed ? 1 : 3)
                    .padding(.horizontal, 2)
                    .offset(y: pressed ? 0 : 2)
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
            }
            .shadow(color: fill.opacity(pressed ? 0.15 : 0.35), radius: pressed ? 4 : 10, y: pressed ? 1 : 4)
            .scaleEffect(pressed ? 0.97 : 1)
            .offset(y: pressed ? 2 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: pressed)
    }
}

// MARK: - DiscoveryTopBar

/// Floating glass app bar: leaf affordance · "Terrarium" wordmark · weather chip.
/// Mirrors the mockup's pill header and stays clear of the Dynamic Island.
struct DiscoveryTopBar<Trailing: View>: View {
    var weatherSystemImage: String
    var weatherText: String
    var onLeading: () -> Void = {}
    /// Optional accessory pinned to the far trailing edge (e.g. a Settings gear).
    /// Defaults to `EmptyView` via the convenience init below, so existing call
    /// sites are unaffected.
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                GlassIconButton(systemImage: "leaf.fill",
                                accessibilityLabel: "Garden menu",
                                action: onLeading)

                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    Image(systemName: weatherSystemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accent)
                    Text(weatherText)
                        .font(Theme.Typography.body(12, weight: .medium))
                        .foregroundStyle(Theme.Palette.secondary)
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .glassEffect(.regular, in: .capsule)
                .accessibilityElement(children: .combine)

                trailing()
            }
        }
    }
}

extension DiscoveryTopBar where Trailing == EmptyView {
    /// Convenience init for the common case with no trailing accessory.
    init(weatherSystemImage: String,
         weatherText: String,
         onLeading: @escaping () -> Void = {}) {
        self.init(weatherSystemImage: weatherSystemImage,
                  weatherText: weatherText,
                  onLeading: onLeading,
                  trailing: { EmptyView() })
    }
}

// MARK: - DiscoveryTabBar

enum DiscoveryNavItem: Int, CaseIterable, Identifiable {
    case garden, explore, journal, profile
    var id: Int { rawValue }

    var systemImage: String {
        switch self {
        case .garden:  return "globe.americas.fill"
        case .explore: return "safari.fill"
        case .journal: return "book.fill"
        case .profile: return "person.fill"
        }
    }
    var label: String {
        switch self {
        case .garden:  return "Garden"
        case .explore: return "Explore"
        case .journal: return "Journal"
        case .profile: return "Profile"
        }
    }
}

/// Floating glass bottom navigation. The selection highlight glides between items
/// with `matchedGeometryEffect` (a soft tinted capsule, kept off-glass so we never
/// nest glass-in-glass).
struct DiscoveryTabBar: View {
    @Binding var selection: DiscoveryNavItem
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DiscoveryNavItem.allCases) { item in
                let isSelected = item == selection
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                        selection = item
                    }
                } label: {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isSelected ? Theme.Garden.moss : Theme.Palette.secondary.opacity(0.7))
                        .frame(width: 52, height: 44)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(Theme.Garden.leaf.opacity(0.45))
                                    .matchedGeometryEffect(id: "tabHighlight", in: highlight)
                            }
                        }
                        .scaleEffect(isSelected ? 1.06 : 1)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }
}

// MARK: - Previews

#Preview("Glass chrome") {
    ZStack {
        LinearGradient(colors: [Color(hex: "F2E2C4"), Color(hex: "FBF2E0")],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

        VStack {
            DiscoveryTopBar(weatherSystemImage: "cloud.fog.fill", weatherText: "Foggy · evening")
                .padding(.horizontal)

            Spacer()

            HStack(spacing: 10) {
                OrganicPill(systemImage: "leaf.fill", text: "Open Now", tint: Theme.Garden.moss)
                OrganicPill(systemImage: "figure.walk", text: "12 min", tint: Theme.Garden.bloom)
            }

            Button("Take me there") {}
                .buttonStyle(TactilePrimaryButtonStyle())
                .padding(.horizontal, 40)
                .padding(.top, 8)

            Spacer()

            DiscoveryTabBarPreviewHarness()
                .padding(.bottom)
        }
    }
}

private struct DiscoveryTabBarPreviewHarness: View {
    @State private var sel: DiscoveryNavItem = .explore
    var body: some View { DiscoveryTabBar(selection: $sel) }
}
