//
//  TerrariumApp.swift
//  Terrarium
//
//  Created by Tobias Fu on 5/30/26.
//

import SwiftUI

@main
struct TerrariumApp: App {
    /// The composition root, built once for the app's lifetime.
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.container, container)
        }
    }
}
