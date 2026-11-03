//
//  Theme.swift
//  TrueDepthExplorer
//
//  Created by Zeshan Ahmad on 03.11.2026.
//  Copyright © 2026 Zeshan Ahmad. All rights reserved.
//

import SwiftUI

/// Shared colors, gradients and small reusable views used across all tabs.
enum Theme {
    static let accent = Color(red: 0.15, green: 0.80, blue: 1.00)
    static let secondaryAccent = Color(red: 0.55, green: 0.35, blue: 1.00)
    static let good = Color.green
    static let warn = Color.orange

    static var gradient: LinearGradient {
        LinearGradient(
            colors: [accent, secondaryAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Persistent credit banner shown at the bottom of every tab.
struct CreditFooter: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("TrueDepth Explorer")
                .font(.caption2.weight(.semibold))
            Text("Developed by Zeshan Ahmad")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

/// Compact live metric chip (FPS, vertex count, distance...).
struct StatChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.footnote.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

/// Friendly full-screen explanation shown when the device lacks a
/// TrueDepth sensor / face-tracking support (e.g. iPhone SE, Simulator).
struct UnsupportedCard: View {
    let title: String
    let message: String

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "faceid")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.gradient)
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Text("App by Zeshan Ahmad")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
