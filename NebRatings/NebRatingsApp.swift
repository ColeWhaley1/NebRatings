//
//  NebRatingsApp.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/28/25.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct NebRatingsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var store = NebRatingsStore()

    class AppDelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication,
                         didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
            FirebaseApp.configure()
            return true
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If ModelContainer creation fails, create an in-memory container as fallback
            // This prevents app crash and allows basic functionality
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                // Last resort: create empty in-memory container
                return try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(store)
        }
        .modelContainer(sharedModelContainer)
    }
}

struct AppRootView: View {
    @Environment(NebRatingsStore.self) private var store
    @State private var showSplash = true

    var body: some View {
        Group {
            #if DEBUG
            if let snapshot = MarketingSnapshot.requested {
                MarketingSnapshotView(kind: snapshot)
            } else if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
            #else
            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
            #endif
        }
        .onAppear {
            // Show splash for 0.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSplash = false
                }
            }
        }
    }
}
