// Saves a frame every quarter second from a video: video_frames.swift video.mp4 out-folder
import AVFoundation
import AppKit

let asset = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
let folder = CommandLine.arguments[2]
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero

let duration = CMTimeGetSeconds(asset.duration)
var time = 0.0
var index = 0
while time < duration {
    if let image = try? generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil),
       let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
        try png.write(to: URL(fileURLWithPath: "\(folder)/frame-\(String(format: "%03d", index)).png"))
        index += 1
    }
    time += 0.25
}
print("Saved \(index) frames")
