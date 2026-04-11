//
//  CalmRouteAttributes.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 10/04/2026.
//

import ActivityKit
import Foundation

struct CalmRouteActivityAttributes: ActivityAttributes {

    // Static data — set once when the activity starts, never changes
    var routeName: String
    var destinationName: String

    // Dynamic data — updated as navigation progresses
    struct ContentState: Codable, Hashable {
        var instruction: String       // "Turn right on Oak St"
        var distanceToNext: String    // "400 m"
        var stressScore: Int          // 0–100
        var eta: String               // "14 min"
        var stressLevel: String       // "Low" / "Moderate" / "High"
    }
}
