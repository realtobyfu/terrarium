//
//  OnboardingGlassComponents.swift
//  Terrarium — Prototypes
//
//  The reusable kit for the Liquid-Glass onboarding redesign (US-G1 / US-G2).
//  These are the "Hidden Garden" counterparts to the cream/serif step controls in
//  OnboardingFeature/: a warm generative backdrop, a glass progress bar, the
//  persona cards, the multi-select chips (interests + vibe), the radius slider,
//  and the location-priming map illustration.
//
//  Built on the iOS 26 Liquid Glass APIs directly (min target is iOS 26, no
//  #available gate) and the FROZEN shared kit (Theme.Garden tokens, Scenic RNG).
//  Selected state is always conveyed with fill + a check/icon + the label — never
//  hue alone (a11y). Pure & stateless: every piece previews in isolation.
//

import SwiftUI

// MARK: - GardenBackdrop

/// A warm, generative "garden" wash used behind every onboarding step. A soft
/// `MeshGradient` (cream identity, a whisper of moss at the foot) replaces the flat
/// `F5EDD9` of the old flow so the screens feel alive without fighting the content.
struct GardenBackdrop: View {
    private static let points: [SIMD2<Float>] = [
        .init(0, 0),    .init(0.5, 0),     .init(1, 0),
        .init(0, 0.5),  .init(0.55, 0.45), .init(1, 0.5),
        .init(0, 1),    .init(0.5, 1),     .init(1, 1),
    ]

    private static let colors: [Color] = [
        Color(hex: "F5ECD8"), Color(hex: "FCF4E3"), Color(hex: "F1EAD6"),
        Color(hex: "EEEAD2"), Color(hex: "F8F1DE"), Color(hex: "E6EBCF"),
        Color(hex: "E2E8C8"), Color(hex: "EEEBD4"), Color(hex: "DBE5C3"),
    ]

    var body: some View {
        MeshGradient(width: 3, height: 3, points: Self.points, colors: Self.colors, smoothsColors: true)
            .overlay(alignment: .top) {
                // Soft skylight so the eye is drawn up to the headline.
                RadialGradient(
                    colors: [Color.white.opacity(0.45), Color.white.opacity(0)],
                    center: .top, startRadius: 0, endRadius: 360
                )
                .blendMode(.softLight)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

// MARK: - OnboardingProgressBar

/// A floating glass progress track: one capsule segment per step, moss for the
/// steps reached, pale leaf for those ahead. Reads as "Step N of M" to VoiceOver.
struct OnboardingProgressBar: View {
    let totalSteps: Int
    /// 0-based index of the current step.
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= currentIndex ? Theme.Garden.moss : Theme.Garden.leaf.opacity(0.4))
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentIndex + 1) of \(totalSteps)")
    }
}

// MARK: - OnboardingStepHeader

