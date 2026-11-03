//
//  BlendShapeCatalog.swift
//  TrueDepthExplorer
//
//  Created by Zeshan Ahmad on 03.11.2026.
//  Copyright © 2026 Zeshan Ahmad. All rights reserved.
//

import SwiftUI
import ARKit

/// The 52 ARKit blend shapes in display order, grouped for the
/// Expressions tab. Keys use the exact ARKit case names.
enum BlendShapeGroup: String, CaseIterable {
    case brows = "Brows"
    case eyes = "Eyes"
    case jaw = "Jaw"
    case mouth = "Mouth"
    case noseCheeks = "Nose & Cheeks"
    case tongue = "Tongue"

    var color: Color {
        switch self {
        case .brows: return Color(red: 0.35, green: 0.80, blue: 1.00)
        case .eyes: return Color(red: 0.55, green: 0.35, blue: 1.00)
        case .jaw: return Color(red: 1.00, green: 0.58, blue: 0.25)
        case .mouth: return Color(red: 1.00, green: 0.35, blue: 0.55)
        case .noseCheeks: return Color(red: 0.30, green: 0.90, blue: 0.60)
        case .tongue: return Color(red: 0.95, green: 0.45, blue: 0.45)
        }
    }
}

struct BlendShapeDefinition: Identifiable {
    /// ARKit name, e.g. "eyeBlinkLeft".
    let id: String
    /// Human-friendly label shown in the UI.
    let label: String
    let group: BlendShapeGroup
    let location: ARFaceAnchor.BlendShapeLocation

    var isLeft: Bool { id.hasSuffix("Left") }
    var isRight: Bool { id.hasSuffix("Right") }
}

enum BlendShapeCatalog {

