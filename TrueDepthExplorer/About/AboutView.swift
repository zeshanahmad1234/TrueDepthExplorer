//
//  AboutView.swift
//  TrueDepthExplorer
//
//  Created by Zeshan Ahmad on 03.11.2026.
//  Copyright © 2026 Zeshan Ahmad. All rights reserved.
//

import SwiftUI

/// Tab 5 — what this device can do, what the app does, and who made it.
struct AboutView: View {
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (build \(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Developer card
                VStack(spacing: 6) {
                    Image(systemName: "faceid")
                        .font(.system(size: 46))
                        .foregroundStyle(Theme.gradient)
                    Text("TrueDepth Explorer")
                        .font(.title2.weight(.bold))
                    Text("Developed by Zeshan Ahmad")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text("Version \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Capability report
                VStack(alignment: .leading, spacing: 10) {
                    Text("This device")
                        .font(.headline)
                    LabeledRow(label: "Model", value: DeviceCapability.deviceModelIdentifier)
                    LabeledRow(label: "iOS", value: DeviceCapability.systemVersion)
                    ForEach(DeviceCapability.capabilityReport, id: \.name) { row in
                        HStack {
                            Text(row.name)
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: row.supported ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(row.supported ? Theme.good : Theme.warn)
                            Text(row.supported ? "Supported" : "Not available")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                // What the app does
                VStack(alignment: .leading, spacing: 10) {
                    Text("What this app demonstrates")
                        .font(.headline)
                    FeatureRow(
                        symbol: "faceid",
                        title: "Face Mesh",
                        text: "ARFaceTrackingConfiguration drives the IR projector and IR camera; ARSCNFaceGeometry renders the 1,200+ vertex mesh measured in 3D."
                    )
                    FeatureRow(
                        symbol: "face.dashed",
                        title: "Expressions",
                        text: "The 52 ARKit blend shape coefficients, streamed live — the same vector that powers Animoji and Memoji."
                    )
                    FeatureRow(
                        symbol: "checkmark.shield",
                        title: "Liveness",
                        text: "Challenge/response checks (blink, smile, head turns) that a photo or screen replay cannot pass, because the depth sensor measures real 3D motion."
                    )
                    FeatureRow(
                        symbol: "ruler",
                        title: "IR Depth",
                        text: "AVCaptureDepthDataOutput reads .builtInTrueDepthCamera directly: per-pixel metric depth in meters, color-mapped in real time."
                    )
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Privacy note
                VStack(alignment: .leading, spacing: 8) {
                    Label("Privacy", systemImage: "lock.shield")
                        .font(.headline)
                    Text("Every frame is processed on-device. The TrueDepth Explorer app does not record, store, or transmit camera or depth data. No analytics, no network access.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text("© 2026 Zeshan Ahmad — MIT License")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .background {
            Theme.background.ignoresSafeArea()
        }
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospaced())
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
#endif
