import Foundation
import SwiftUI

// MARK: - Book

struct Book: Identifiable, Hashable {
    let id: Int64
    var title: String
    var author: String?
    var genre: String?
    var publisher: String?
    var language: String?
    var description_: String?
    var pageCount: Int
    var format: String
    var filePath: String
    var fileSize: Int64
    var coverPath: String?
    var year: Int?
    var dateAdded: Date

    // Per-account reading state
    var readingProgress: Double // 0.0 - 1.0
    var currentPage: Int
    var favorite: Bool
    var finished: Bool
    var startedAt: Date?
    var finishedAt: Date?
    var totalReadingTime: Double // seconds

    var progressPercent: Int {
        min(Int(readingProgress * 100), 100)
    }

    var fileSizeFormatted: String {
        let gb = Double(fileSize) / 1_073_741_824
        if gb >= 1.0 { return String(format: "%.1f GB", gb) }
        let mb = Double(fileSize) / 1_048_576
        if mb >= 1.0 { return String(format: "%.0f MB", mb) }
        let kb = Double(fileSize) / 1024
        return String(format: "%.0f KB", kb)
    }

    var fileExtension: String {
        (filePath as NSString).pathExtension.uppercased()
    }

    var formatBadgeColor: Color {
        switch format.uppercased() {
        case "EPUB": return .blue
        case "PDF": return .red
        case "MOBI", "AZW3": return .orange
        case "CBZ", "CBR": return .purple
        case "FB2": return .green
        case "DJVU": return .teal
        default: return .gray
        }
    }

    var readingTimeFormatted: String {
        guard totalReadingTime > 0 else { return "" }
        let hours = Int(totalReadingTime) / 3600
        let minutes = (Int(totalReadingTime) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var pagesReadEstimate: Int {
        guard pageCount > 0 else { return 0 }
        return Int(Double(pageCount) * readingProgress)
    }

    var authorDisplay: String {
        author ?? "Unknown Author"
    }
}

// MARK: - Book Bookmark

struct BookBookmark: Identifiable, Hashable {
    let id: Int64
    var bookId: Int64
    var page: Int
    var note: String?
    var createdAt: Date
}

// MARK: - Book Author

struct BookAuthor: Identifiable, Hashable {
    var name: String
    var bookCount: Int

    var id: String { name }
}

// MARK: - Audiobook Metadata

struct AudiobookMeta: Codable {
    let title: String
    let generatedAt: String
    let ttsEngine: String
    let voice: String
    let speed: Double
    let totalChapters: Int
    let totalDurationSeconds: Double
    let totalDurationDisplay: String
    let chapters: [AudiobookChapter]

    enum CodingKeys: String, CodingKey {
        case title
        case generatedAt = "generated_at"
        case ttsEngine = "tts_engine"
        case voice, speed
        case totalChapters = "total_chapters"
        case totalDurationSeconds = "total_duration_seconds"
        case totalDurationDisplay = "total_duration_display"
        case chapters
    }
}

struct AudiobookChapter: Codable, Identifiable {
    let index: Int
    let title: String
    let filename: String
    let durationSeconds: Double
    let durationDisplay: String
    let fileSize: Int
    let charCount: Int

    var id: Int { index }

    enum CodingKeys: String, CodingKey {
        case index, title, filename
        case durationSeconds = "duration_seconds"
        case durationDisplay = "duration_display"
        case fileSize = "file_size"
        case charCount = "char_count"
    }
}

// MARK: - TTS Voice

struct TTSVoice: Identifiable {
    let id: String
    let name: String
    let accent: String

    static let allVoices: [TTSVoice] = [
        TTSVoice(id: "af_bella", name: "Bella", accent: "American"),
        TTSVoice(id: "af_nicole", name: "Nicole", accent: "American"),
        TTSVoice(id: "af_sarah", name: "Sarah", accent: "American"),
        TTSVoice(id: "af_sky", name: "Sky", accent: "American"),
        TTSVoice(id: "am_adam", name: "Adam", accent: "American"),
        TTSVoice(id: "am_michael", name: "Michael", accent: "American"),
        TTSVoice(id: "bf_emma", name: "Emma", accent: "British"),
        TTSVoice(id: "bf_isabella", name: "Isabella", accent: "British"),
        TTSVoice(id: "bm_george", name: "George", accent: "British"),
        TTSVoice(id: "bm_lewis", name: "Lewis", accent: "British"),
    ]
}

// MARK: - Book Sort Option

enum BookSortOption: String, CaseIterable {
    case title = "Title"
    case author = "Author"
    case dateAdded = "Recently Added"
    case year = "Year"
}

// MARK: - Book Sub-navigation

enum BookSubView: String, CaseIterable {
    case all = "All Books"
    case currentlyReading = "Currently Reading"
    case finished = "Finished"
    case authors = "Authors"
}
