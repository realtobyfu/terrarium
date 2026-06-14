//
//  LocationPrimingView.swift
//  Terrarium — OnboardingFeature
//
//  US-G2 / FR-7: explains *why* location is needed ("draw your map during walks")
//  before the system CLLocationManager prompt fires. The system prompt is only
//  triggered after the user taps "Enable Location" → `viewModel.proceedWithLocation()`.
//
//  It must NEVER fire on cold launch — this view gates it.
//
//  Stream B (LocationSessionManager) owns the real CLLocationManager prompt. This
//  view calls the `onProceedWithLocationPermission` hook set on the view model,
//  which Stream B will wire to `CLLocationManager.requestWhenInUseAuthorization()`.
//  If the hook is not yet wired (Wave 1 in-progress), tapping "Enable Location"
//  still completes onboarding cleanly — the permission request is a best-effort
//  hook, not a requirement for the onboarding flow to finish.
//

import SwiftUI

struct LocationPrimingView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustration / icon
            ZStack {
                Circle()
                    .fill(Theme.Palette.atmosphere.opacity(0.25))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(Theme.Palette.atmosphere.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "map.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.Palette.accent)
            }
            .padding(.bottom, Theme.Spacing.xl)

            // Headline
            Text("Your walks\ndraw your map")
                .font(Theme.Typography.display(30, weight: .medium))
                .foregroundStyle(Theme.Palette.title)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            // Body copy — answers "why location?"
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                PrimingBullet(
                    icon: "location.fill",
                    title: "Only during your walks",
                    detail: "We track your path only while a Drift session is active — never in the background."
                )
                PrimingBullet(
                    icon: "internaldrive",
                    title: "Everything stays on your device",
                    detail: "Your routes and discoveries are stored locally and never leave your phone."
                )
                PrimingBullet(
                    icon: "lock.shield",
                    title: "When In Use permission only",
                    detail: "We request the minimal permission — we never ask for Always or background access."
                )
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.xl)

            Spacer()

            // Primary CTA: enable location (fires the system prompt via hook)
            GlowButton(title: "Enable Location") {
                viewModel.proceedWithLocation()
            }
            .padding(.horizontal, Theme.Spacing.l)

            // Secondary: skip location for now, still completes onboarding
            Button("Not now") {
                viewModel.skip()
            }
            .font(Theme.Typography.body(15))
            .foregroundStyle(Theme.Palette.secondary)
            .padding(.top, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

// MARK: - PrimingBullet

private struct PrimingBullet: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.body(15, weight: .medium))
                    .foregroundStyle(Theme.Palette.title)
                Text(detail)
                    .font(Theme.Typography.body(14))
                    .foregroundStyle(Theme.Palette.secondary)
            }
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "F5EDD9").ignoresSafeArea()
        LocationPrimingView(viewModel: OnboardingViewModel(store: PreferencesStore()))
    }
}
