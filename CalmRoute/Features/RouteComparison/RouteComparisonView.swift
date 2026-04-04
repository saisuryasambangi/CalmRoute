//
//  RouteComparisonView.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 03/04/2026.
//

import SwiftUI

struct RouteComparisonView: View {

    let routes: [ScoredRoute]
    @EnvironmentObject var coordinator: AppCoordinator

    // Selected route — defaults to calmest
    @State private var selectedIndex: Int = 0

    private var calmest: ScoredRoute? { routes.first(where: { $0.label == .calmest }) ?? routes.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                // Route cards — one per route returned by MKDirections (usually 1–2)
                routeCards

                // Time delta callout (only shown when there are 2+ routes)
                if routes.count >= 2, let calm = calmest {
                    let fastest = routes.first(where: { $0.label == .fastest })
                        ?? routes.dropFirst().first
                    if let fastest {
                        timeDeltaBanner(calm: calm, fast: fastest)
                    }
                }

                // Stress breakdown for selected route
                breakdownSection(for: routes[safe: selectedIndex] ?? routes[0])

                // Action buttons
                if let selected = routes[safe: selectedIndex] {
                    actionButtons(selected)
                }
            }
            .padding(.vertical, CalmRouteTheme.padding)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Choose Your Route")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Route cards

    private var routeCards: some View {
        Group {
            if routes.count == 1 {
                // Single route — full width card
                RouteCard(
                    route: routes[0],
                    isSelected: true,
                    isRecommended: true
                )
                .padding(.horizontal, CalmRouteTheme.padding)
            } else {
                // Multiple routes — scrollable row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(routes.enumerated()), id: \.element.id) { i, route in
                            RouteCard(
                                route: route,
                                isSelected: selectedIndex == i,
                                isRecommended: route.label == .calmest
                            )
                            .frame(width: 180)
                            .onTapGesture { selectedIndex = i }
                        }
                    }
                    .padding(.horizontal, CalmRouteTheme.padding)
                }
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "road.lanes")
                .font(.largeTitle)
                .foregroundStyle(CalmRouteTheme.stressLow)
            Text("Routes compared by stress, not just time")
                .font(.subheadline)
                .foregroundStyle(CalmRouteTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, CalmRouteTheme.padding)
    }

    private func timeDeltaBanner(calm: ScoredRoute, fast: ScoredRoute) -> some View {
        let delta = Int((calm.expectedTravelTime - fast.expectedTravelTime) / 60)
        let stressDelta = Int(fast.stressScore.total - calm.stressScore.total)

        return Group {
            if delta > 0 && stressDelta > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(CalmRouteTheme.stressLow)
                    Text("+\(delta) min for \(stressDelta) less stress points")
                        .font(.subheadline)
                }
                .padding(14)
                .background(
                    CalmRouteTheme.stressLow.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: CalmRouteTheme.radiusSM)
                )
                .padding(.horizontal, CalmRouteTheme.padding)
            }
        }
    }

    private func breakdownSection(for route: ScoredRoute) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why this route was chosen")
                .font(.headline)
                .padding(.horizontal, CalmRouteTheme.padding)

            VStack(spacing: 8) {
                ForEach(route.stressScore.factors) { factor in
                    HStack {
                        Image(systemName: iconFor(factor.kind))
                            .foregroundStyle(CalmRouteTheme.stressLow)
                            .frame(width: 24)
                        Text(factor.description)
                            .font(.subheadline)
                        Spacer()
                    }
                }
                if route.stressScore.factors.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(CalmRouteTheme.stressLow)
                        Text("No significant stress factors")
                            .font(.subheadline)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal, CalmRouteTheme.padding)
        }
    }

    private func actionButtons(_ route: ScoredRoute) -> some View {
        VStack(spacing: 12) {
            Button {
                coordinator.push(.navigating(route))
            } label: {
                HStack {
                    Image(systemName: "road.lanes.divided")
                    Text("Go \(route.label.rawValue)")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    CalmRouteTheme.stressColor(route.stressScore.total),
                    in: RoundedRectangle(cornerRadius: CalmRouteTheme.radius)
                )
                .foregroundStyle(.black)
            }

            Button {
                coordinator.push(.map(route))
            } label: {
                HStack {
                    Image(systemName: "map")
                    Text("Preview on Map")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    CalmRouteTheme.surface,
                    in: RoundedRectangle(cornerRadius: CalmRouteTheme.radius)
                )
                .foregroundStyle(CalmRouteTheme.primary)
            }
        }
        .padding(.horizontal, CalmRouteTheme.padding)
    }

    private func iconFor(_ kind: StressFactor.Kind) -> String {
        switch kind {
        case .traffic:   return "car.2.fill"
        case .junctions: return "arrow.triangle.branch"
        case .roadType:  return "exclamationmark.triangle"
        case .weather:   return "cloud.rain.fill"
        case .timeOfDay: return "clock.fill"
        }
    }
}

// MARK: - Route card

private struct RouteCard: View {

    let route: ScoredRoute
    let isSelected: Bool
    let isRecommended: Bool
    @EnvironmentObject var coordinator: AppCoordinator

    private var stressColor: Color {
        CalmRouteTheme.stressColor(route.stressScore.total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(route.label.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(isRecommended ? .black : CalmRouteTheme.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        isRecommended ? CalmRouteTheme.stressLow : CalmRouteTheme.surface,
                        in: Capsule()
                    )
                Spacer()
                // Info button — tap to see full breakdown sheet
                Button {
                    coordinator.show(sheet: .routeDetail(route))
                } label: {
                    Image(systemName: isRecommended ? "checkmark.seal.fill" : "info.circle")
                        .foregroundStyle(isRecommended ? CalmRouteTheme.stressLow : CalmRouteTheme.secondary)
                        .font(.caption)
                }
            }

            ZStack {
                Circle()
                    .stroke(stressColor.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(route.stressScore.total) / 100)
                    .stroke(stressColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(route.stressScore.total))")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(stressColor)
                        .monospacedDigit()
                    Text("stress")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(CalmRouteTheme.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)

            VStack(alignment: .leading, spacing: 6) {
                statRow(icon: "clock",                 value: "\(Int(route.expectedTravelTime / 60)) min")
                statRow(icon: "arrow.left.and.right",  value: String(format: "%.1f km", route.distanceMeters / 1000))
                statRow(icon: "gauge.medium",          value: route.stressScore.level.rawValue)
            }
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: CalmRouteTheme.radius)
                .stroke(isSelected ? CalmRouteTheme.stressLow : Color.clear, lineWidth: 2)
        )
    }

    private func statRow(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(CalmRouteTheme.secondary)
                .frame(width: 16)
            Text(value)
                .font(.caption.bold())
        }
    }
}

// MARK: - Safe array subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
