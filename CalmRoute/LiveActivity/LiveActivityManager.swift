//
//  LiveActivityManager.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 11/04/2026.
//
//  High-level facade over LiveActivityService for use from NavigationSessionActor
//  and NavigationView. Exposes a minimal API:
//    startActivity / updateActivity / endActivity
//
//  Runs on @MainActor so SwiftUI views can call it without extra hops.
//

import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager: ObservableObject {

    static let shared = LiveActivityManager()

    @Published private(set) var isActive = false

    private let service = LiveActivityService.shared

    private init() {}

    // MARK: - Public API

    /// Starts a Live Activity for the given route.
    /// - Parameters:
    ///   - routeName:  Display name shown in the Dynamic Island expanded view.
    ///   - destination: The destination name shown on the Lock Screen.
    func startActivity(routeName: String, destination: String = "") async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivityManager] Activities not available")
            return
        }
        await service.start(
            routeName: routeName,
            destination: destination.isEmpty ? routeName : destination,
            instruction: "Calculating route…",
            stressScore: 0,
            eta: "--"
        )
        isActive = true
    }

    /// Updates the Live Activity with the latest navigation state.
    /// - Parameters:
    ///   - score:    Current route stress score (0–100).
    ///   - turn:     Next turn instruction, e.g. "Turn right in 200m".
    ///   - distance: Distance to next manoeuvre, e.g. "1.2 km".
    ///   - eta:      Remaining travel time, e.g. "4 min".
    func updateActivity(score: Int, turn: String, distance: String, eta: String) async {
        guard isActive else { return }
        await service.update(
            instruction: turn,
            distanceToNext: distance,
            stressScore: score,
            eta: eta
        )
    }

    /// Ends and dismisses the Live Activity immediately.
    func endActivity() async {
        await service.stop()
        isActive = false
    }
}