    /// All 52 blend shapes. The order here is the order shown in the UI.
    static let all: [BlendShapeDefinition] = [
        // MARK: Brows
        BlendShapeDefinition(id: "browDownLeft", label: "Brow Down L", group: .brows, location: .browDownLeft),
        BlendShapeDefinition(id: "browDownRight", label: "Brow Down R", group: .brows, location: .browDownRight),
        BlendShapeDefinition(id: "browInnerUp", label: "Brow Inner Up", group: .brows, location: .browInnerUp),
        BlendShapeDefinition(id: "browOuterUpLeft", label: "Brow Outer Up L", group: .brows, location: .browOuterUpLeft),
        BlendShapeDefinition(id: "browOuterUpRight", label: "Brow Outer Up R", group: .brows, location: .browOuterUpRight),

        // MARK: Cheeks & Nose
        BlendShapeDefinition(id: "cheekPuff", label: "Cheek Puff", group: .noseCheeks, location: .cheekPuff),
        BlendShapeDefinition(id: "cheekSquintLeft", label: "Cheek Squint L", group: .noseCheeks, location: .cheekSquintLeft),
        BlendShapeDefinition(id: "cheekSquintRight", label: "Cheek Squint R", group: .noseCheeks, location: .cheekSquintRight),
        BlendShapeDefinition(id: "noseSneerLeft", label: "Nose Sneer L", group: .noseCheeks, location: .noseSneerLeft),
        BlendShapeDefinition(id: "noseSneerRight", label: "Nose Sneer R", group: .noseCheeks, location: .noseSneerRight),

        // MARK: Eyes
        BlendShapeDefinition(id: "eyeBlinkLeft", label: "Eye Blink L", group: .eyes, location: .eyeBlinkLeft),
        BlendShapeDefinition(id: "eyeBlinkRight", label: "Eye Blink R", group: .eyes, location: .eyeBlinkRight),
        BlendShapeDefinition(id: "eyeLookDownLeft", label: "Eye Look Down L", group: .eyes, location: .eyeLookDownLeft),
        BlendShapeDefinition(id: "eyeLookDownRight", label: "Eye Look Down R", group: .eyes, location: .eyeLookDownRight),
        BlendShapeDefinition(id: "eyeLookInLeft", label: "Eye Look In L", group: .eyes, location: .eyeLookInLeft),
        BlendShapeDefinition(id: "eyeLookInRight", label: "Eye Look In R", group: .eyes, location: .eyeLookInRight),
        BlendShapeDefinition(id: "eyeLookOutLeft", label: "Eye Look Out L", group: .eyes, location: .eyeLookOutLeft),
        BlendShapeDefinition(id: "eyeLookOutRight", label: "Eye Look Out R", group: .eyes, location: .eyeLookOutRight),
        BlendShapeDefinition(id: "eyeLookUpLeft", label: "Eye Look Up L", group: .eyes, location: .eyeLookUpLeft),
        BlendShapeDefinition(id: "eyeLookUpRight", label: "Eye Look Up R", group: .eyes, location: .eyeLookUpRight),
        BlendShapeDefinition(id: "eyeSquintLeft", label: "Eye Squint L", group: .eyes, location: .eyeSquintLeft),
        BlendShapeDefinition(id: "eyeSquintRight", label: "Eye Squint R", group: .eyes, location: .eyeSquintRight),
        BlendShapeDefinition(id: "eyeWideLeft", label: "Eye Wide L", group: .eyes, location: .eyeWideLeft),
        BlendShapeDefinition(id: "eyeWideRight", label: "Eye Wide R", group: .eyes, location: .eyeWideRight),

        // MARK: Jaw
        BlendShapeDefinition(id: "jawForward", label: "Jaw Forward", group: .jaw, location: .jawForward),
        BlendShapeDefinition(id: "jawLeft", label: "Jaw Left", group: .jaw, location: .jawLeft),
        BlendShapeDefinition(id: "jawOpen", label: "Jaw Open", group: .jaw, location: .jawOpen),
        BlendShapeDefinition(id: "jawRight", label: "Jaw Right", group: .jaw, location: .jawRight),

        // MARK: Mouth
        BlendShapeDefinition(id: "mouthClose", label: "Mouth Close", group: .mouth, location: .mouthClose),
        BlendShapeDefinition(id: "mouthDimpleLeft", label: "Mouth Dimple L", group: .mouth, location: .mouthDimpleLeft),
        BlendShapeDefinition(id: "mouthDimpleRight", label: "Mouth Dimple R", group: .mouth, location: .mouthDimpleRight),
        BlendShapeDefinition(id: "mouthFrownLeft", label: "Mouth Frown L", group: .mouth, location: .mouthFrownLeft),
        BlendShapeDefinition(id: "mouthFrownRight", label: "Mouth Frown R", group: .mouth, location: .mouthFrownRight),
        BlendShapeDefinition(id: "mouthFunnel", label: "Mouth Funnel", group: .mouth, location: .mouthFunnel),
        BlendShapeDefinition(id: "mouthLeft", label: "Mouth Left", group: .mouth, location: .mouthLeft),
        BlendShapeDefinition(id: "mouthLowerDownLeft", label: "Lip Lower Down L", group: .mouth, location: .mouthLowerDownLeft),
        BlendShapeDefinition(id: "mouthLowerDownRight", label: "Lip Lower Down R", group: .mouth, location: .mouthLowerDownRight),
        BlendShapeDefinition(id: "mouthPressLeft", label: "Lip Press L", group: .mouth, location: .mouthPressLeft),
        BlendShapeDefinition(id: "mouthPressRight", label: "Lip Press R", group: .mouth, location: .mouthPressRight),
        BlendShapeDefinition(id: "mouthPucker", label: "Mouth Pucker", group: .mouth, location: .mouthPucker),
        BlendShapeDefinition(id: "mouthRight", label: "Mouth Right", group: .mouth, location: .mouthRight),
        BlendShapeDefinition(id: "mouthRollLower", label: "Lip Roll Lower", group: .mouth, location: .mouthRollLower),
        BlendShapeDefinition(id: "mouthRollUpper", label: "Lip Roll Upper", group: .mouth, location: .mouthRollUpper),
        BlendShapeDefinition(id: "mouthShrugLower", label: "Lip Shrug Lower", group: .mouth, location: .mouthShrugLower),
        BlendShapeDefinition(id: "mouthShrugUpper", label: "Lip Shrug Upper", group: .mouth, location: .mouthShrugUpper),
        BlendShapeDefinition(id: "mouthSmileLeft", label: "Mouth Smile L", group: .mouth, location: .mouthSmileLeft),
        BlendShapeDefinition(id: "mouthSmileRight", label: "Mouth Smile R", group: .mouth, location: .mouthSmileRight),
        BlendShapeDefinition(id: "mouthStretchLeft", label: "Mouth Stretch L", group: .mouth, location: .mouthStretchLeft),
        BlendShapeDefinition(id: "mouthStretchRight", label: "Mouth Stretch R", group: .mouth, location: .mouthStretchRight),
        BlendShapeDefinition(id: "mouthUpperUpLeft", label: "Lip Upper Up L", group: .mouth, location: .mouthUpperUpLeft),
        BlendShapeDefinition(id: "mouthUpperUpRight", label: "Lip Upper Up R", group: .mouth, location: .mouthUpperUpRight),

        // MARK: Tongue
        BlendShapeDefinition(id: "tongueOut", label: "Tongue Out", group: .tongue, location: .tongueOut)
    ]

    static func definition(for location: ARFaceAnchor.BlendShapeLocation) -> BlendShapeDefinition? {
        all.first { $0.location == location }
    }
}
