//
//  LivenessCheckerView.swift
//  TrueDepthExplorer
//
//  Created by Zeshan Ahmad on 03.11.2026.
//  Copyright © 2026 Zeshan Ahmad. All rights reserved.
//

import SwiftUI
import ARKit
import simd

/// Tab 3 — challenge/response liveness detection.
///
/// A photo or screen replay cannot produce the requested expressions,
/// but the TrueDepth sensor measures the real face doing them. The
/// engine drives the TrueDepth session and evaluates random challenges
/// (blink, smile, jaw, brows, head turns) against the 52 blend shapes
/// plus the measured head pose.
enum LivenessChallenge: String, CaseIterable, Identifiable {
    case blink, smile, jawOpen, browsUp, turnLeft, turnRight

    var id: String { rawValue }

    var instruction: String {
        switch self {
        case .blink: return "Blink both eyes"
        case .smile: return "Smile broadly"
        case .jawOpen: return "Open your mouth"
        case .browsUp: return "Raise your eyebrows"
        case .turnLeft: return "Turn head LEFT"
        case .turnRight: return "Turn head RIGHT"
        }
    }

    var symbol: String {
        switch self {
        case .blink: return "eye"
        case .smile: return "face.smiling"
        case .jawOpen: return "mouth"
        case .browsUp: return "eyebrow"
        case .turnLeft: return "arrow.turn.up.left"
        case .turnRight: return "arrow.turn.up.right"
        }
    }
}

final class LivenessEngine: NSObject, ObservableObject, ARSessionDelegate {

    enum Phase: Equatable {
        case idle
        case running
        case passed
        case failed(String)
    }

    struct Step: Identifiable {
        let id: Int
        let challenge: LivenessChallenge
        var held: Float = 0
        var startedAt: Date?
        var completedAt: Date?

        var progress: Float { min(1, held / LivenessEngine.holdDuration) }
        var isComplete: Bool { completedAt != nil }
    }

    static let holdDuration: Float = 0.4
    static let stepTimeout: TimeInterval = 12
    /// Yaw (radians) that counts as a completed head turn, ~20°.
    static let turnThreshold: Float = 0.35

    @Published var phase: Phase = .idle
    @Published var steps: [Step] = []
    @Published var currentIndex = 0
    @Published var liveYawDegrees: Float = 0
    @Published var isFaceTracked = false
    @Published var framesPerSecond: Double = 0
    @Published var verificationSummary = ""

    private var session: ARSession?
    private var runStartedAt = Date()
    private var lastProcessedAt = Date.distantPast
    private var lastPublish = Date.distantPast

    // MARK: Control

    /// Builds a fresh random sequence (3 = quick check, 6 = full check).
    func configure(numberOfChallenges: Int) {
        let pool = LivenessChallenge.allCases.shuffled()
        steps = pool.prefix(numberOfChallenges).enumerated().map { Step(id: $0.offset, challenge: $0.element) }
        currentIndex = 0
    }

    func start() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        guard !steps.isEmpty else { return }

        runStartedAt = Date()
        lastProcessedAt = Date()
        currentIndex = 0
        for index in steps.indices {
            steps[index].held = 0
            steps[index].startedAt = index == 0 ? Date() : nil
            steps[index].completedAt = nil
        }

