//
//  CalmRouteApp.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 28/03/2026.
//

import SwiftUI

@main
struct CalmRouteApp: App {

    @StateObject private var coordinator = AppCoordinator()

    init() {
        // BGTask registration must happen before the app finishes launching.
        // If we do it lazily we miss the window and the task never fires.
        BackgroundTaskService.registerTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
        }
    }
}

// MARK: - RootView

struct RootView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            SearchView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .search:
                        SearchView()
                    case .comparison(let routes):
                        RouteComparisonView(routes: routes)
                    case .map(let route):
                        MapView(selectedRoute: route)
                    case .navigating(let route):
                        NavigationView(route: route)
                    }
                }
        }
        .sheet(item: $coordinator.activeSheet) { sheet in
            switch sheet {
            case .routeDetail(let route):
                RouteDetailSheet(route: route)
            case .settings:
                SettingsSheet()
            }
        }
        .tint(CalmRouteTheme.stressLow)
    }
}

// MARK: - Placeholder sheets

struct RouteDetailSheet: View {
    let route: ScoredRoute
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Stress Breakdown") {
                    ForEach(route.stressScore.factors) { factor in
                        HStack {
                            Text(factor.description)
                                .font(.subheadline)
                            Spacer()
                            Text("+\(Int(factor.contribution))")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Route Info") {
                    LabeledContent("Distance", value: formattedDistance(route.distanceMeters))
                    LabeledContent("ETA", value: formattedTime(route.expectedTravelTime))
                    LabeledContent("Stress Score", value: "\(Int(route.stressScore.total))/100")
                }
            }
            .navigationTitle(route.label.rawValue + " Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formattedDistance(_ meters: Double) -> String {
        let km = meters / 1000
        return String(format: "%.1f km", km)
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return "\(minutes) min"
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("homeAddress")  private var homeAddress  = ""
    @AppStorage("workAddress")  private var workAddress  = ""
    @AppStorage("trafficWeight")   private var trafficWeight   = 30.0
    @AppStorage("junctionWeight")  private var junctionWeight  = 25.0
    @AppStorage("weatherWeight")   private var weatherWeight   = 15.0

    @State private var editingHome = false
    @State private var editingWork = false

    var body: some View {
        NavigationStack {
            List {
                // Saved destinations
                Section {
                    destinationRow(
                        icon: "house.fill",
                        iconColor: CalmRouteTheme.stressLow,
                        label: "Home",
                        address: $homeAddress,
                        isEditing: $editingHome
                    )
                    destinationRow(
                        icon: "briefcase.fill",
                        iconColor: .blue,
                        label: "Work",
                        address: $workAddress,
                        isEditing: $editingWork
                    )
                } header: {
                    Text("Saved Destinations")
                } footer: {
                    Text("Tap to set your home and work addresses for quick routing.")
                }

                // Stress weights
                Section {
                    weightRow(label: "Traffic density",  icon: "car.2.fill",
                              color: .orange, value: $trafficWeight)
                    weightRow(label: "Junction count",   icon: "arrow.triangle.branch",
                              color: .blue,   value: $junctionWeight)
                    weightRow(label: "Weather impact",   icon: "cloud.rain.fill",
                              color: .teal,   value: $weatherWeight)
                } header: {
                    Text("Stress Weights")
                } footer: {
                    Text("Adjust how much each factor contributes to the stress score.")
                }

                // About
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Algorithm", value: "Weighted stress model")
                    LabeledContent("Map data", value: "Apple Maps")
                    LabeledContent("Weather", value: "Mock (demo mode)")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func destinationRow(
        icon: String,
        iconColor: Color,
        label: String,
        address: Binding<String>,
        isEditing: Binding<Bool>
    ) -> some View {
        if isEditing.wrappedValue {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.subheadline)
                }
                TextField("Enter \(label.lowercased()) address", text: address)
                    .submitLabel(.done)
                    .onSubmit { isEditing.wrappedValue = false }
                Button {
                    isEditing.wrappedValue = false
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(CalmRouteTheme.stressLow)
                }
            }
        } else {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.subheadline)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.subheadline.bold())
                    Text(address.wrappedValue.isEmpty ? "Tap to add" : address.wrappedValue)
                        .font(.caption)
                        .foregroundStyle(address.wrappedValue.isEmpty ? CalmRouteTheme.secondary : .primary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(CalmRouteTheme.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { isEditing.wrappedValue = true }
        }
    }

    private func weightRow(label: String, icon: String, color: Color, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(value.wrappedValue))%")
                    .font(.subheadline.bold())
                    .foregroundStyle(CalmRouteTheme.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0...60, step: 5)
                .tint(color)
        }
        .padding(.vertical, 4)
    }
}