/// The shared header for each step: a tracked moss eyebrow, a serif display title,
/// and a rounded subtitle — matching `AnchorView`'s "Hidden Garden" header.
struct OnboardingStepHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text(eyebrow.uppercased())
                .font(Theme.Typography.body(13, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(Theme.Garden.mossLight)

            Text(title)
                .font(Theme.Typography.display(30, weight: .bold))
                .foregroundStyle(Theme.Palette.title)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(Theme.Typography.body(15))
                .foregroundStyle(Theme.Palette.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.s)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Selectable surface (glass when idle, moss fill when chosen)

/// The shared "tap target" surface: a Liquid Glass panel when unselected, and a
/// solid moss island (with a lifted shadow) when selected. Keeping selection a
/// *fill* — paired with the explicit check/label on each control — means the
/// state never rests on hue alone.
private struct SelectableSurface: ViewModifier {
    let isSelected: Bool
    var cornerRadius: CGFloat = Theme.Radius.glass
    var fill: Color = Theme.Garden.moss

    func body(content: Content) -> some View {
        if isSelected {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: fill.opacity(0.35), radius: 14, x: 0, y: 8)
        } else {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

private extension View {
    func selectableSurface(isSelected: Bool, cornerRadius: CGFloat = Theme.Radius.glass) -> some View {
        modifier(SelectableSurface(isSelected: isSelected, cornerRadius: cornerRadius))
    }
}

// MARK: - OnboardingPersonaCard

/// Step 1 control: a roomy explorer card. Selected = moss fill, white content, a
/// filled check. The strongest screen in the old flow — the rest match its weight.
/// (Named `Onboarding…` to avoid clashing with the cream-flow `PersonaCard`.)
struct OnboardingPersonaCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.l) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.22) : Theme.Garden.leaf.opacity(0.35))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Theme.Garden.moss)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Theme.Typography.body(17, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Theme.Palette.title)
                    Text(subtitle)
                        .font(Theme.Typography.body(13))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Theme.Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? .white : Theme.Palette.label.opacity(0.5))
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .selectableSurface(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - SelectableChip

/// Steps 2 & 3 control: a compact multi-select grid cell (icon over label) for
/// interest categories and vibes. Selected = moss fill + a corner check badge.
struct SelectableChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.s) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Theme.Garden.moss)
                Text(label)
                    .font(Theme.Typography.body(14, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Theme.Palette.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.vertical, Theme.Spacing.l)
            .selectableSurface(isSelected: isSelected)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                        .padding(7)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - RadiusSlider

/// Step 4 control: a glass island showing the travel radius as a big serif number
/// + a human label, a concentric "reach" motif that grows with the value, and the
/// moss-tinted slider bound to `OnboardingViewModel.travelRadiusMeters`.
struct RadiusSlider: View {
    @Binding var meters: Double
    var range: ClosedRange<Double> = 500...5000
    var step: Double = 100

    private var fraction: Double {
        (meters - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private var kmText: String { String(format: "%.1f", meters / 1000) }

    private var humanLabel: String {
        switch meters {
        case ..<1000:  return "A short walk"
        case ..<1800:  return "An easy wander"
        case ..<2800:  return "Ready to roam"
        case ..<3800:  return "Going the distance"
        default:       return "Willing to travel far"
        }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            RadiusRings(fraction: fraction)
                .frame(height: 132)

            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(kmText)
                        .font(Theme.Typography.display(46, weight: .bold))
                        .foregroundStyle(Theme.Garden.moss)
                        .contentTransition(.numericText())
                    Text("km")
                        .font(Theme.Typography.body(18, weight: .semibold))
                        .foregroundStyle(Theme.Garden.mossLight)
                }
                Text(humanLabel)
                    .font(Theme.Typography.body(15, weight: .medium))
                    .foregroundStyle(Theme.Palette.secondary)
                    .contentTransition(.opacity)
            }
            .animation(.spring(response: 0.3), value: meters)

            Slider(value: $meters, in: range, step: step) {
                Text("Travel radius")
            } minimumValueLabel: {
                Text("Nearby").font(Theme.Typography.body(12)).foregroundStyle(Theme.Palette.label)
            } maximumValueLabel: {
                Text("Far").font(Theme.Typography.body(12)).foregroundStyle(Theme.Palette.label)
            }
            .tint(Theme.Garden.moss)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.glass))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Travel radius \(kmText) kilometers, \(humanLabel)")
    }
}

/// Concentric "reach" rings — the outer dashed ring grows with the chosen radius,
/// a walking figure pinned at the centre. Decorative; the slider carries the value.
private struct RadiusRings: View {
    let fraction: Double

    private var outer: CGFloat { 72 + 60 * CGFloat(fraction) }

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.Garden.leaf.opacity(0.16))
                .frame(width: outer, height: outer)
            Circle()
                .strokeBorder(
                    Theme.Garden.moss.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 5])
                )
                .frame(width: outer, height: outer)
            Circle()
                .fill(Theme.Garden.moss)
                .frame(width: 34, height: 34)
            Image(systemName: "figure.walk")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: fraction)
        .accessibilityHidden(true)
    }
}

// MARK: - PrimingMapIllustration

/// Step 5 centrepiece: a soft painterly "map" with a dashed footstep trail and a
/// pin, illustrating the promise that *your walks draw your map* — the reassuring
/// picture shown before the system location prompt. Deterministic (seeded).
struct PrimingMapIllustration: View {
    private static let seed = Scenic.seed("onboarding.priming.map")

