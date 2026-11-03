//
//  DepthColormap.swift
//  TrueDepthExplorer
//
//  Created by Zeshan Ahmad on 03.11.2026.
//  Copyright © 2026 Zeshan Ahmad. All rights reserved.
//

import CoreVideo
import UIKit

/// Conversions from a raw `AVDepthData` pixel buffer (Float32 meters) to
/// displayable output: a color-mapped UIImage and simple region statistics.
///
/// The TrueDepth sensor delivers the depth map in landscape sensor
/// orientation, so quarter-turn rotation and optional mirroring are applied
/// here (front camera feels natural mirrored).
enum DepthColormap {

    /// Median depth (meters) of a small centered region — a stable
    /// "distance to face" readout that single outliers cannot skew.
    static func medianDepth(in depthMap: CVPixelBuffer, regionSize: Int = 25) -> Float? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let stride = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float>.stride
        let pointer = base.assumingMemoryBound(to: Float.self)

        let half = regionSize / 2
        let centerX = width / 2
        let centerY = height / 2
        var samples: [Float] = []
        samples.reserveCapacity(regionSize * regionSize)

        var y = max(0, centerY - half)
        while y < min(height, centerY + half + 1) {
            var x = max(0, centerX - half)
            while x < min(width, centerX + half + 1) {
                let value = pointer[y * stride + x]
                if value.isFinite, value > 0.05, value < 8 {
                    samples.append(value)
                }
                x += 1
            }
            y += 1
        }

        guard !samples.isEmpty else { return nil }
        samples.sort()
        return samples[samples.count / 2]
    }

    /// Min/max of valid samples in the whole buffer (meters).
    static func bufferStats(_ depthMap: CVPixelBuffer) -> (min: Float, max: Float)? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let stride = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float>.stride
        let pointer = base.assumingMemoryBound(to: Float.self)

        var lowest = Float.greatestFiniteMagnitude
        var highest = -Float.greatestFiniteMagnitude
        for y in 0..<height {
            let row = pointer + y * stride
            for x in 0..<width {
                let value = row[x]
                guard value.isFinite, value > 0.05, value < 8 else { continue }
                if value < lowest { lowest = value }
                if value > highest { highest = value }
            }
        }
        guard lowest <= highest else { return nil }
        return (lowest, highest)
    }

    /// Color-maps the depth buffer into an RGBA UIImage.
    /// Near objects render warm (red), far objects cool (blue).
    static func rgbaImage(
        from depthMap: CVPixelBuffer,
        minMeters: Float,
        maxMeters: Float,
        quarterTurns: Int,
        mirrored: Bool
    ) -> UIImage? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let stride = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float>.stride
        let pointer = base.assumingMemoryBound(to: Float.self)

        let turns = ((quarterTurns % 4) + 4) % 4
        let swapped = turns == 1 || turns == 3
        let outWidth = swapped ? height : width
        let outHeight = swapped ? width : height

        var rgba = [UInt8](repeating: 0, count: outWidth * outHeight * 4)
        let range = max(0.001, maxMeters - minMeters)

        for y in 0..<height {
            let row = pointer + y * stride
            for x in 0..<width {
                let value = row[x]
                var red: UInt8 = 0
                var green: UInt8 = 0
                var blue: UInt8 = 0
                var alpha: UInt8 = 0
                if value.isFinite, value >= minMeters, value <= maxMeters {
                    // Invert so close = hot end of the ramp.
                    let t = 1 - min(1, max(0, (value - minMeters) / range))
                    (red, green, blue) = colorRamp(t)
                    alpha = 255
                }

                var dx = x
                var dy = y
                switch turns {
                case 1: dx = height - 1 - y; dy = x
                case 2: dx = width - 1 - x; dy = height - 1 - y
                case 3: dx = y; dy = width - 1 - x
                default: break
                }
                if mirrored {
                    dx = outWidth - 1 - dx
                }

                let index = (dy * outWidth + dx) * 4
                rgba[index] = red
                rgba[index + 1] = green
                rgba[index + 2] = blue
                rgba[index + 3] = alpha
            }
        }

        guard let context = CGContext(
            data: &rgba,
            width: outWidth,
            height: outHeight,
            bitsPerComponent: 8,
            bytesPerRow: outWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else { return nil }

        return UIImage(cgImage: image)
    }

    /// Five-stop blue→cyan→green→yellow→red ramp.
    static func colorRamp(_ t: Float) -> (UInt8, UInt8, UInt8) {
        let stops: [(Float, Float, Float)] = [
            (0.00, 0.00, 1.00),   // blue
            (0.00, 1.00, 1.00),   // cyan
            (0.00, 1.00, 0.00),   // green
            (1.00, 1.00, 0.00),   // yellow
            (1.00, 0.00, 0.00)    // red
        ]
        let scaled = min(0.9999, max(0, t)) * 4
        let index = Int(scaled)
        let fraction = scaled - Float(index)
        let from = stops[index]
        let to = stops[index + 1]
        return (
            UInt8(255 * (from.0 + (to.0 - from.0) * fraction)),
            UInt8(255 * (from.1 + (to.1 - from.1) * fraction)),
            UInt8(255 * (from.2 + (to.2 - from.2) * fraction))
        )
    }
}
