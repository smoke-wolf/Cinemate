import Foundation

struct MediaItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let year: Int?
    let genre: [String]
    let rating: Double?
    let quality: String?
    let duration: TimeInterval?
    let fileSize: Int64?
    let description: String?
    let thumbnailURL: String?
    let streamURL: String?
    var isFavorite: Bool
    var isWatched: Bool
    var watchProgress: Double
    let dateAdded: Date?

    var formattedDuration: String {
        guard let duration = duration else { return "" }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedFileSize: String {
        guard let size = fileSize else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var qualityType: QualityType {
        QualityType(rawValue: quality ?? "") ?? .unknown
    }

    var genreDisplay: String {
        genre.joined(separator: " \u{2022} ")
    }

    var ratingStars: Double {
        (rating ?? 0) / 2.0
    }

    enum CodingKeys: String, CodingKey {
        case id, title, year, genre, rating, quality, duration, description
        case fileSize = "file_size"
        case thumbnailURL = "thumbnail_url"
        case streamURL = "stream_url"
        case isFavorite = "is_favorite"
        case isWatched = "is_watched"
        case watchProgress = "watch_progress"
        case dateAdded = "date_added"
    }
}

enum QualityType: String, Codable {
    case uhd4k = "4K"
    case fullHD = "1080p"
    case hd = "720p"
    case sd = "480p"
    case unknown

    var displayName: String { rawValue }

    var badgeColor: String {
        switch self {
        case .uhd4k: return "#9333EA"
        case .fullHD: return "#3B82F6"
        case .hd: return "#14B8A6"
        case .sd: return "#6B7280"
        case .unknown: return "#6B7280"
        }
    }
}

extension MediaItem {
    static let preview = MediaItem(
        id: "1",
        title: "Inception",
        year: 2010,
        genre: ["Sci-Fi", "Action", "Thriller"],
        rating: 8.8,
        quality: "4K",
        duration: 8880,
        fileSize: 4_500_000_000,
        description: "A thief who steals corporate secrets through the use of dream-sharing technology is given the inverse task of planting an idea into the mind of a C.E.O., but his tragic past may doom the project and his team to disaster.",
        thumbnailURL: nil,
        streamURL: "/api/stream/1",
        isFavorite: true,
        isWatched: false,
        watchProgress: 0.35,
        dateAdded: Date()
    )

    static let previewList: [MediaItem] = [
        .preview,
        MediaItem(id: "2", title: "The Dark Knight", year: 2008, genre: ["Action", "Crime", "Drama"], rating: 9.0, quality: "1080p", duration: 9120, fileSize: 3_200_000_000, description: "When the menace known as the Joker wreaks havoc and chaos on the people of Gotham, Batman must accept one of the greatest psychological and physical tests of his ability to fight injustice.", thumbnailURL: nil, streamURL: "/api/stream/2", isFavorite: false, isWatched: true, watchProgress: 1.0, dateAdded: Date()),
        MediaItem(id: "3", title: "Interstellar", year: 2014, genre: ["Adventure", "Drama", "Sci-Fi"], rating: 8.7, quality: "4K", duration: 10140, fileSize: 5_800_000_000, description: "When Earth becomes uninhabitable in the future, a farmer and ex-NASA pilot, Joseph Cooper, is tasked to pilot a spacecraft, along with a team of researchers, to find a new planet for humans.", thumbnailURL: nil, streamURL: "/api/stream/3", isFavorite: true, isWatched: false, watchProgress: 0.0, dateAdded: Date()),
        MediaItem(id: "4", title: "Blade Runner 2049", year: 2017, genre: ["Action", "Drama", "Mystery"], rating: 8.0, quality: "4K", duration: 9840, fileSize: 6_100_000_000, description: "Young Blade Runner K's discovery of a long-buried secret leads him to track down former Blade Runner Rick Deckard, who's been missing for thirty years.", thumbnailURL: nil, streamURL: "/api/stream/4", isFavorite: false, isWatched: false, watchProgress: 0.72, dateAdded: Date().addingTimeInterval(-86400)),
        MediaItem(id: "5", title: "Dune", year: 2021, genre: ["Action", "Adventure", "Drama"], rating: 8.0, quality: "1080p", duration: 9360, fileSize: 3_900_000_000, description: "A noble family becomes embroiled in a war for control over the galaxy's most valuable asset while its heir becomes troubled by visions of a dark future.", thumbnailURL: nil, streamURL: "/api/stream/5", isFavorite: false, isWatched: true, watchProgress: 1.0, dateAdded: Date().addingTimeInterval(-172800)),
    ]
}
