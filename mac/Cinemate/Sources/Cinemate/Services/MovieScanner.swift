import Foundation

struct ParsedMedia {
    let title: String
    let year: Int?
    let quality: String?
    let mediaType: MediaType
    let showName: String?
    let seasonNumber: Int?
    let episodeNumber: Int?
}

final class MovieScanner {
    static let videoExtensions: Set<String> = ["mp4", "mkv", "avi", "mov", "m4v", "wmv", "flv", "webm"]

    /// Regex matching S01E01, s02e03, S1E5, etc. (case-insensitive)
    private static let episodePattern = try! NSRegularExpression(
        pattern: "S(\\d{1,2})E(\\d{1,2})",
        options: .caseInsensitive
    )

    static func scan(directory: String, progress: @escaping (Int) -> Void) async -> Int {
        let fm = FileManager.default
        let db = Database.shared
        var count = 0

        guard let enumerator = fm.enumerator(atPath: directory) else { return 0 }

        while let relativePath = enumerator.nextObject() as? String {
            let fullPath = (directory as NSString).appendingPathComponent(relativePath)
            let filename = (fullPath as NSString).lastPathComponent

            // Skip macOS resource forks and sample files
            if filename.hasPrefix("._") || filename.lowercased() == "sample.avi" { continue }

            let ext = (filename as NSString).pathExtension.lowercased()
            guard videoExtensions.contains(ext) else { continue }

            // 50 MB minimum file size
            var fileSize: Int64 = 0
            if let attrs = try? fm.attributesOfItem(atPath: fullPath),
               let size = attrs[.size] as? Int64 {
                fileSize = size
            }
            if fileSize < 50_000_000 { continue }

            let parsed = parseMedia(from: fullPath, rootDir: directory)

            try? db.insertMedia(
                title: parsed.title,
                year: parsed.year,
                filePath: fullPath,
                fileSize: fileSize,
                format: ext.uppercased(),
                quality: parsed.quality,
                mediaType: parsed.mediaType,
                showName: parsed.showName,
                seasonNumber: parsed.seasonNumber,
                episodeNumber: parsed.episodeNumber
            )

            count += 1
            if count % 50 == 0 {
                await probeMissingDurations()
            }
            if count % 10 == 0 {
                progress(count)
            }
        }

        progress(count)
        await probeMissingDurations()
        return count
    }

    private static func probeMissingDurations() async {
        let ffprobePaths = ["/opt/homebrew/bin/ffprobe", "/usr/local/bin/ffprobe"]
        guard let ffprobe = ffprobePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }

