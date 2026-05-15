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
