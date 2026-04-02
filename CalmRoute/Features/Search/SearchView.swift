//
//  SearchView.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 01/04/2026.
//

@preconcurrency import MapKit
import SwiftUI

// MARK: - Background map

struct LocationMapBackground: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.showsUserLocation = true
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.pointOfInterestFilter = .excludingAll
        map.mapType = .standard
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        guard let coord = coordinate else { return }
        let region = MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 1200,
            longitudinalMeters: 1200
        )
        map.setRegion(region, animated: true)
    }
}

// MARK: - ViewModel

@MainActor
final class SearchViewModel: ObservableObject {

    @Published var query = ""
    @Published var suggestions: [MKMapItem] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var userLocation: CLLocationCoordinate2D?

    private var searchTask: Task<Void, Never>?
    private let locationActor: LocationActor

    init(locationActor: LocationActor) {
        self.locationActor = locationActor
    }

    func onAppear() async {
        await locationActor.requestPermission()
        for await location in await locationActor.stream() {
            userLocation = location.coordinate
            break
        }
    }

    func search() {
        searchTask?.cancel()
        guard query.count >= 2 else { suggestions = []; return }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    private func performSearch() async {
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        if let center = userLocation {
            request.region = MKCoordinateRegion(
                center: center, latitudinalMeters: 50_000, longitudinalMeters: 50_000
            )
        }

        struct Box: @unchecked Sendable { let items: [MKMapItem] }
        let search = MKLocalSearch(request: request)
        let box = await withCheckedContinuation { (c: CheckedContinuation<Box, Never>) in
            search.start { r, _ in c.resume(returning: Box(items: r?.mapItems ?? [])) }
        }
        suggestions = box.items
    }
}

// MARK: - Bottom sheet snap points

private enum SheetSnap: CGFloat {
    case collapsed = 300   // search + saved rows visible
    case expanded  = 620   // hero card + tip fully visible
}

// MARK: - View

struct SearchView: View {

    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm: SearchViewModel

    @AppStorage("homeAddress") private var homeAddress = ""
    @AppStorage("workAddress") private var workAddress = ""

    @State private var sheetHeight: CGFloat = SheetSnap.collapsed.rawValue
    @State private var dragOffset: CGFloat = 0
    @State private var showSettings = false

    init() {
        _vm = StateObject(wrappedValue: SearchViewModel(locationActor: LocationActor()))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {

                // ── Map background ─────────────────────────────────────
                LocationMapBackground(coordinate: vm.userLocation)
                    .ignoresSafeArea()

                // ── App title + settings gear ──────────────────────────
                VStack {
                    HStack {
                        HStack(spacing: 8) {
                            // Green dot — brand accent
                            Circle()
                                .fill(CalmRouteTheme.stressLow)
                                .frame(width: 10, height: 10)
                                .shadow(color: CalmRouteTheme.stressLow, radius: 4)
                            Text("CalmRoute")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        // Layered shadow trick — stacking two shadows gives
                        // readable white text on ANY map tile colour
                        .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: 1)
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
                        .padding(.leading, 20)
                        Spacer()
                        Button {
                            coordinator.show(sheet: .settings)
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    Spacer()
                }

                // ── Draggable bottom sheet ─────────────────────────────
                VStack(spacing: 0) {

                    // Drag handle
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 40, height: 5)
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                    .contentShape(Rectangle())
                    .gesture(dragGesture)

                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(CalmRouteTheme.secondary)
                        TextField("Where to?", text: $vm.query)
                            .submitLabel(.search)
                            .onChange(of: vm.query) { _ in
                                vm.search()
                                if !vm.query.isEmpty {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        sheetHeight = SheetSnap.expanded.rawValue
                                    }
                                }
                            }
                        if !vm.query.isEmpty {
                            Button {
                                vm.query = ""
                                vm.suggestions = []
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    sheetHeight = SheetSnap.collapsed.rawValue
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(CalmRouteTheme.secondary)
                            }
                        }
                        if vm.isSearching { ProgressView().scaleEffect(0.8) }
                    }
                    .padding(13)
                    .background(Color(UIColor.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)

                    // Content below search bar
                    if vm.suggestions.isEmpty && vm.query.isEmpty {
                        savedDestinations
                            .padding(.top, 20)
                    } else {
                        suggestionsList
                    }

                    Spacer()
                }
                .frame(height: sheetHeight - dragOffset)
                .frame(maxWidth: .infinity)
                .background(
                    Color(UIColor.systemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.14), radius: 16, y: -4)
                )
                .gesture(dragGesture)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarHidden(true)
        .task { await vm.onAppear() }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
    }

