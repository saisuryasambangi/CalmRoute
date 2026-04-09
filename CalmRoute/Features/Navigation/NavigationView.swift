//
//  NavigationView.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 08/04/2026.
//

import CoreLocation
import MapKit
import SwiftUI

// MARK: - ViewModel

@MainActor
final class NavigationViewModel: ObservableObject {

    @Published var currentStepIndex: Int = 0
    @Published var distanceToNext: CLLocationDistance = 0
    @Published var isArrived = false
    @Published var currentInstruction = "Starting navigation..."

    private let route: ScoredRoute
    private var session: NavigationSessionActor?
    private let locationActor: LocationActor
    private let liveActivity: LiveActivityService
    private var pollTask: Task<Void, Never>?

    init(route: ScoredRoute, locationActor: LocationActor, liveActivity: LiveActivityService) {
        self.route = route
        self.locationActor = locationActor
        self.liveActivity = liveActivity
    }

    func start() async {
        let session = NavigationSessionActor(route: route, liveActivityService: liveActivity)
        self.session = session
        let stream = await locationActor.stream()
        await session.start(locationStream: stream)

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let session = self.session else { break }

                let stepIdx  = await session.currentStepIndex
                let distance = await session.distanceToNextStep
                let arrived  = await session.isArrived

                self.currentStepIndex = stepIdx
                self.distanceToNext   = distance
                self.isArrived        = arrived

                let steps = self.route.route.steps
                if stepIdx < steps.count {
                    self.currentInstruction = steps[stepIdx].instructions
                }

                if arrived { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stop() async {
        pollTask?.cancel()
        await session?.stop()
    }
}

// MARK: - View

struct NavigationView: View {

    let route: ScoredRoute
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm: NavigationViewModel
    @State private var mapRegion: MKCoordinateRegion?

    init(route: ScoredRoute) {
        self.route = route
        _vm = StateObject(wrappedValue: NavigationViewModel(
            route: route,
            locationActor: LocationActor(),
            liveActivity: LiveActivityService()
        ))
    }

    private var stressColor: Color {
        CalmRouteTheme.stressColor(route.stressScore.total)
    }

    var body: some View {
        ZStack {
            StressMapRepresentable(route: route, region: $mapRegion)
                .ignoresSafeArea()

            if vm.isArrived {
                arrivedOverlay
            } else {
                navigationHUD
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Task {
                        await vm.stop()
                        coordinator.popToRoot()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .background(
                            Circle().fill(Color.black.opacity(0.45)).padding(-3)
                        )
                }
            }
        }
        .onAppear {
            // Zoom map to fit the route polyline with padding
            let rect = route.route.polyline.boundingMapRect
            mapRegion = MKCoordinateRegion(rect.insetBy(dx: -rect.size.width * 0.2,
                                                         dy: -rect.size.height * 0.2))
        }
        .task { await vm.start() }
        .onDisappear { Task { await vm.stop() } }
    }

    // MARK: - Navigation HUD

    private var navigationHUD: some View {
        VStack {
            // Top instruction card — dark background so white text is always readable
            HStack(spacing: 14) {
                Circle()
                    .fill(stressColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text(vm.currentInstruction)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if vm.distanceToNext > 0 {
                        Text(formattedDistance(vm.distanceToNext))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                Spacer()

                VStack(spacing: 1) {
                    Text("\(Int(route.stressScore.total))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(stressColor)
                        .monospacedDigit()
                    Text("stress")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.88))
            )
            .padding(.horizontal, CalmRouteTheme.padding)
            .padding(.top, 8)

            Spacer()

            // Bottom ETA strip — same dark treatment
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedTime(route.expectedTravelTime))
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("ETA")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 32)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedDistance(route.distanceMeters))
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("remaining")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.88))
            )
            .padding(.horizontal, CalmRouteTheme.padding)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Arrived overlay

    private var arrivedOverlay: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(CalmRouteTheme.stressLow)
                Text("You've arrived!")
                    .font(.title.bold())
                Text("Stress score for this trip: \(Int(route.stressScore.total))/100")
                    .font(.subheadline)
                    .foregroundStyle(CalmRouteTheme.secondary)
                Button("Done") {
                    coordinator.popToRoot()
                }
                .buttonStyle(.borderedProminent)
                .tint(CalmRouteTheme.stressLow)
            }
            .cardStyle()
            .padding(CalmRouteTheme.padding)
            Spacer()
        }
        .background(Color.black.opacity(0.4).ignoresSafeArea())
    }

    // MARK: - Helpers

    private func formattedDistance(_ meters: CLLocationDistance) -> String {
        meters < 1000
            ? "\(Int(meters)) m"
            : String(format: "%.1f km", meters / 1000)
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        "\(Int(seconds / 60)) min"
    }
}