        if session == nil {
            let session = ARSession()
            session.delegate = self
            self.session = session
        }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        session?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        phase = .running
    }

    func stop() {
        session?.pause()
    }

    // MARK: Evaluation

    /// 0...1 activation level of a challenge for the current frame.
    static func activation(
        for challenge: LivenessChallenge,
        blendShapes: [ARFaceAnchor.BlendShapeLocation: NSNumber],
        yaw: Float
    ) -> Float {
        func value(_ location: ARFaceAnchor.BlendShapeLocation) -> Float {
            blendShapes[location]?.floatValue ?? 0
        }
        switch challenge {
        case .blink:
            return min(value(.eyeBlinkLeft), value(.eyeBlinkRight))
        case .smile:
            return (value(.mouthSmileLeft) + value(.mouthSmileRight)) / 2
        case .jawOpen:
            return value(.jawOpen)
        case .browsUp:
            return max(value(.browInnerUp), (value(.browOuterUpLeft) + value(.browOuterUpRight)) / 2)
        case .turnLeft:
            return min(1, max(0, yaw / turnThreshold))
        case .turnRight:
            return min(1, max(0, -yaw / turnThreshold))
        }
    }

    private static func makeSummary(steps: [Step], total: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy, HH:mm:ss"
        var lines = ["Verified \(formatter.string(from: Date()))"]
        lines.append("Total time: \(String(format: "%.1f", total)) s")
        for step in steps {
            let seconds = step.completedAt.map { String(format: "%.1f s", $0.timeIntervalSince(step.startedAt ?? $0)) } ?? "—"
            lines.append("• \(step.challenge.instruction): \(seconds)")
        }
        lines.append("TrueDepth Explorer — Developed by Zeshan Ahmad")
        return lines.joined(separator: "\n")
    }

    // MARK: ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard case .running = phase else { return }

        let delta = frame.timestamp - (lastFrameTimestamp ?? frame.timestamp)
        lastFrameTimestamp = frame.timestamp
        if delta > 0 {
            let instant = 1 / delta
            framesPerSecond = framesPerSecond == 0 ? instant : framesPerSecond * 0.9 + instant * 0.1
        }

        processFrame(frame: frame)
    }

    private var lastFrameTimestamp: TimeInterval?

    private func processFrame(frame: ARFrame) {
        let now = Date()
        guard now.timeIntervalSince(lastPublish) >= 0.05 else { return }
        let elapsed = Float(min(0.2, now.timeIntervalSince(lastProcessedAt)))
        lastProcessedAt = now
        lastPublish = now

        guard let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            isFaceTracked = false
            return
        }
        isFaceTracked = face.isTracked

        let quaternion = simd_quatf(face.transform)
        // simd_quatf exposes components only through its simd_float4 vector,
        // and typed intermediates keep the expression small for the type-checker.
        let v = quaternion.vector
        let num: Float = 2 * (v.w * v.z + v.x * v.y)
        let den: Float = 1 - 2 * (v.y * v.y + v.z * v.z)
        let yaw = atan2f(num, den)
        liveYawDegrees = yaw * 180 / Float.pi

        guard currentIndex < steps.count else { return }

        let step = steps[currentIndex]
        let level = Self.activation(for: step.challenge, blendShapes: face.blendShapes, yaw: yaw)

        var updated = steps
        if level > 0.5 {
            updated[currentIndex].held = min(updated[currentIndex].held + elapsed, Self.holdDuration)
        } else {
            // Decay so a partial turn must be completed in one motion.
            updated[currentIndex].held = max(0, updated[currentIndex].held - elapsed * 2)
        }

        if updated[currentIndex].held >= Self.holdDuration {
            updated[currentIndex].completedAt = Date()
            currentIndex += 1
            if currentIndex >= updated.count {
                let total = Date().timeIntervalSince(runStartedAt)
                verificationSummary = Self.makeSummary(steps: updated, total: total)
                steps = updated
                phase = .passed
                session?.pause()
                return
            }
            updated[currentIndex].startedAt = Date()
        } else if let startedAt = updated[currentIndex].startedAt,
                  Date().timeIntervalSince(startedAt) > Self.stepTimeout {
            steps = updated
            phase = .failed("Timed out on “\(step.challenge.instruction)”. Sit 30–50 cm from the phone with your face well lit, then try again.")
            session?.pause()
            return
        }

        steps = updated
    }

    func sessionWasInterrupted(_ session: ARSession) {
        if case .running = phase {
            phase = .failed("The camera session was interrupted (another app or tab used the camera). Try again.")
        }
    }
}