    var body: some View {
        GeometryReader { geo in
            let trail = Self.trail(in: geo.size)
            ZStack {
                // Painterly meadow wash.
                MeshGradient(
                    width: 3, height: 3,
                    points: ScenicArtBand.meshPoints(seed: Self.seed),
                    colors: [
                        Color(hex: "DDEAF0"), Color(hex: "E9E2EC"), Color(hex: "F2E7CE"),
                        Color(hex: "D7EAB0"), Color(hex: "BBCD96"), Color(hex: "A5D0BE"),
                        Color(hex: "5D6D3E"), Color(hex: "455528"), Color(hex: "3D4C20"),
                    ],
                    smoothsColors: true
                )

                // Dashed footstep trail + breadcrumb dots.
                Canvas { ctx, _ in
                    var path = Path()
                    path.move(to: trail[0])
                    for i in 1..<trail.count {
                        let mid = CGPoint(
                            x: (trail[i - 1].x + trail[i].x) / 2,
                            y: (trail[i - 1].y + trail[i].y) / 2
                        )
                        path.addQuadCurve(to: mid, control: trail[i - 1])
                        path.addLine(to: trail[i])
                    }
                    ctx.stroke(
                        path,
                        with: .color(.white.opacity(0.92)),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 9])
                    )
                    for p in trail {
                        let r: CGFloat = 3
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                            with: .color(.white.opacity(0.85))
                        )
                    }
                }

                // Destination pin at the end of the trail.
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.Garden.bloom, .white)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    .position(x: trail.last!.x, y: trail.last!.y - 14)
            }
        }
        .aspectRatio(1.5, contentMode: .fit)
        .clipShape(.rect(cornerRadius: Theme.Radius.heroInner))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.heroInner, style: .continuous)
                .strokeBorder(Theme.Palette.cardBorder.opacity(0.5), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            WashiTape(width: 78, height: 22, rotation: .degrees(-8))
                .offset(x: 12, y: -8)
        }
        .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
        .accessibilityElement()
        .accessibilityLabel("An illustrated map with a footpath winding toward a pin")
    }

    /// A gentle left-to-right wandering trail, seeded so it never reflows.
    private static func trail(in size: CGSize) -> [CGPoint] {
        var rng = ScenicRNG(seed: seed)
        let count = 6
        return (0..<count).map { i in
            let t = Double(i) / Double(count - 1)
            let x = size.width * (0.12 + 0.74 * t)
            let y = size.height * (0.30 + rng.unitInterval() * 0.42)
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - PrimingReassurance

/// The "why location?" reassurance, as a single tinted glass island of bullets.
struct PrimingReassurance: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            PrimingBullet(
                icon: "location.fill",
                title: "Only during your walks",
                detail: "We trace your path only while a Drift is active — never in the background."
            )
            PrimingBullet(
                icon: "internaldrive",
                title: "Everything stays on device",
                detail: "Your routes and discoveries are stored locally and never leave your phone."
            )
            PrimingBullet(
                icon: "lock.shield",
                title: "When-In-Use only",
                detail: "We ask for the minimal permission — never Always or background access."
            )
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Theme.Garden.leaf.opacity(0.16)), in: .rect(cornerRadius: Theme.Radius.glass))
    }
}

