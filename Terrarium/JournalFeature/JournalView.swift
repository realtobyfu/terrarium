//
//  JournalView.swift
//  Terrarium — JournalFeature
//
//  Reflective journal sheet (§E): write an optional reflection (and, later, a
//  photo) attached to the specimen the completed quest just grew.
//

import SwiftUI

struct JournalView: View {
    let quest: Quest
    let onSave: (String) -> Void
    let onOpenGrowthLog: () -> Void

    @State private var reflection: String = ""
    @State private var saved = false

    var body: some View {
        ZStack {
            Theme.Palette.cardSurface.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text("JOURNAL")
                    .font(Theme.Typography.body(12, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Theme.Palette.label)

                Text(quest.title)
                    .font(Theme.Typography.display(26, weight: .medium))
                    .foregroundStyle(Theme.Palette.title)

                Text("What did the place give you?")
                    .font(Theme.Typography.body(15))
                    .foregroundStyle(Theme.Palette.secondary)

                SoftPanel {
                    TextEditor(text: $reflection)
                        .font(Theme.Typography.body(15))
                        .foregroundStyle(Theme.Palette.title)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(Theme.Spacing.m)
                }

                GlowButton(title: saved ? "Saved ✓" : "Save reflection") {
                    onSave(reflection)
                    saved = true
                }
                .disabled(reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                Button("View growth log", action: onOpenGrowthLog)
                    .font(Theme.Typography.body(15, weight: .medium))
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.xl)
        }
    }
}

#Preview {
    JournalView(
        quest: Quest(title: "Ocean Beach at dusk",
                     prompt: "Walk the shore, name three sounds",
                     placeName: "Ocean Beach"),
        onSave: { _ in },
        onOpenGrowthLog: {}
    )
}
