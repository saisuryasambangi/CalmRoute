//
//  LiveActivityService.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 10/04/2026.
//
//  Manages the ActivityKit Live Activity lifecycle during navigation.
//  Works with a FREE Apple Developer account.
//  Only requires NSSupportsLiveActivities = YES in Info.plist.
//

import ActivityKit
import Foundation

final class LiveActivityService: Sendable {

    static let shared = LiveActivityService()
    init() {}

    // MARK: - Start

    func start(
        routeName: String,
        destination: String,
        instruction: String,
        stressScore: Int,
        eta: String
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Activities not enabled on this device/simulator")
            return
        }

        let attributes = CalmRouteActivityAttributes(
            routeName: routeName,
            destinationName: destination
        )

        let initialState = CalmRouteActivityAttributes.ContentState(
            instruction: instruction,
            distanceToNext: "",
            stressScore: stressScore,
            eta: eta,
            stressLevel: stressLevelString(stressScore)
        )

        do {
            let _ = try Activity<CalmRouteActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
            print("[LiveActivity] Started successfully")
        } catch {
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
        }
    }

    // MARK: - Update

    func update(
        instruction: String,
        distanceToNext: String,
        stressScore: Int,
        eta: String
    ) async {
        let updatedState = CalmRouteActivityAttributes.ContentState(
            instruction: instruction,
            distanceToNext: distanceToNext,
            stressScore: stressScore,
            eta: eta,
            stressLevel: stressLevelString(stressScore)
        )

        for activity in Activity<CalmRouteActivityAttributes>.activities {
            await activity.update(.init(state: updatedState, staleDate: nil))
        }
    }

    // MARK: - Stop

    func stop() async {
        for activity in Activity<CalmRouteActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        print("[LiveActivity] Stopped")
    }

    // MARK: - Helpers

    private func stressLevelString(_ score: Int) -> String {
        switch score {
        case ..<30:  return "Low"
        case 30..<60: return "Moderate"
        default:      return "High"
        }
    }
}
