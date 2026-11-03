//
//  ContentView.swift
//  TrueDepthExplorer
//
//  Created by Zeshan Ahmad on 03.11.2026.
//  Copyright © 2026 Zeshan Ahmad. All rights reserved.
//

import SwiftUI

/// Root of the app: one tab per TrueDepth capability.
/// Only one tab is active at a time; every tab starts its session in
/// `onAppear` and pauses it in `onDisappear` so the front camera is
/// never claimed by two sessions at once.
struct ContentView: View {
    var body: some View {
        TabView {
            FaceMeshView()
                .tabItem { Label("Face Mesh", systemImage: "faceid") }

            BlendShapesView()
                .tabItem { Label("Expressions", systemImage: "face.dashed") }

            LivenessCheckerView()
                .tabItem { Label("Liveness", systemImage: "checkmark.shield") }

            DepthCameraView()
                .tabItem { Label("IR Depth", systemImage: "ruler") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .tint(Theme.accent)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
