//
//  ProGate.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 11/04/2026.
//
//  ViewModifier that gates access to Pro-only features.
//  Wraps any view: when isPro == false and the user taps the gated content,
//  PurchaseView is presented as a sheet.
//
//  Usage:
//    SavedRoutesView()
//        .proGate()
//
//  Or with a custom trigger:
//    someView
//        .modifier(ProGate(isPresenting: $showPaywall))
//

import SwiftUI

// MARK: - ViewModifier

struct ProGateModifier: ViewModifier {

    @EnvironmentObject private var store: StoreService
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if !store.isPro {
                    // Semi-transparent overlay with a padlock
                    Color(.systemBackground).opacity(0.85)
                        .overlay(lockOverlay)
                        .contentShape(Rectangle())
                        .onTapGesture { showPaywall = true }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PurchaseView()
                    .environmentObject(store)
            }
    }

    private var lockOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("CalmRoute Pro")
                .font(.subheadline.bold())
            Text("Tap to unlock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - View extension

extension View {
    /// Gates this view behind the Pro paywall when the user is not subscribed.
    func proGate() -> some View {
        modifier(ProGateModifier())
    }
}

// MARK: - Standalone wrapper view

/// Use ProGate as a wrapper when you want to conditionally show content vs
/// the paywall in a declarative way without a ViewModifier.
///
///     ProGate {
///         SavedRoutesView()
///     }
struct ProGate<Content: View>: View {

    @EnvironmentObject private var store: StoreService
    @State private var showPaywall = false

    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if store.isPro {
                content()
            } else {
                paywallPlaceholder
                    .sheet(isPresented: $showPaywall) {
                        PurchaseView()
                            .environmentObject(store)
                    }
            }
        }
    }

    private var paywallPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("CalmRoute Pro")
                .font(.title3.bold())
            Text("Unlock unlimited routes, custom themes, and GPX export.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("See CalmRoute Pro") {
                showPaywall = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
