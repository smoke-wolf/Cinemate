import AVFoundation
import AppKit
import Foundation

final class ThumbnailGenerator {
    static let thumbnailDir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cinemate/thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let brightnessThreshold: CGFloat = 0.08
    private static let maxRetries = 5

    static func generate(for movie: Movie) async -> String? {
        if let existing = movie.thumbnailPath, FileManager.default.fileExists(atPath: existing) {
            return existing
        }

        let outputPath = thumbnailDir.appendingPathComponent("\(movie.id).jpg").path
        if FileManager.default.fileExists(atPath: outputPath) {
            if !isTooDark(at: outputPath) {
                Database.shared.updateThumbnail(movieId: movie.id, path: outputPath)
                return outputPath
            }
            try? FileManager.default.removeItem(atPath: outputPath)
        }

        if let path = await generateWithAVFoundation(movie: movie, outputPath: outputPath) {
            return path
        }

        if let path = await generateWithFFmpeg(movie: movie, outputPath: outputPath) {
            return path
        }

        return nil
    }

    private static func generateWithAVFoundation(movie: Movie, outputPath: String) async -> String? {
        let url = URL(fileURLWithPath: movie.filePath)
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 600)

        let duration = try? await asset.load(.duration)
        let totalSeconds = duration.map { CMTimeGetSeconds($0) } ?? 60

        if totalSeconds > 0 {
            Database.shared.updateDuration(movieId: movie.id, duration: totalSeconds)
        }

        var startOffset = min(totalSeconds * 0.15, 120)

        for attempt in 0..<maxRetries {
            let sampleTime = CMTime(seconds: startOffset, preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: sampleTime)
                if !isCGImageTooDark(cgImage) || attempt == maxRetries - 1 {
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    if let tiffData = nsImage.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let jpgData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
                        try jpgData.write(to: URL(fileURLWithPath: outputPath))
                        Database.shared.updateThumbnail(movieId: movie.id, path: outputPath)
                        return outputPath
                    }
                }
            } catch {}
            startOffset += 5
            if startOffset > totalSeconds * 0.8 { break }
        }
        return nil
    }

    private static func generateWithFFmpeg(movie: Movie, outputPath: String) async -> String? {
        let ffmpegPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
        guard let ffmpeg = ffmpegPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var seekTime = 30
                var finalPath: String?

                for attempt in 0..<maxRetries {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: ffmpeg)
                    process.arguments = [
                        "-ss", "\(seekTime)",
                        "-i", movie.filePath,
                        "-vframes", "1",
                        "-vf", "scale=400:-1",
                        "-q:v", "3",
                        "-y",
                        outputPath
                    ]
                    process.standardOutput = FileHandle.nullDevice
                    process.standardError = FileHandle.nullDevice

                    do {
                        try process.run()
                        process.waitUntilExit()
                        if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: outputPath) {
                            if !isTooDark(at: outputPath) || attempt == maxRetries - 1 {
                                Database.shared.updateThumbnail(movieId: movie.id, path: outputPath)
                                finalPath = outputPath
                                break
                            }
                            try? FileManager.default.removeItem(atPath: outputPath)
                        }
                    } catch {}
                    seekTime += 5
                }

                // Probe duration
                let durationProcess = Process()
                durationProcess.executableURL = URL(fileURLWithPath: ffmpeg.replacingOccurrences(of: "ffmpeg", with: "ffprobe"))
                durationProcess.arguments = [
                    "-v", "quiet", "-show_entries", "format=duration",
                    "-of", "default=noprint_wrappers=1:nokey=1",
                    movie.filePath
                ]
                let pipe = Pipe()
                durationProcess.standardOutput = pipe
                durationProcess.standardError = FileHandle.nullDevice
                try? durationProcess.run()
                durationProcess.waitUntilExit()
                if let data = try? pipe.fileHandleForReading.availableData,
                   let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   let dur = Double(str), dur > 0 {
                    Database.shared.updateDuration(movieId: movie.id, duration: dur)
                }

                continuation.resume(returning: finalPath)
            }
        }
    }

    // MARK: - Brightness detection

    private static func isCGImageTooDark(_ image: CGImage) -> Bool {
        let width = min(image.width, 100)
        let height = min(image.height, 100)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixelData, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalBrightness: Double = 0
        let pixelCount = width * height
        for i in 0..<pixelCount {
            let offset = i * bytesPerPixel
            let r = Double(pixelData[offset]) / 255.0
            let g = Double(pixelData[offset + 1]) / 255.0
            let b = Double(pixelData[offset + 2]) / 255.0
            totalBrightness += (0.299 * r + 0.587 * g + 0.114 * b)
        }

        let avgBrightness = totalBrightness / Double(pixelCount)
        return avgBrightness < Double(brightnessThreshold)
    }

    private static func isTooDark(at path: String) -> Bool {
        guard let nsImage = NSImage(contentsOfFile: path),
              let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else { return false }
        return isCGImageTooDark(cgImage)
    }
}
