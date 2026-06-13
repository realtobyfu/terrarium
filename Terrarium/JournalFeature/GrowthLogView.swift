//
//  GrowthLogView.swift
//  Terrarium — JournalFeature
//
//  Stub growth-log sheet. Later this visualizes the world's vitality over time.
//  // TODO(Phase 1b)
//

import SwiftUI

struct GrowthLogView: View {
    var body: some View {
        ZStack {
            Theme.Palette.cardSurface.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text("GROWTH LOG")
                    .font(Theme.Typography.body(12, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Theme.Palette.label)

                Text("Your world, growing")
                    .font(Theme.Typography.display(26, weight: .medium))
                    .foregroundStyle(Theme.Palette.title)

                ForEach(0..<3, id: \.self) { index in
                    SoftPanel {
                        HStack(spacing: Theme.Spacing.m) {
                            Circle()
                                .fill(Theme.Palette.accent.opacity(0.8))
                                .frame(width: 10, height: 10)
                            Text("Milestone \(index + 1) — coming soon")
                                .font(Theme.Typography.body(15))
                                .foregroundStyle(Theme.Palette.secondary)
                            Spacer()
                        }
                        .padding(Theme.Spacing.l)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.xl)
        }
    }
}

#Preview {
    GrowthLogView()
}
