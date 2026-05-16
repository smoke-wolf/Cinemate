import Foundation

struct LyricLine: Identifiable {
    let id: Int
    let time: TimeInterval
    let text: String
}

@MainActor
final class LyricManager: ObservableObject {
    @Published var lines: [LyricLine] = []
    @Published var currentLineIndex: Int = -1
    @Published var hasLyrics: Bool = false

    private static let lrcDirectory = NSHomeDirectory() + "/lyric-matcher/output"

    func loadLyrics(artist: String, title: String) {
        lines = []
        currentLineIndex = -1
        hasLyrics = false

        let safeName = "\(artist) - \(title)".replacingOccurrences(of: "/", with: "-")
        let path = "\(Self.lrcDirectory)/\(safeName).lrc"

        guard FileManager.default.fileExists(atPath: path),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return
        }

        var parsed: [LyricLine] = []
        guard let regex = try? NSRegularExpression(pattern: #"\[(\d{2}):(\d{2})\.(\d{2})\](.*)"#) else { return }

        for line in content.components(separatedBy: .newlines) {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range) else { continue }

            func group(_ i: Int) -> String {
                guard let r = Range(match.range(at: i), in: line) else { return "" }
                return String(line[r])
            }

            let minutes = Double(group(1)) ?? 0
            let seconds = Double(group(2)) ?? 0
            let centiseconds = Double(group(3)) ?? 0
            let text = group(4).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }

            let time = minutes * 60.0 + seconds + centiseconds / 100.0
            parsed.append(LyricLine(id: parsed.count, time: time, text: text))
        }

        lines = parsed.sorted { $0.time < $1.time }
        hasLyrics = !lines.isEmpty
    }

    // Offset to compensate for audio pipeline latency (lyrics show this many seconds later)
    var lyricOffset: TimeInterval = 1.5

    func update(currentTime: TimeInterval) {
        guard !lines.isEmpty else { return }

        let adjusted = currentTime - lyricOffset
        var newIndex = -1
        for i in lines.indices {
            if lines[i].time <= adjusted {
                newIndex = i
            } else {
                break
            }
        }

        if newIndex != currentLineIndex {
            currentLineIndex = newIndex
        }
    }

    func clear() {
        lines = []
        currentLineIndex = -1
        hasLyrics = false
    }
}
