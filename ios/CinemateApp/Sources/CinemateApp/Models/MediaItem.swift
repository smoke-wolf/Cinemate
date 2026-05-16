import Foundation

struct MediaItem: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let year: Int?
    let genre: [String]
    let rating: Double?
    let quality: String?
    let duration: TimeInterval?
    let fileSize: Int64?
    let description: String?
    var thumbnailURL: String?
    var streamURL: String?
    var isFavorite: Bool
    var isWatched: Bool
    var watchProgress: Double
    let dateAdded: Date?
    let showName: String?
    let seasonNumber: Int?
    let episodeNumber: Int?

    /// Returns a cleaned version of the title by stripping common rip/codec/release-group
    /// suffixes that appear in raw filenames (e.g. "The Gray Man AAC5 1" → "The Gray Man").
    var cleanTitle: String {
        // Patterns to strip, in order of preference:
        //   1. Quality tags: 720p, 1080p, 2160p, 4K, UHD, HDR, SDR, BDRip, DVDRip, BluRay, WEB-DL, WEBRip, HDTV
        //   2. Codec tags: x264, x265, XviD, H264, H265, AAC, AC3, DTS, MP3 + optional trailing digits/dots
        //   3. Release groups: any word starting with a hyphen (e.g. -aXXo, -iFT, -Blackjesus, -YIFY)
        //   4. Miscellaneous scene tags: BOKUTOX, PROPER, REPACK, EXTENDED, THEATRICAL, UNRATED
        let noisePattern = #"""
        (?xi)
        \s+
        (?:
          # Quality
          (?:2160p|1080p|720p|480p|4K|UHD|HDR|SDR)
          | (?:BDRip|BRRip|BluRay|Blu-Ray|DVDRip|DvDrip|DVD|WEB-DL|WEBRip|HDTV|AMZN|NF|DSNP|HULU)
          # Codec + optional trailing numbers/dots
          | (?:x264|x265|XviD|Xvid|H\.?264|H\.?265|HEVC|AVC|AAC5?(?:\s*[\.\d]+)*|AC3|DTS|MP3|DDP5|DDP|DD5|BOKUTOX)
          # Scene release-group suffixes (hyphen-prefixed word at end of anything)
          | -\w+
          # Misc scene tags
          | (?:PROPER|REPACK|EXTENDED|THEATRICAL|UNRATED|LIMITED|DC|DUBBED|SUBBED|MULTI|REMUX)
        )
        .*$
        """#
        let cleaned = title.replacingOccurrences(
            of: noisePattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        ).trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? title : cleaned
    }

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

    func withServerURLs(base: String) -> MediaItem {
        var copy = self
        if copy.thumbnailURL == nil || copy.thumbnailURL?.hasPrefix("/") == true {
            copy.thumbnailURL = "\(base)/api/thumbnail/\(id)"
        }
        if copy.streamURL == nil || copy.streamURL?.hasPrefix("/") == true {
            copy.streamURL = "\(base)/api/stream/\(id)"
        }
        return copy
    }

    enum CodingKeys: String, CodingKey {
        case id, title, year, genre, rating, quality, duration, description, format
        case fileSize = "file_size"
        case thumbnailURL = "thumbnail_url"
        case thumbnailPath = "thumbnail_path"
        case streamURL = "stream_url"
        case isFavorite = "is_favorite"
        case isWatched = "is_watched"
        case watchProgress = "watch_progress"
        case dateAdded = "date_added"
        case showName = "show_name"
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        if let intId = try? c.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try c.decode(String.self, forKey: .id)
        }

        title = try c.decode(String.self, forKey: .title)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        rating = try c.decodeIfPresent(Double.self, forKey: .rating)
        quality = try c.decodeIfPresent(String.self, forKey: .quality)
            ?? (try c.decodeIfPresent(String.self, forKey: .format))
        duration = try c.decodeIfPresent(TimeInterval.self, forKey: .duration)
        fileSize = try c.decodeIfPresent(Int64.self, forKey: .fileSize)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        showName = try c.decodeIfPresent(String.self, forKey: .showName)
        seasonNumber = try c.decodeIfPresent(Int.self, forKey: .seasonNumber)
        episodeNumber = try c.decodeIfPresent(Int.self, forKey: .episodeNumber)

        if let arr = try? c.decode([String].self, forKey: .genre) {
            genre = arr
        } else if let str = try? c.decode(String.self, forKey: .genre), !str.isEmpty {
            genre = str.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            genre = []
        }

        thumbnailURL = try c.decodeIfPresent(String.self, forKey: .thumbnailURL)
            ?? (try c.decodeIfPresent(String.self, forKey: .thumbnailPath))
        streamURL = try c.decodeIfPresent(String.self, forKey: .streamURL)
        isFavorite = (try? c.decode(Bool.self, forKey: .isFavorite)) ?? false
        isWatched = (try? c.decode(Bool.self, forKey: .isWatched)) ?? false
        watchProgress = (try? c.decode(Double.self, forKey: .watchProgress)) ?? 0

        if let dateStr = try? c.decode(String.self, forKey: .dateAdded) {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateAdded = fmt.date(from: dateStr) ?? ISO8601DateFormatter().date(from: dateStr)
        } else {
            dateAdded = try? c.decode(Date.self, forKey: .dateAdded)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(year, forKey: .year)
        try c.encode(genre, forKey: .genre)
        try c.encodeIfPresent(rating, forKey: .rating)
        try c.encodeIfPresent(quality, forKey: .quality)
        try c.encodeIfPresent(duration, forKey: .duration)
        try c.encodeIfPresent(fileSize, forKey: .fileSize)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try c.encodeIfPresent(streamURL, forKey: .streamURL)
        try c.encode(isFavorite, forKey: .isFavorite)
        try c.encode(isWatched, forKey: .isWatched)
        try c.encode(watchProgress, forKey: .watchProgress)
        try c.encodeIfPresent(showName, forKey: .showName)
    }

    init(id: String, title: String, year: Int?, genre: [String], rating: Double?,
         quality: String?, duration: TimeInterval?, fileSize: Int64?, description: String?,
         thumbnailURL: String?, streamURL: String?, isFavorite: Bool, isWatched: Bool,
         watchProgress: Double, dateAdded: Date?, showName: String? = nil,
         seasonNumber: Int? = nil, episodeNumber: Int? = nil) {
        self.id = id; self.title = title; self.year = year; self.genre = genre
        self.rating = rating; self.quality = quality; self.duration = duration
        self.fileSize = fileSize; self.description = description
        self.thumbnailURL = thumbnailURL; self.streamURL = streamURL
        self.isFavorite = isFavorite; self.isWatched = isWatched
        self.watchProgress = watchProgress; self.dateAdded = dateAdded
        self.showName = showName
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
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
        id: "1", title: "Inception", year: 2010, genre: ["Sci-Fi", "Action", "Thriller"],
        rating: 8.8, quality: "4K", duration: 8880, fileSize: 4_500_000_000,
        description: "A thief who steals corporate secrets through the use of dream-sharing technology.",
        thumbnailURL: nil, streamURL: "/api/stream/1",
        isFavorite: true, isWatched: false, watchProgress: 0.35, dateAdded: Date()
    )

    static let previewList: [MediaItem] = [.preview]
}
