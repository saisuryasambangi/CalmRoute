//
//  CalmRouteWidget.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 12/04/2026.
//

import SwiftUI
import WidgetKit

// Home screen widget: "Best time to leave today"
// Reads precomputed stress data from the shared app group
// (populated by BackgroundTaskService).
struct CalmRouteWidget: Widget {
    let kind = "CalmRouteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LeaveTimeProvider()) { entry in
            CalmRouteWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Best Time to Leave")
        .description("See the calmest departure window for your saved route.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline provider

struct LeaveTimeProvider: TimelineProvider {
    typealias Entry = LeaveTimeEntry

    func placeholder(in context: Context) -> LeaveTimeEntry {
        LeaveTimeEntry(date: Date(), stressScore: 28, recommendation: "Leave now", destination: "Work")
    }

    func getSnapshot(in context: Context, completion: @escaping (LeaveTimeEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LeaveTimeEntry>) -> Void) {
        // In production: read from shared AppGroup UserDefaults populated by
        // BackgroundTaskService. For the demo we generate synthetic entries.
        let now = Date()
        var entries: [LeaveTimeEntry] = []

        // Generate hourly snapshots for the next 4 hours
        for hour in 0..<4 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hour, to: now) ?? now
            let h = Calendar.current.component(.hour, from: entryDate)

            // Simulate stress curve — high during rush, low otherwise
            let stress: Int
            let recommendation: String
            switch h {
            case 7...9:
                stress = 72
                recommendation = "Wait 30 min"
            case 10...15:
                stress = 25
                recommendation = "Good time to leave"
            case 16...19:
                stress = 68
                recommendation = "Heavy traffic"
            default:
                stress = 18
                recommendation = "Leave now"
            }

            entries.append(LeaveTimeEntry(
                date: entryDate,
                stressScore: stress,
                recommendation: recommendation,
                destination: "Work"
            ))
        }

        // Refresh every hour
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }
}

// MARK: - Entry

struct LeaveTimeEntry: TimelineEntry {
    let date: Date
    let stressScore: Int
    let recommendation: String
    let destination: String
}

// MARK: - Widget view

struct CalmRouteWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: LeaveTimeEntry

    private var stressColor: Color {
        switch entry.stressScore {
        case ..<30: return .green
        case 30..<60: return .yellow
        default: return .red
        }
    }

    var body: some View {
        switch family {
        case .systemSmall: smallView
        default: mediumView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "road.lanes")
                    .foregroundStyle(stressColor)
                    .font(.caption.bold())
                Text(entry.destination)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text("\(entry.stressScore)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(stressColor)
                .monospacedDigit()
            Text(entry.recommendation)
                .font(.caption.bold())
                .foregroundStyle(stressColor)
        }
        .padding(12)
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "road.lanes")
                        .foregroundStyle(stressColor)
                    Text(entry.destination)
                        .font(.subheadline.bold())
                }
                Text(entry.recommendation)
                    .font(.title3.bold())
                    .foregroundStyle(stressColor)
                Text("Stress score: \(entry.stressScore)/100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(stressColor.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(entry.stressScore) / 100)
                    .stroke(stressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(entry.stressScore)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 60, height: 60)
        }
        .padding(16)
    }
}
