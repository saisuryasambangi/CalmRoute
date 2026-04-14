//
//  StartNavigationIntent.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 11/04/2026.
//
//  AppIntent that allows Siri / Shortcuts to start stress-aware navigation.
//  Suggested phrase: "Navigate to <destination> with CalmRoute"
//
//  Registration: add StartNavigationIntent to the AppShortcutsProvider below.
//  Info.plist must include the intent class under NSUserActivityTypes if
//  using the older intent pathway; AppIntents registers automatically.
//

import AppIntents
import Foundation

// MARK: - Intent

struct StartNavigationIntent: AppIntent {

    nonisolated(unsafe) static var title: LocalizedStringResource = "Start Stress-Aware Navigation"
    nonisolated(unsafe) static var description = IntentDescription(
        "Start CalmRoute navigation to a destination",
        categoryName: "Navigation"
    )

    /// Opens the app when the intent is performed so the user sees the map.
    nonisolated(unsafe) static var openAppWhenRun: Bool = true

    @Parameter(title: "Destination", description: "Where do you want to go?")
    var destination: String

    // MARK: - Perform

    func perform() async throws -> some IntentResult & OpensIntent {
        // Store the destination in shared UserDefaults so the app reads it
        // on launch and pre-fills the search field.
        UserDefaults(suiteName: "group.com.saisuryasambangi.calmroute")?
            .set(destination, forKey: "siriNavigationDestination")

        // The app is opened by openAppWhenRun = true. The destination is
        // picked up in SearchView via onReceive(NotificationCenter).
        NotificationCenter.default.post(
            name: .startNavigationFromSiri,
            object: destination
        )

        return .result()
    }
}

// MARK: - Notification name

extension Notification.Name {
    /// Posted by StartNavigationIntent so SearchView can pre-fill the query.
    static let startNavigationFromSiri = Notification.Name(
        "com.saisuryasambangi.calmroute.startNavigationFromSiri"
    )
}

// MARK: - App shortcuts provider

struct CalmRouteShortcuts: AppShortcutsProvider {

    nonisolated(unsafe) static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartNavigationIntent(),
            phrases: [
                "Navigate to \(\.$destination) with CalmRoute",
                "Start CalmRoute to \(\.$destination)",
                "Find calm route to \(\.$destination)"
            ],
            shortTitle: "Start Navigation",
            systemImageName: "road.lanes"
        )
    }
}
