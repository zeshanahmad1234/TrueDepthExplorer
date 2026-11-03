//
//  DepthCameraView.swift
//  TrueDepthExplorer
//
//  Created by Zeshan Ahmad on 03.11.2026.
//  Copyright © 2026 Zeshan Ahmad. All rights reserved.
//

import SwiftUI
import AVFoundation
import UIKit

/// Tab 4 — the raw TrueDepth depth stream through AVFoundation.
///
/// `.builtInTrueDepthCamera` opens the physical IR depth module directly;
/// `AVCaptureDepthDataOutput` delivers per-pixel metric depth, which is
/// color-mapped over the live selfie preview.
final class DepthEngine: NSObject, ObservableObject {

    @Published var isSupported = true
    @Published var isRunning = false
    @Published var depthImage: UIImage?
    @Published var distanceMeters: Float = 0
    @Published var minMeters: Float = 0
    @Published var maxMeters: Float = 0
    @Published var depthResolution = ""
    @Published var framesPerSecond: Double = 0
    @Published var quarterTurns = 1
    @Published var isMirrored = true
    @Published var statusMessage = ""

    let session = AVCaptureSession()
    private let depthOutput = AVCaptureDepthDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.zeshanahmad.truedepthexplorer.depth.session")
    private let processingQueue = DispatchQueue(label: "com.zeshanahmad.truedepthexplorer.depth.processing", qos: .userInteractive)
    private let settingsLock = NSLock()

    private var lastImagePublish = Date.distantPast
    private var lastReadoutPublish = Date.distantPast
    private var lastDepthTimestamp: Double = 0
    private var isConfigured = false

    override init() {
        super.init()
        isSupported = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .depthData, position: .front) != nil
    }

    // MARK: Lifecycle

    func start() {
        guard isSupported else { return }
        sessionQueue.async { self.configureIfNeededAndRun() }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    private func configureIfNeededAndRun() {
        if !isConfigured {
            session.beginConfiguration()
            if session.canSetSessionPreset(.vga640x480) {
                session.sessionPreset = .vga640x480
            }

            guard let device = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .depthData, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                DispatchQueue.main.async {
                    self.isSupported = false
                    self.statusMessage = "The TrueDepth camera could not be opened on this device."
                }
                return
            }
            session.addInput(input)

            depthOutput.isFilteringEnabled = true
            depthOutput.alwaysDiscardsLateDepthData = true
            if session.canAddOutput(depthOutput) {
                session.addOutput(depthOutput)
                depthOutput.setDelegate(self, callbackQueue: processingQueue)
            }

            session.commitConfiguration()
            isConfigured = true
        }

        session.startRunning()
        DispatchQueue.main.async { self.isRunning = true }
    }

    // MARK: Display settings (set from UI thread, read on processing queue)

    func updateDisplaySettings(turns: Int? = nil, mirrored: Bool? = nil) {
        settingsLock.lock()
        if let turns { quarterTurns = turns }
        if let mirrored { isMirrored = mirrored }
        settingsLock.unlock()
    }

    private var currentTurns: Int {
        settingsLock.lock(); defer { settingsLock.unlock() }
        return quarterTurns
    }

    private var currentMirrored: Bool {
        settingsLock.lock(); defer { settingsLock.unlock() }
        return isMirrored
    }

    private func publishMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}

// MARK: - AVCaptureDepthDataOutputDelegate

extension DepthEngine: AVCaptureDepthDataOutputDelegate {

