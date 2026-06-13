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

    var body: some View {
        ZStack {
            // 1. Sky
            SkyLayer(state: viewModel.sky)

            // 2. World (3D globe)
            WorldView(world: viewModel.world, sky: viewModel.sky,
                      onTapSpecimen: { viewModel.openSpecimen(propID: $0) })
                .ignoresSafeArea()

            // 3. Overlay UI
            VStack {
                HStack(alignment: .top) {
                    Wordmark()
                        // Hidden debug affordance: long-press cycles the sky.
                        .onLongPressGesture(minimumDuration: 0.6) {
                            withAnimation { viewModel.cycleSky() }
                        }
                    Spacer()
                    LocationChip(sky: viewModel.sky)
                }

                Spacer()

                QuestCard(quest: viewModel.suggestedQuest,
                          onBegin: viewModel.beginQuest)
            }
            .padding()
        }
        // 4. Presentation
        .sheet(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .questDetail(let quest):
                QuestDetailView(
                    quest: quest,
                    onComplete: { Task { await viewModel.completeQuest(quest) } }
                )
            case .journal(let quest):
                JournalView(
                    quest: quest,
                    onSave: { viewModel.saveReflection(for: quest, text: $0) },
                    onOpenGrowthLog: viewModel.openGrowthLog
                )
            case .growthLog:
                GrowthLogView()
            case .specimenJournal(let propID):
                if let reflection = viewModel.reflection(forPropID: propID) {
                    SpecimenJournalView(reflection: reflection)
                }
            }
        }
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel(
        sky: StubSkyStateProvider(),
        world: StubWorldStateProvider(),
        quests: StubQuestSuggester()
    ))
}