        let items = Database.shared.itemsMissingDuration()
        for item in items {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffprobe)
            process.arguments = ["-v", "quiet", "-show_entries", "format=duration",
                                 "-of", "default=noprint_wrappers=1:nokey=1", item.filePath]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
            if let data = try? pipe.fileHandleForReading.availableData,
               let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let dur = Double(str), dur > 0 {
                Database.shared.updateDuration(movieId: item.id, duration: dur)
            }
        }
    }

    // MARK: - Parsing

    /// Determines whether a file is a movie or TV episode based on S##E## pattern,
    /// then extracts the relevant metadata.
    static func parseMedia(from path: String, rootDir: String) -> ParsedMedia {
        let relative = String(path.dropFirst(rootDir.count + 1))
        let components = relative.split(separator: "/").map(String.init)
        let filename = (path as NSString).lastPathComponent
        let filenameNoExt = (filename as NSString).deletingPathExtension

        // --- Detect TV episode via S##E## in the filename ---
        let fnRange = NSRange(filenameNoExt.startIndex..., in: filenameNoExt)
        if let match = episodePattern.firstMatch(in: filenameNoExt, range: fnRange) {
            let seasonNum = Int((filenameNoExt as NSString).substring(with: match.range(at: 1)))!
            let episodeNum = Int((filenameNoExt as NSString).substring(with: match.range(at: 2)))!

            // Everything before the S##E## token is the raw show name
            let sxxexxRange = match.range(at: 0)
            let beforePattern = String(filenameNoExt[filenameNoExt.startIndex..<filenameNoExt.index(filenameNoExt.startIndex, offsetBy: sxxexxRange.location)])
            let year = extractYear(from: beforePattern)
            let showNameRaw = cleanTitle(beforePattern, removingYear: year)

            let episodeTag = "S\(String(format: "%02d", seasonNum))E\(String(format: "%02d", episodeNum))"
            let displayTitle = showNameRaw.isEmpty ? episodeTag : "\(showNameRaw) \(episodeTag)"

            return ParsedMedia(
                title: displayTitle,
                year: year,
                quality: extractQuality(from: path),
                mediaType: .tvEpisode,
                showName: showNameRaw.isEmpty ? nil : showNameRaw,
                seasonNumber: seasonNum,
                episodeNumber: episodeNum
            )
        }

        let (movieTitle, movieYear) = parseMovieTitle(from: path, rootDir: rootDir, components: components)
        return ParsedMedia(
            title: movieTitle,
            year: movieYear,
            quality: extractQuality(from: path),
            mediaType: .movie,
            showName: nil,
            seasonNumber: nil,
            episodeNumber: nil
        )
    }

    // MARK: - Movie title parsing (preserved from original)

    private static func parseMovieTitle(from path: String, rootDir: String, components: [String]) -> (String, Int?) {
        var raw: String
        if components.count > 1 {
            raw = components[0]
        } else {
            raw = (path as NSString).lastPathComponent
            raw = (raw as NSString).deletingPathExtension
        }

        // Handle "001 New Movies" container folder
        if raw == "001 New Movies" && components.count > 2 {
            raw = components[1]
        } else if raw == "001 New Movies" && components.count == 2 {
            raw = (components[1] as NSString).deletingPathExtension
        }

        let year = extractYear(from: raw)
        let cleaned = cleanTitle(raw, removingYear: year)

        let title = cleaned.isEmpty
            ? ((path as NSString).lastPathComponent as NSString).deletingPathExtension
            : cleaned

        return (title, year)
    }

    // MARK: - Shared helpers

    /// Extract a four-digit year (1900-2029) from a string.
    /// Prefers the LAST match so titles like "1917" keep their name and "2019" is the release year.
    private static func extractYear(from text: String) -> Int? {
        let stripped = text
            .replacingOccurrences(of: "\\[.*?\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\{.*?\\}", with: "", options: .regularExpression)
        let pattern = try! NSRegularExpression(pattern: "\\b(19\\d{2}|20[0-2]\\d)\\b")
        let range = NSRange(stripped.startIndex..., in: stripped)
        let matches = pattern.matches(in: stripped, range: range)
        guard let last = matches.last else { return nil }
        let matchRange = Range(last.range, in: stripped)!
        return Int(stripped[matchRange])
    }

    static func extractQuality(from path: String) -> String? {
        let text = path.uppercased()
        var parts: [String] = []

        if text.contains("2160P") || text.contains("4K") { parts.append("4K") }
        else if text.contains("1080P") { parts.append("1080p") }
        else if text.contains("720P") { parts.append("720p") }
        else if text.contains("480P") { parts.append("480p") }

        if text.contains("BLURAY") || text.contains("BRRIP") || text.contains("BDRIP") { parts.append("BluRay") }
        else if text.contains("WEBRIP") || text.contains("WEB-DL") || text.contains("WEBDL") { parts.append("WEB") }
        else if text.contains("HDTV") { parts.append("HDTV") }
        else if text.contains("DVDRIP") || text.contains("DVDSCR") { parts.append("DVD") }
        else if text.contains("HDRIP") { parts.append("HDRip") }

        if text.contains("HDR") && !text.contains("HDRIP") { parts.append("HDR") }
        if text.contains("X265") || text.contains("HEVC") { parts.append("HEVC") }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// Clean a raw title string: strip brackets, noise words, dots, dashes, collapse whitespace.
    /// Optionally also removes a specific year value.
    private static func cleanTitle(_ raw: String, removingYear year: Int? = nil) -> String {
        var cleaned = raw
            .replacingOccurrences(of: "\\[.*?\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\{.*?\\}", with: "", options: .regularExpression)

        let noise = [
            "1080p", "720p", "480p", "2160p", "4K",
            "BluRay", "BrRip", "BRRip", "WEBRip", "WEB-DL", "WEBDL", "HDRip", "DVDRip", "DvDrip", "DVDSCR",
            "WEB",
            "x264", "x265", "H264", "H.264", "XviD", "HEVC",
            "AAC", "AAC5.1", "AC3", "DTS", "5.1",
            "YIFY", "YTS.MX", "YTS.AM", "YTS.AG", "RARBG", "EVO", "aXXo", "HANDJOB", "RBG",
            "GalaxyTV", "PHOENiX", "TORRENTGALAXY", "TGx",
            "HMAX",
            "Eng", "Hard", "Sub", "VoStFr",
            "anoXmous", "Blackjesus", "JYK", "Pimp4003", "BOKUTOX",
            "DC", "EXTENDED", "UNRATED", "REMASTERED", "DIRECTORS.CUT",
            "COMPLETE",
            "Season",
        ]

        for word in noise {
            cleaned = cleaned.replacingOccurrences(
                of: "\\b\(NSRegularExpression.escapedPattern(for: word))\\b",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        if let yearVal = year {
            cleaned = cleaned.replacingOccurrences(of: String(yearVal), with: "")
        }

        // Strip any leftover S## season-only tags (e.g., from COMPLETE packs folder names)
        cleaned = cleaned.replacingOccurrences(
            of: "\\bS\\d{1,2}\\b",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        cleaned = cleaned
            .replacingOccurrences(of: "\\.", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "-+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "\\(\\s*\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "- .()"))

        return cleaned
    }
}
