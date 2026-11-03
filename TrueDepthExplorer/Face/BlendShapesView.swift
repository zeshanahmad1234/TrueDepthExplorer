//
//  BlendShapesView.swift
//  TrueDepthExplorer
//
//  Created by Zeshan Ahmad on 03.11.2026.
//  Copyright © 2026 Zeshan Ahmad. All rights reserved.
//

import SwiftUI
import ARKit

/// Tab 2 — all 52 ARKit blend shape coefficients, live.
///
/// Uses a bare `ARSession` (no SceneKit rendering) with
/// `ARFaceTrackingConfiguration`, which still drives the TrueDepth
/// hardware and publishes the full expression vector every frame.
final class BlendShapeEngine: NSObject, ObservableObject, ARSessionDelegate {

    /// Blend shape values keyed by ARKit name ("eyeBlinkLeft" ...).
    @Published var values: [String: Float] = [:]
    @Published var isRunning = false
    @Published var framesPerSecond: Double = 0
    @Published var isFaceTracked = false

    private var session: ARSession?
    private var lastFrameTimestamp: TimeInterval = 0
    private var lastPublish = Date.distantPast

    func start() {
        guard !isRunning else { return }
        guard ARFaceTrackingConfiguration.isSupported else { return }

        let session = ARSession()
        session.delegate = self
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        session.run(configuration)

        self.session = session
        isRunning = true
    }

    func stop() {
        session?.pause()
        session = nil
        isRunning = false
    }

    // MARK: ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let delta = frame.timestamp - lastFrameTimestamp
        lastFrameTimestamp = frame.timestamp
        if delta > 0 {
            let instant = 1 / delta
            framesPerSecond = framesPerSecond == 0 ? instant : framesPerSecond * 0.9 + instant * 0.1
        }

        guard let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            isFaceTracked = false
            return
        }
        isFaceTracked = face.isTracked

        // 20 Hz is plenty for the bar list and keeps SwiftUI cheap.
        let now = Date()
        guard now.timeIntervalSince(lastPublish) >= 0.05 else { return }
        lastPublish = now

        var updated: [String: Float] = [:]
        updated.reserveCapacity(BlendShapeCatalog.all.count)
        for definition in BlendShapeCatalog.all {
            updated[definition.id] = face.blendShapes[definition.location]?.floatValue ?? 0
        }
        values = updated
    }
}

struct BlendShapesView: View {
    @StateObject private var engine = BlendShapeEngine()

    var body: some View {
        Group {
            if !DeviceCapability.supportsFaceTracking {
                UnsupportedCard(
                    title: "Blend shapes unavailable",
                    message: "The 52 expression coefficients come from the TrueDepth face tracker. Run this on an iPhone X or newer."
                )
            } else {
                shapeList
            }
        }
        .background {
            Theme.background.ignoresSafeArea()
        }
        .onAppear { engine.start() }
        .onDisappear { engine.stop() }
    }

    private var shapeList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                StatChip(title: "FPS", value: String(format: "%.0f", engine.framesPerSecond))
                StatChip(title: "SHAPES", value: "\(BlendShapeCatalog.all.count)")
                StatChip(title: "FACE", value: engine.isFaceTracked ? "LOCKED" : "SEARCHING")
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if !engine.isFaceTracked {
                Text("Hold the phone 30–50 cm from your face, in portrait.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16, pinnedViews: []) {
                    ForEach(BlendShapeGroup.allCases, id: \.rawValue) { group in
                        section(for: group)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }

            CreditFooter()
        }
    }

    @ViewBuilder
    private func section(for group: BlendShapeGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.rawValue)
                .font(.footnote.weight(.bold))
                .foregroundStyle(group.color)
                .padding(.leading, 4)

            ForEach(BlendShapeCatalog.all.filter { $0.group == group }) { definition in
                HStack(spacing: 10) {
                    Text(definition.label)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 128, alignment: .leading)
                    BlendShapeBar(
                        value: engine.values[definition.id] ?? 0,
                        color: group.color
                    )
                    Text("\(Int(round((engine.values[definition.id] ?? 0) * 100)))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.primary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct BlendShapeBar: View {
    let value: Float
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(color)
                    .frame(width: max(3, proxy.size.width * CGFloat(min(1, max(0, value)))))
            }
        }
        .frame(height: 10)
    }
}

#if DEBUG
struct BlendShapesView_Previews: PreviewProvider {
    static var previews: some View {
        BlendShapesView()
    }
}
#endif
