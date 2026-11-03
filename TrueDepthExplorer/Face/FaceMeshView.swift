//
//  FaceMeshView.swift
//  TrueDepthExplorer
//
//  Created by Zeshan Ahmad on 03.11.2026.
//  Copyright © 2026 Zeshan Ahmad. All rights reserved.
//

import SwiftUI
import ARKit
import SceneKit
import UIKit

/// Tab 1 — live 3D face wireframe straight from the TrueDepth sensor.
///
/// ARFaceTrackingConfiguration drives the IR projector + IR camera;
/// `ARSCNFaceGeometry.update(from:)` pushes the 1,200+ vertex mesh into
/// SceneKit every frame. The engine collects live statistics.
final class FaceTrackingEngine: NSObject, ObservableObject, ARSessionDelegate {

    struct MeshStats {
        var vertexCount = 0
        var triangleCount = 0
        var framesPerSecond: Double = 0
        var depthAvailable = false
        var isFaceTracked = false
        var distanceMeters: Float = 0
        var ambientLight: Float = 0
    }

    @Published var stats = MeshStats()
    @Published var lastError: String?

    private var pendingStats = MeshStats()
    private var lastFrameTimestamp: TimeInterval = 0
    private var lastPublish = Date.distantPast

    /// Called by the SceneKit coordinator each time the mesh geometry updates.
    func noteGeometry(vertexCount: Int, triangleCount: Int) {
        pendingStats.vertexCount = vertexCount
        pendingStats.triangleCount = triangleCount
    }

    func reportError(_ error: Error) {
        DispatchQueue.main.async { self.lastError = error.localizedDescription }
    }

    // MARK: ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let delta = frame.timestamp - lastFrameTimestamp
        lastFrameTimestamp = frame.timestamp

        if delta > 0 {
            let instant = 1 / delta
            pendingStats.framesPerSecond = pendingStats.framesPerSecond == 0
                ? instant
                : pendingStats.framesPerSecond * 0.9 + instant * 0.1
        }

        // Raw IR depth is delivered on the same frame when available.
        pendingStats.depthAvailable = frame.capturedDepthData != nil

        if let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first {
            pendingStats.isFaceTracked = face.isTracked
            // Face anchors are camera-relative; translation.z is the
            // measured distance from the TrueDepth sensor in meters.
            pendingStats.distanceMeters = abs(face.transform.columns.3.z)
        } else {
            pendingStats.isFaceTracked = false
        }

        pendingStats.ambientLight = Float(frame.lightEstimate?.ambientIntensity ?? 0)

        // Throttle SwiftUI updates to ~10 Hz; rendering is unaffected.
        let now = Date()
        guard now.timeIntervalSince(lastPublish) >= 0.1 else { return }
        lastPublish = now
        stats = pendingStats
    }
}

/// UIViewRepresentable that owns the ARSCNView and runs/pauses the
/// face-tracking session according to `isSessionActive` (tab lifecycle).
struct FaceMeshCameraView: UIViewRepresentable {
    @ObservedObject var engine: FaceTrackingEngine
    @Binding var isSessionActive: Bool

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.delegate = context.coordinator
        view.session.delegate = engine
        view.automaticallyUpdatesLighting = true
        view.scene = SCNScene()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        if isSessionActive {
            guard !view.session.isRunning else { return }
            guard ARFaceTrackingConfiguration.isSupported else { return }
            let configuration = ARFaceTrackingConfiguration()
            configuration.isLightEstimationEnabled = true
            view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        } else if view.session.isRunning {
            view.session.pause()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(engine: engine)
    }

    final class Coordinator: NSObject, ARSCNViewDelegate {
        private let engine: FaceTrackingEngine

        init(engine: FaceTrackingEngine) {
            self.engine = engine
            super.init()
        }

        /// Build the wireframe geometry once per detected face.
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARFaceAnchor,
                  let sceneView = renderer as? ARSCNView,
                  let device = sceneView.device,
                  let faceGeometry = ARSCNFaceGeometry(device: device) else {
                return nil
            }
            if let material = faceGeometry.firstMaterial {
                material.fillMode = .lines
                material.lightingModel = .constant
                material.diffuse.contents = UIColor(red: 0.20, green: 0.90, blue: 1.00, alpha: 1.0)
                material.isDoubleSided = true
            }
            return SCNNode(geometry: faceGeometry)
        }

        /// Push the per-frame TrueDepth mesh into SceneKit.
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let geometry = node.geometry as? ARSCNFaceGeometry else { return }
            geometry.update(from: faceAnchor.geometry)
            engine.noteGeometry(
                vertexCount: faceAnchor.geometry.vertexCount,
                triangleCount: faceAnchor.geometry.triangleCount
            )
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            engine.reportError(error)
        }
    }
}

struct FaceMeshView: View {
    @StateObject private var engine = FaceTrackingEngine()
    @State private var isSessionActive = false

    var body: some View {
        ZStack {
            FaceMeshCameraView(engine: engine, isSessionActive: $isSessionActive)
                .ignoresSafeArea()

            VStack {
                statsBar
                    .padding(.horizontal)
                    .padding(.top, 4)
                Spacer()
                CreditFooter()
            }

            if !DeviceCapability.supportsFaceTracking {
                UnsupportedCard(
                    title: "Face tracking unavailable",
                    message: "This device has no TrueDepth camera (or it is disabled). Face tracking needs iPhone X or newer — or an A12+ iPhone using the rear camera."
                )
                .ignoresSafeArea()
            }
        }
        .onAppear { isSessionActive = true }
        .onDisappear { isSessionActive = false }
    }

    private var statsBar: some View {
        HStack(spacing: 8) {
            StatChip(title: "FPS", value: String(format: "%.0f", engine.stats.framesPerSecond))
            StatChip(title: "VERTICES", value: engine.stats.vertexCount == 0 ? "—" : "\(engine.stats.vertexCount)")
            StatChip(title: "TRIANGLES", value: engine.stats.triangleCount == 0 ? "—" : "\(engine.stats.triangleCount)")
            StatChip(title: "DISTANCE", value: engine.stats.distanceMeters > 0
                ? String(format: "%.2f m", engine.stats.distanceMeters)
                : "—")
            StatChip(title: "IR DEPTH", value: engine.stats.depthAvailable ? "LIVE" : "—")
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
struct FaceMeshView_Previews: PreviewProvider {
    static var previews: some View {
        FaceMeshView()
    }
}
#endif
