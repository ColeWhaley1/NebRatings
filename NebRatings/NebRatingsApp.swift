//
//  NebRatingsApp.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/28/25.
//

import SwiftUI
import SwiftData

@main
struct NebRatingsApp: App {
    @State private var store = NebRatingsStore()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .modelContainer(sharedModelContainer)
    }
}
