//
//  QuestDetailView.swift
//  Terrarium — QuestFeature
//
//  Stub quest detail sheet. Real quest engine arrives later. // TODO(Phase 1b)
//

import SwiftUI

struct QuestDetailView: View {
    let quest: Quest
    /// Honor verification — "I did it". Grows the world and opens the journal.
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Theme.Palette.cardSurface.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text(quest.placeName.uppercased())
                    .font(Theme.Typography.body(12, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Theme.Palette.label)

                Text(quest.title)
                    .font(Theme.Typography.display(30, weight: .medium))
                    .foregroundStyle(Theme.Palette.title)

                Text(quest.prompt)
                    .font(Theme.Typography.body(17))
                    .foregroundStyle(Theme.Palette.secondary)

                Text("This is a placeholder quest. Soon you'll get directions, a map, and a moment worth recording.")
                    .font(Theme.Typography.body(15))
                    .foregroundStyle(Theme.Palette.secondary)
                    .padding(.top, Theme.Spacing.s)

                Spacer()

                GlowButton(title: "I did it", action: onComplete)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.xl)
        }
    }
}

#Preview {
    QuestDetailView(
        quest: Quest(title: "Ocean Beach at dusk",
                     prompt: "Walk the shore, name three sounds",
                     placeName: "Ocean Beach"),
        onComplete: {}
    )
}