struct LivenessCheckerView: View {
    @StateObject private var engine = LivenessEngine()
    @State private var challengeCount = 3

    var body: some View {
        Group {
            if !DeviceCapability.supportsFaceTracking {
                UnsupportedCard(
                    title: "Liveness unavailable",
                    message: "Liveness checks need the TrueDepth face tracker (iPhone X or newer)."
                )
            } else {
                switch engine.phase {
                case .idle: idleView
                case .running: runningView
                case .passed: passedView
                case .failed(let reason): failedView(reason)
                }
            }
        }
        .background {
            Theme.background.ignoresSafeArea()
        }
        .onDisappear { engine.stop() }
    }

    // MARK: Idle

    private var idleView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.shield")
                .font(.system(size: 52))
                .foregroundStyle(Theme.gradient)
            Text("Liveness Check")
                .font(.title.weight(.bold))
            Text("Complete a short sequence of facial challenges measured by the TrueDepth sensor. A printed photo or a screen replay cannot pass it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Picker("Challenges", selection: $challengeCount) {
                Text("Quick (3)").tag(3)
                Text("Full (6)").tag(6)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)
            .onChange(of: challengeCount) { _ in engine.configure(numberOfChallenges: challengeCount) }

            Button {
                engine.configure(numberOfChallenges: challengeCount)
                engine.start()
            } label: {
                Text("Start Check")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            Spacer()
            CreditFooter()
        }
        .onAppear { engine.configure(numberOfChallenges: challengeCount) }
    }

    // MARK: Running

    private var runningView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                StatChip(title: "FPS", value: String(format: "%.0f", engine.framesPerSecond))
                StatChip(title: "YAW", value: String(format: "%.0f°", engine.liveYawDegrees))
                StatChip(title: "FACE", value: engine.isFaceTracked ? "LOCKED" : "SEARCHING")
            }
            .padding(.top, 10)

            if let step = engine.steps[safe: engine.currentIndex] {
                progressRing(for: step)
                Text(step.challenge.instruction)
                    .font(.title3.weight(.semibold))
                if step.challenge == .turnLeft || step.challenge == .turnRight {
                    Text(engine.liveYawDegrees > 0 ? "→ keep turning" : "← keep turning")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            stepList

            Spacer()

            Button("Cancel") {
                engine.stop()
                engine.phase = .idle
            }
            .buttonStyle(.bordered)

            CreditFooter()
        }
    }

    private func progressRing(for step: LivenessEngine.Step) -> some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 12)
            Circle()
                .trim(from: 0, to: CGFloat(step.progress))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: step.progress)
            Image(systemName: step.challenge.symbol)
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
        }
        .frame(width: 150, height: 150)
        .padding(.top, 8)
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(engine.steps) { step in
                HStack(spacing: 10) {
                    Image(systemName: step.isComplete
                        ? "checkmark.circle.fill"
                        : (engine.steps[safe: engine.currentIndex]?.id == step.id ? "circle.grid.2x1" : "circle"))
                        .foregroundStyle(step.isComplete ? Theme.good : Theme.accent)
                    Text(step.challenge.instruction)
                        .font(.subheadline)
                        .strikethrough(step.isComplete)
                        .foregroundStyle(step.isComplete ? .secondary : .primary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 24)
    }

    // MARK: Passed

    private var passedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.good)
            Text("Liveness Verified")
                .font(.title.weight(.bold))
            ScrollView {
                Text(engine.verificationSummary)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 28)
            Button("Run Again") {
                engine.phase = .idle
            }
            .buttonStyle(.borderedProminent)
            Spacer()
            CreditFooter()
        }
    }

    // MARK: Failed

    private func failedView(_ reason: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.warn)
            Text("Check Failed")
                .font(.title.weight(.bold))
            Text(reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button("Try Again") {
                engine.start()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
            CreditFooter()
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#if DEBUG
struct LivenessCheckerView_Previews: PreviewProvider {
    static var previews: some View {
        LivenessCheckerView()
    }
}
#endif
