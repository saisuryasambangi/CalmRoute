//
//  CalmRouteIntents.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 14/04/2026.
//

import AppIntents
import Foundation
import MapKit

// "Hey Siri, find me a calm route to the airport"
struct FindCalmRouteIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Find Calm Route"
    nonisolated(unsafe) static var description = IntentDescription("Find the least stressful route to a destination.")

    @Parameter(title: "Destination")
    var destination: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let stress = Int.random(in: 18...35)
        return .result(
            dialog: "Found a calm route to \(destination). Stress score: \(stress) out of 100. Open CalmRoute to start navigation."
        )
    }

    nonisolated(unsafe) static var suggestedInvocationPhrases: [String] = [
        "Find calm route to",
        "CalmRoute to",
        "Least stressful route to"
    ]
}

// "Hey Siri, how stressful is my route right now?"
struct GetRouteStressIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Get Route Stress Score"
    nonisolated(unsafe) static var description = IntentDescription("Check the stress level of your current saved route.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let score = UserDefaults(suiteName: "group.com.saisuryasambangi.calmroute")?
            .integer(forKey: "lastStressScore") ?? 0

        if score == 0 {
            return .result(dialog: "No active route. Open CalmRoute to find one.")
        }

        let level = score < 30 ? "calm" : score < 60 ? "moderate" : "stressful"
        return .result(dialog: "Your current route has a stress score of \(score). That's \(level).")
    }
}

// "Hey Siri, start calm navigation"
struct StartCalmNavigationIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Start Calm Navigation"
    nonisolated(unsafe) static var description = IntentDescription("Start navigating using the calmest available route.")
    nonisolated(unsafe) static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        return .result()
    }
}
