//
//  PurchaseView.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 11/04/2026.
//
//  StoreKit 2 paywall screen for CalmRoute Pro.
//  Shown via ProGate when a user tries to access a Pro-only feature.
//

import StoreKit
import SwiftUI

struct PurchaseView: View {

    @EnvironmentObject private var store: StoreService
    @Environment(\.dismiss) private var dismiss

    @State private var showSuccessAnimation = false

    private let proFeatures: [(icon: String, color: Color, title: String, detail: String)] = [
        ("bookmark.fill",    .blue,   "Unlimited saved routes",      "Save as many routes as you like"),
        ("paintpalette.fill", .purple, "Custom stress colour themes", "Personalise low / medium / high colours"),
        ("arrow.up.doc.fill", .green,  "GPX export",                  "Export routes to GPX for any navigation app")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    header
                        .padding(.top, 32)
                        .padding(.bottom, 28)

                    // Feature list
                    VStack(spacing: 12) {
                        ForEach(proFeatures, id: \.title) { feature in
                            featureRow(feature)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)

                    // CTA / success state
                    Group {
                        if showSuccessAnimation {
                            successBanner
                        } else {
                            purchaseCTA
                        }
                    }
                    .padding(.horizontal, 24)

                    // Restore link
                    Button("Restore Purchases") {
                        Task { await store.restorePurchases() }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("CalmRoute Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Not Now") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: store.isPro) { _, newValue in
                if newValue {
                    withAnimation(.spring(response: 0.5)) {
                        showSuccessAnimation = true
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.2), .blue.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                Image(systemName: "road.lanes.divided")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
            }

            Text("CalmRoute Pro")
                .font(.title.bold())

            Text("The calmer commute, unlocked.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func featureRow(_ feature: (icon: String, color: Color, title: String, detail: String)) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(feature.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: feature.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(feature.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.subheadline.bold())
                Text(feature.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var purchaseCTA: some View {
        VStack(spacing: 12) {
            if let error = store.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    do {
                        try await store.purchase()
                    } catch {
                        // StoreError message is localised — surface it.
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if store.isPurchasing {
                        ProgressView().tint(.black).scaleEffect(0.8)
                    }
                    Text(store.isPurchasing ? "Processing…" : priceLabel)
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.black)
            }
            .disabled(store.isPurchasing || store.products.isEmpty)

            Text("One-time purchase · No subscription")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var successBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
                .scaleEffect(showSuccessAnimation ? 1 : 0.1)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showSuccessAnimation)

            Text("Welcome to Pro!")
                .font(.title3.bold())

            Text("All features are now unlocked.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private var priceLabel: String {
        if let product = store.products.first {
            return "Unlock for \(product.displayPrice)"
        }
        return "Unlock for $2.99"
    }
}

// MARK: - Preview

#Preview {
    PurchaseView()
        .environmentObject(StoreService.shared)
}
