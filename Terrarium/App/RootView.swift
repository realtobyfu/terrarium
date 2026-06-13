//
//  RootView.swift
//  Terrarium — App
//
//  Pulls the composition root from the environment and launches HomeView.
//

import SwiftUI

struct RootView: View {
    @Environment(\.container) private var container

    var body: some View {
        HomeView(viewModel: container.makeHomeViewModel())
    }
}