    func depthDataOutput(
        _ output: AVCaptureDepthDataOutput,
        didOutput depthData: AVDepthData,
        timestamp: CMTime,
        connection: AVCaptureConnection
    ) {
        // Frame rate estimate.
        let seconds = timestamp.seconds
        if lastDepthTimestamp > 0 {
            let delta = seconds - lastDepthTimestamp
            if delta > 0 {
                let instant = 1 / delta
                publishMain {
                    self.framesPerSecond = self.framesPerSecond == 0
                        ? instant
                        : self.framesPerSecond * 0.9 + instant * 0.1
                }
            }
        }
        lastDepthTimestamp = seconds

        // Everything downstream is metric depth in meters.
        let metricDepth = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let depthMap = metricDepth.depthDataMap

        if depthResolution.isEmpty {
            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            publishMain { self.depthResolution = "\(width) × \(height)" }
        }

        // Center distance readout (~20 Hz).
        let now = Date()
        if now.timeIntervalSince(lastReadoutPublish) >= 0.05 {
            lastReadoutPublish = now
            if let center = DepthColormap.medianDepth(in: depthMap) {
                publishMain { self.distanceMeters = center }
            }
        }

        // Color-mapped overlay (~10 Hz is visually smooth).
        guard now.timeIntervalSince(lastImagePublish) >= 0.1 else { return }
        lastImagePublish = now

        if let stats = DepthColormap.bufferStats(depthMap) {
            publishMain {
                self.minMeters = stats.min
                self.maxMeters = stats.max
            }
        }
        let image = DepthColormap.rgbaImage(
            from: depthMap,
            minMeters: 0.15,
            maxMeters: 1.5,
            quarterTurns: currentTurns,
            mirrored: currentMirrored
        )
        if let image {
            publishMain { self.depthImage = image }
        }
    }
}

// MARK: - Preview

/// UIView backed by AVCaptureVideoPreviewLayer (the live selfie feed
/// behind the transparent depth overlay).
final class PreviewHostView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewHostView, context: Context) {}
}

// MARK: - SwiftUI view

struct DepthCameraView: View {
    @StateObject private var engine = DepthEngine()

    var body: some View {
        Group {
            if !engine.isSupported {
                UnsupportedCard(
                    title: "Depth camera unavailable",
                    message: "This device has no TrueDepth module. Raw IR depth capture needs iPhone X or newer."
                )
            } else {
                depthView
            }
        }
        .background {
            Color.black.ignoresSafeArea()
        }
        .onAppear { engine.start() }
        .onDisappear { engine.stop() }
    }

    private var depthView: some View {
        ZStack {
            CameraPreviewView(session: engine.session)
                .ignoresSafeArea()

            if let image = engine.depthImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.85)
                    .ignoresSafeArea()
            }

            VStack {
                hud
                Spacer()
                controls
                CreditFooter()
            }
        }
    }

    private var hud: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                StatChip(title: "DISTANCE", value: engine.distanceMeters > 0
                    ? String(format: "%.0f cm", engine.distanceMeters * 100)
                    : "—")
                StatChip(title: "FPS", value: String(format: "%.0f", engine.framesPerSecond))
                StatChip(title: "DEPTH MAP", value: engine.depthResolution.isEmpty ? "…" : engine.depthResolution)
            }
            HStack(spacing: 8) {
                StatChip(title: "NEAREST", value: engine.minMeters > 0
                    ? String(format: "%.2f m", engine.minMeters)
                    : "—")
                StatChip(title: "FARTHEST", value: engine.maxMeters > 0
                    ? String(format: "%.2f m", engine.maxMeters)
                    : "—")
            }
            if !engine.statusMessage.isEmpty {
                Text(engine.statusMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.warn)
            }
        }
        .padding(.top, 8)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                engine.updateDisplaySettings(turns: (engine.quarterTurns + 1) % 4)
            } label: {
                Label("Rotate", systemImage: "rotate.right")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.bordered)

            Button {
                engine.updateDisplaySettings(mirrored: !engine.isMirrored)
            } label: {
                Label(engine.isMirrored ? "Mirror: On" : "Mirror: Off", systemImage: "arrow.left.arrow.right")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.bordered)

            Button {
                engine.updateDisplaySettings(turns: 1, mirrored: true)
                engine.depthImage = nil
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
        .padding(.bottom, 4)
    }
}

#if DEBUG
struct DepthCameraView_Previews: PreviewProvider {
    static var previews: some View {
        DepthCameraView()
    }
}
#endif