private struct PrimingBullet: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Garden.moss)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.Garden.leaf.opacity(0.3)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.Typography.body(15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.title)
                Text(detail)
                    .font(Theme.Typography.body(14))
                    .foregroundStyle(Theme.Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Onboarding copy (display strings for the domain enums)

/// File-scoped display metadata for the onboarding controls. Kept here (not on the
/// frozen Domain enums) so the prototype owns its own copy without touching the VM.
extension PersonaKind {
    var onboardingTitle: String {
        switch self {
        case .restlessLocal:  return "Restless Local"
        case .newcomer:       return "Newcomer"
        case .weekendDrifter: return "Weekend Drifter"
        }
    }
    var onboardingSubtitle: String {
        switch self {
        case .restlessLocal:  return "I know the city. Surprise me."
        case .newcomer:       return "I'm seeing the city for the first time."
        case .weekendDrifter: return "No plans — give me one good place."
        }
    }
    var onboardingIcon: String {
        switch self {
        case .restlessLocal:  return "figure.walk.motion"
        case .newcomer:       return "binoculars.fill"
        case .weekendDrifter: return "sun.horizon.fill"
        }
    }
    /// Per-persona hint shown under the radius slider (mirrors the radius defaults).
    var radiusHint: String {
        switch self {
        case .restlessLocal:
            return "Restless Locals roam about 2 km — enough to stumble on something new."
        case .newcomer:
            return "Around 1.2 km keeps first discoveries close and easy to find."
        case .weekendDrifter:
            return "Weekend Drifters cast a wide net: 2.5 km means more surprises."
        }
    }
}

extension POICategory {
    var onboardingLabel: String {
        switch self {
        case .park:       return "Parks"
        case .coffee:     return "Coffee"
        case .bookstore:  return "Bookstores"
        case .restaurant: return "Food"
        case .viewpoint:  return "Viewpoints"
        case .market:     return "Markets"
        case .museum:     return "Museums"
        case .bar:        return "Bars"
        case .other:      return "Hidden gems"
        }
    }
    var onboardingIcon: String {
        switch self {
        case .park:       return "tree.fill"
        case .coffee:     return "cup.and.saucer.fill"
        case .bookstore:  return "books.vertical.fill"
        case .restaurant: return "fork.knife"
        case .viewpoint:  return "binoculars.fill"
        case .market:     return "basket.fill"
        case .museum:     return "building.columns.fill"
        case .bar:        return "wineglass.fill"
        case .other:      return "sparkles"
        }
    }
}

extension Vibe {
    var onboardingLabel: String {
        switch self {
        case .quiet:  return "Quiet"
        case .lively: return "Lively"
        case .cozy:   return "Cozy"
        case .scenic: return "Scenic"
        case .quirky: return "Quirky"
        }
    }
    var onboardingIcon: String {
        switch self {
        case .quiet:  return "moon.stars.fill"
        case .lively: return "sparkles"
        case .cozy:   return "flame.fill"
        case .scenic: return "mountain.2.fill"
        case .quirky: return "theatermasks.fill"
        }
    }
}

// MARK: - Previews

#Preview("OnboardingPersonaCard") {
    ZStack {
        GardenBackdrop()
        VStack(spacing: Theme.Spacing.m) {
            OnboardingPersonaCard(
                title: PersonaKind.restlessLocal.onboardingTitle,
                subtitle: PersonaKind.restlessLocal.onboardingSubtitle,
                icon: PersonaKind.restlessLocal.onboardingIcon,
                isSelected: true, action: {}
            )
            OnboardingPersonaCard(
                title: PersonaKind.newcomer.onboardingTitle,
                subtitle: PersonaKind.newcomer.onboardingSubtitle,
                icon: PersonaKind.newcomer.onboardingIcon,
                isSelected: false, action: {}
            )
        }
        .padding()
    }
}

#Preview("SelectableChip grid") {
    ZStack {
        GardenBackdrop()
        GlassEffectContainer(spacing: Theme.Spacing.m) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.m) {
                SelectableChip(label: "Parks", icon: "tree.fill", isSelected: true, action: {})
                SelectableChip(label: "Coffee", icon: "cup.and.saucer.fill", isSelected: false, action: {})
                SelectableChip(label: "Bookstores", icon: "books.vertical.fill", isSelected: false, action: {})
                SelectableChip(label: "Viewpoints", icon: "binoculars.fill", isSelected: true, action: {})
            }
        }
        .padding()
    }
}

#Preview("RadiusSlider") {
    struct Harness: View {
        @State private var meters: Double = 2000
        var body: some View {
            ZStack {
                GardenBackdrop()
                RadiusSlider(meters: $meters).padding()
            }
        }
    }
    return Harness()
}

#Preview("Priming illustration") {
    ZStack {
        GardenBackdrop()
        VStack(spacing: Theme.Spacing.l) {
            PrimingMapIllustration()
            PrimingReassurance()
        }
        .padding()
    }
}
