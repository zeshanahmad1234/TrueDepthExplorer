//
//  DeviceCapability.swift
//  TrueDepthExplorer
//
//  Created by Zeshan Ahmad on 03.11.2026.
//  Copyright © 2026 Zeshan Ahmad. All rights reserved.
//

import Foundation
import ARKit
import AVFoundation
import UIKit

/// Single source of truth for "what can this device do?".
/// Every tab reads from here to decide whether to run a session
/// or show the graceful fallback card.
enum DeviceCapability {

    /// TrueDepth face tracking (ARFaceTrackingConfiguration).
    /// True on iPhone X and newer front cameras, and on A12+ rear cameras.
    static var supportsFaceTracking: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    /// The physical TrueDepth module (IR projector + IR camera),
    /// addressable through AVFoundation for raw depth streams.
    static var hasTrueDepthCamera: Bool {
        AVCaptureDevice.default(.builtInTrueDepthCamera, for: .depthData, position: .front) != nil
    }

    /// Rear LiDAR scene depth (iPhone 12 Pro and newer Pro models).
    static var hasLiDAR: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    /// Person occlusion capability (A12+).
    static var supportsPersonOcclusion: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth)
    }

    static var systemVersion: String {
        UIDevice.current.systemVersion
    }

    /// Hardware model identifier, e.g. "iPhone14,5" (iPhone 13).
    static var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            let data = Data(buffer.prefix(while: { $0 != 0 }))
            return String(decoding: data, as: UTF8.self)
        }
    }

    /// Rows for the About tab capability report.
    static var capabilityReport: [(name: String, supported: Bool)] {
        [
            ("Face tracking (ARKit)", supportsFaceTracking),
            ("TrueDepth camera (AVFoundation)", hasTrueDepthCamera),
            ("Rear LiDAR scene depth", hasLiDAR),
            ("Person occlusion", supportsPersonOcclusion)
        ]
    }
}
