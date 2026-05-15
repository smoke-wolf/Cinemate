import Foundation

enum MediaType: String, Codable, CaseIterable {
    case movie
    case tvEpisode
}

struct MediaItem: Identifiable, Hashable {
    let id: Int64
    var title: String
    var year: Int?
    var filePath: String
    var fileSize: Int64
    var format: String
    var genre: String?
    var rating: Int?
    var quality: String?
    var description_: String?
    var thumbnailPath: String?
    var lastPlayed: Date?
    var playCount: Int
    var favorite: Bool
    var watched: Bool
    var watchProgress: Double
    var duration: Double
    var dateAdded: Date

    var mediaType: MediaType
    var showName: String?
    var seasonNumber: Int?
    var episodeNumber: Int?
    var totalWatchTime: Double

    var displayTitle: String {
        switch mediaType {
        case .tvEpisode:
            let label = episodeLabel
            return label.isEmpty ? title : label
        case .movie:
            return title
        }
    }

    var episodeLabel: String {
        guard let s = seasonNumber, let e = episodeNumber else { return "" }
        return String(format: "S%02dE%02d", s, e)
    }

    var fileSizeFormatted: String {
        let gb = Double(fileSize) / 1_073_741_824
        if gb >= 1.0 { return String(format: "%.1f GB", gb) }
        let mb = Double(fileSize) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    var fileExtension: String {
        (filePath as NSString).pathExtension.uppercased()
    }

    var durationFormatted: String {
        guard duration > 0 else { return "" }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var totalWatchTimeFormatted: String {
        guard totalWatchTime > 0 else { return "" }
        let hours = Int(totalWatchTime) / 3600
        let minutes = (Int(totalWatchTime) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var progressPercent: Int {
        guard duration > 0 else { return 0 }
        return min(Int(watchProgress / duration * 100), 100)
    }
}

typealias Movie = MediaItem

struct GenreRow: Identifiable {
    let genre: String
    let movies: [MediaItem]
    var id: String { genre }
}

struct TVShow: Identifiable {
    let name: String
    var year: Int?
    var seasons: [Int: [MediaItem]]
    var thumbnailPath: String?
    var description_: String?

    var id: String { name }

    var allEpisodes: [MediaItem] {
        seasons.keys.sorted().flatMap { seasonNum in
            (seasons[seasonNum] ?? []).sorted {
                ($0.episodeNumber ?? 0) < ($1.episodeNumber ?? 0)
            }
        }
    }

    var sortedSeasons: [Int] { seasons.keys.sorted() }
    var episodeCount: Int { seasons.values.reduce(0) { $0 + $1.count } }

    var watchedCount: Int {
        allEpisodes.filter(\.watched).count
    }

    var nextUnwatched: MediaItem? {
        allEpisodes.first { !$0.watched }
    }
}
