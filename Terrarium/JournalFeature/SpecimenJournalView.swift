//
//  SpecimenJournalView.swift
//  Terrarium — JournalFeature
//
//  Read-only reflection shown when a specimen on the globe is tapped (§E): the
//  place, the day, what you wrote, and whether a photo is attached.
//

import SwiftUI

struct SpecimenJournalView: View {
    let reflection: SpecimenReflection

    private var dateLabel: String {
        reflection.date.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        ZStack {
            Theme.Palette.cardSurface.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text(reflection.placeName.uppercased())
                    .font(Theme.Typography.body(12, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Theme.Palette.label)

                Text(dateLabel)
                    .font(Theme.Typography.display(24, weight: .medium))
                    .foregroundStyle(Theme.Palette.title)

                SoftPanel {
                    Text(reflection.text)
                        .font(Theme.Typography.body(16))
                        .foregroundStyle(Theme.Palette.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.l)
                }

                if reflection.hasPhoto {
                    Label("Photo attached", systemImage: "photo")
                        .font(Theme.Typography.body(14))
                        .foregroundStyle(Theme.Palette.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.xl)
        }
    }
}

#Preview {
    SpecimenJournalView(reflection: SpecimenReflection(
        placeName: "Ocean Beach",
        date: .now,
        text: "The fog came in fast. I named three sounds: gulls, surf, a far-off dog.",
        hasPhoto: true
    ))
}
