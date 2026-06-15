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
    /// `live()` wires the real Explore providers (bundled catalog, WeatherKit,
    /// session location, rules recommender); `init` defaults remain stubs.
    private let container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.container, container)
        }
    }
}
