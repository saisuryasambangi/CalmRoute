//
//  CalmRouteLiveActivity.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 10/04/2026.
//
//  Renders on the Lock Screen and in the Dynamic Island during navigation.
//  No paid account needed — ActivityKit works with free accounts.
//  Only requirement: NSSupportsLiveActivities = YES in Info.plist
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Widget entry point

struct CalmRouteLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CalmRouteActivityAttributes.self) { context in
            // Lock Screen view
            LockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.11, green: 0.11, blue: 0.14))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view (long-press on the island)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(stressColor(context.state.stressScore))
                            .frame(width: 8, height: 8)
                        Text(context.state.stressLevel)
                            .font(.caption2.bold())
                            .foregroundStyle(stressColor(context.state.stressScore))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.eta)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.instruction)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "road.lanes.divided")
                            .foregroundStyle(stressColor(context.state.stressScore))
                        Text(context.attributes.destinationName)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text(context.state.distanceToNext)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                }
            } compactLeading: {
                // Compact leading — small stress dot
                Circle()
                    .fill(stressColor(context.state.stressScore))
                    .frame(width: 8, height: 8)
            } compactTrailing: {
                // Compact trailing — ETA
                Text(context.state.eta)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .monospacedDigit()
            } minimal: {
                // Minimal — just the stress dot
                Circle()
                    .fill(stressColor(context.state.stressScore))
                    .frame(width: 10, height: 10)
            }
            .keylineTint(Color(red: 0.11, green: 0.11, blue: 0.14))
        }
    }

    private func stressColor(_ score: Int) -> Color {
        switch score {
        case ..<30:  return Color(red: 0.20, green: 0.78, blue: 0.35) // green
        case 30..<60: return Color(red: 1.0,  green: 0.58, blue: 0.0)  // orange
        default:      return Color(red: 1.0,  green: 0.23, blue: 0.19) // red
        }
    }
}

// MARK: - Lock Screen view

private struct LockScreenView: View {

    let context: ActivityViewContext<CalmRouteActivityAttributes>

    private var stressColor: Color {
        switch context.state.stressScore {
        case ..<30:  return Color(red: 0.20, green: 0.78, blue: 0.35)
        case 30..<60: return Color(red: 1.0,  green: 0.58, blue: 0.0)
        default:      return Color(red: 1.0,  green: 0.23, blue: 0.19)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left: stress score ring
            ZStack {
                Circle()
                    .stroke(stressColor.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(context.state.stressScore) / 100)
                    .stroke(stressColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(context.state.stressScore)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(stressColor)
                        .monospacedDigit()
                    Text("stress")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 52, height: 52)

            // Center: instruction + destination
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.instruction)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(stressColor)
                    Text(context.attributes.destinationName)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Right: ETA + distance
            VStack(alignment: .trailing, spacing: 4) {
                Text(context.state.eta)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(context.state.distanceToNext)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
    }
}
