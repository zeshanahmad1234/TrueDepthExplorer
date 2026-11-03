# TrueDepth Explorer

**A complete, compile-ready iOS app that puts the iPhone TrueDepth camera (the Face ID hardware) in your hands.**

Live 3D face mesh · all 52 expression coefficients · challenge/response liveness · raw infrared depth stream.

Developed by **Zeshan Ahmad**

---

## What it does

| Tab | What you see | TrueDepth hardware used |
|---|---|---|
| **Face Mesh** | Live wireframe of your face (1,200+ vertices, real measured 3D — not an AI guess), plus FPS / vertex / triangle / distance stats | `ARFaceTrackingConfiguration` → IR projector + IR camera, mesh via `ARSCNFaceGeometry` |
| **Expressions** | All 52 ARKit blend shapes as live bars, grouped (brows, eyes, jaw, mouth, nose & cheeks, tongue) — the same vector that powers Memoji | Blend shape coefficients from the IR face tracker |
| **Liveness** | Random challenge sequence (blink, smile, open mouth, raise brows, turn left/right) with progress ring and a verification summary | Depth-verified anti-spoofing: a photo or screen replay cannot pass |
| **IR Depth** | The raw per-pixel depth stream color-mapped over your selfie preview, with center distance in cm and min/max | `.builtInTrueDepthCamera` + `AVCaptureDepthDataOutput` (`AVDepthData`, metric meters) |
| **About** | Device capability report (face tracking, TrueDepth, LiDAR, occlusion) and app info | — |

The app degrades gracefully: on a device without TrueDepth (e.g. iPhone SE, Simulator) each tab shows an explanation instead of crashing.

## Repository layout

```
TrueDepthExplorer/
├── .github/workflows/build-ipa.yml      ← CI: builds an unsigned IPA on every push
├── TrueDepthExplorer.xcodeproj/         ← generated project (opens directly in Xcode)
│   └── xcshareddata/xcschemes/…         ← shared scheme used by CI
└── TrueDepthExplorer/
    ├── App/          App entry, tab root, theme & credit views
    ├── Core/         DeviceCapability (what can this phone do?)
    ├── Face/         Mesh scanner, blend-shape catalog & bars, liveness engine
    ├── Depth/        AVFoundation depth engine + colormap
    ├── About/        Capability report & credits
    ├── Assets.xcassets/  App icon + accent color
    └── Info.plist    Camera usage description etc.
```

## Requirements

- **Xcode 15 or 16** (project format objectVersion 56 / Xcode 14+)
- **iPhone X or newer** to see real TrueDepth data (the Simulator has no camera)
- An Apple ID for free on-device signing (7-day provisioning) or a paid developer account

## Build & run from a Mac

1. Unzip/extract, then open `TrueDepthExplorer.xcodeproj` in Xcode.
2. Select the **TrueDepthExplorer** target → **Signing & Capabilities** → tick *Automatically manage signing* and choose your **Team**.
3. Plug in your iPhone, select it as the run destination, press **Run**.
4. First launch: allow camera access when prompted (the usage string is already in `Info.plist`).
   On-device: Settings → General → VPN & Device Management → trust your developer profile if prompted.

### Command line

```bash
xcodebuild -project TrueDepthExplorer.xcodeproj -scheme TrueDepthExplorer \
  -destination 'platform=iOS,name=YOUR_IPHONE' build
```

## Build an IPA without a Mac (GitHub Actions)

This repo ships with a workflow that archives the app and packages an **unsigned IPA** on a macOS runner:

1. Push this folder to GitHub (keep the `.github/workflows` folder).
2. Open the **Actions** tab → **Build Unsigned IPA** → run it (it also runs on every push).
3. Download the artifact **TrueDepthExplorer-unsigned-ipa**.
4. Sign and install it on your phone with [Sideloadly](https://sideloadly.io), [AltStore](https://altstore.io) or Apple Configurator — they inject your Apple ID signature into the unsigned IPA.

> The unsigned IPA contains the compiled app binary; sideload tools re-sign it with your identity. This is the standard route when you don't have certificates in CI.

## Devices & sensors

- **iPhone X – 13 / 14 / 15 / 16 (non-Pro)**: front **TrueDepth** — all four tabs fully functional.
- **Pro models (12 Pro and later)**: front TrueDepth **and** rear LiDAR — the About tab reports both.
- **A12+ iPhones with broken TrueDepth**: ARKit face tracking can also run on the *rear* camera.
- **Android / Simulator**: not supported — there is no public equivalent of ARKit's face mesh + blend shapes.

## Tuning

- Liveness thresholds, hold duration and timeout are constants at the top of
  `Face/LivenessCheckerView.swift` (`turnThreshold`, `holdDuration`, `stepTimeout`).
- Depth color range is `minMeters/maxMeters` in `Depth/DepthCameraView.swift` (`0.15–1.5 m`).
- Head-turn direction sign is derived from the face-anchor quaternion; a live yaw
  readout is shown during turn challenges so you can verify direction on your device.

## Privacy

Everything runs **on-device**. No recording, no network, no analytics. The camera usage
string in `Info.plist` states this.

## License

MIT — see [LICENSE](LICENSE). © 2026 Zeshan Ahmad.
