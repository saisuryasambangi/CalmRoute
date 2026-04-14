//
//  LocationPermissionView.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 11/04/2026.
//
//  Shown when location permission has not yet been granted.
//  Presents the rationale and a single CTA that triggers the system prompt.
//

import CoreLocation
import SwiftUI

struct LocationPermissionView: View {

    // Passed in from the parent so this view doesn't need its own actor reference.
    let onRequestPermission: () async -> Void

    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "location.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
            }
            .padding(.bottom, 28)

            // Heading
            Text("Location Access")
                .font(.title2.bold())
                .padding(.bottom, 8)

            // Body copy
            Text("CalmRoute uses your location to calculate stress-scored routes from where you are right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

            // Feature bullets
            VStack(alignment: .leading, spacing: 12) {
                featureBullet(
                    icon: "map.fill",
                    color: .blue,
                    title: "Real-time routing",
                    detail: "Routes start from your current position"
                )
                featureBullet(
                    icon: "shield.fill",
                    color: .green,
                    title: "On-device only",
                    detail: "Your location is never sent to a server"
                )
                featureBullet(
                    icon: "battery.100",
                    color: .orange,
                    title: "While using only",
                    detail: "Location is requested only while the app is open"
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)

            // CTA
            Button {
                guard !isRequesting else { return }
                isRequesting = true
                Task {
                    await onRequestPermission()
                    isRequesting = false
                }
            } label: {
                HStack(spacing: 8) {
                    if isRequesting {
                        ProgressView()
                            .tint(.black)
                            .scaleEffect(0.8)
                    }
                    Text(isRequesting ? "Requesting…" : "Allow Location Access")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.black)
            }
            .disabled(isRequesting)
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func featureBullet(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LocationPermissionView {
        // no-op in preview
    }
}