    // MARK: - Drag gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                // Dragging up = negative translation → expand
                // Dragging down = positive translation → collapse
                let delta = -value.translation.height
                dragOffset = -delta
                // Clamp so sheet can't go below a minimum or above screen
                dragOffset = max(-200, min(200, dragOffset))
            }
            .onEnded { value in
                let velocity = -value.predictedEndTranslation.height
                let currentHeight = sheetHeight - dragOffset
                let threshold: CGFloat = 360   // midpoint between snaps

                withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                    if velocity > 300 || currentHeight > threshold {
                        sheetHeight = SheetSnap.expanded.rawValue
                    } else {
                        sheetHeight = SheetSnap.collapsed.rawValue
                    }
                    dragOffset = 0
                }
            }
    }

    // MARK: - Saved destinations

    private var savedDestinations: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Hero stress card
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Drive calmer today")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Your last route scored 18 — that's low stress.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                }
                .padding(16)
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: 0.18)
                        .stroke(Color.white,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("18")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("stress")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 58, height: 58)
                .padding(.trailing, 16)
            }
            .background(
                LinearGradient(
                    colors: [CalmRouteTheme.stressLow, Color(red: 0.0, green: 0.55, blue: 0.28)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .padding(.horizontal, 16)

            // Saved rows
            VStack(alignment: .leading, spacing: 8) {
                Text("Saved")
                    .font(.subheadline.bold())
                    .foregroundStyle(CalmRouteTheme.secondary)
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    savedRow(icon: "house.fill", color: CalmRouteTheme.stressLow,
                             label: "Home", address: homeAddress)
                    Divider().padding(.leading, 62)
                    savedRow(icon: "briefcase.fill", color: .blue,
                             label: "Work", address: workAddress)
                }
                .background(Color(UIColor.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
            }

            // Tip
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.subheadline)
                Text("Morning routes score ~30% higher due to rush hour. Try leaving 15 min earlier.")
                    .font(.caption)
                    .foregroundStyle(CalmRouteTheme.secondary)
            }
            .padding(14)
            .background(Color(UIColor.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    private func savedRow(icon: String, color: Color, label: String, address: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline.bold())
                Text(address.isEmpty ? "Tap to add" : address)
                    .font(.caption)
                    .foregroundStyle(address.isEmpty ? CalmRouteTheme.secondary : .primary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: address.isEmpty ? "plus.circle" : "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(address.isEmpty ? color : CalmRouteTheme.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if address.isEmpty {
                showSettings = true
            } else {
                vm.query = address
                vm.search()
                Task {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    if let first = vm.suggestions.first {
                        await routeToDestination(first)
                    }
                }
            }
        }
    }

    // MARK: - Suggestions list

    private var suggestionsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(vm.suggestions.enumerated()), id: \.element) { i, item in
                    suggestionRow(item)
                    if i < vm.suggestions.count - 1 {
                        Divider().padding(.leading, 54)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    private func suggestionRow(_ item: MKMapItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(CalmRouteTheme.stressHigh.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "mappin")
                    .font(.subheadline)
                    .foregroundStyle(CalmRouteTheme.stressHigh)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "Unknown").font(.subheadline.bold())
                if let address = item.placemark.title {
                    Text(address).font(.caption)
                        .foregroundStyle(CalmRouteTheme.secondary).lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.query = item.name ?? ""
            Task { await routeToDestination(item) }
        }
    }

    // MARK: - Route calculation

    private func routeToDestination(_ destination: MKMapItem) async {
        let origin = vm.userLocation ?? CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090)
        let weather = await coordinator.weatherService.condition(at: origin)
        do {
            let routes = try await coordinator.routeActor.fetchScoredRoutes(
                from: origin, to: destination, weather: weather
            )
            coordinator.push(.comparison(routes))
        } catch {
            vm.errorMessage = "Couldn't calculate routes. Check your connection."
        }
    }
}
