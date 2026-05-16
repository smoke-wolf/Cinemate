import Foundation

// MARK: - Music Track

struct MusicTrack: Identifiable, Hashable, Codable {
    let id: Int64
    var title: String
    var artist: String
    var album: String
    var albumArtist: String?
    var trackNumber: Int
    var discNumber: Int
    var year: Int?
    var genre: String?
    var duration: Double // seconds
    var bitrate: Int? // kbps
    var format: String // mp3, flac, aac, etc.
    var filePath: String
    var albumArtPath: String?
    var favorite: Bool
    var playCount: Int
    var lastPlayed: Date?
    var isExplicit: Bool

    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var bitrateFormatted: String {
        guard let br = bitrate else { return format.uppercased() }
        return "\(br) kbps \(format.uppercased())"
    }

    var longDurationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Music Album

struct MusicAlbum: Identifiable, Hashable {
    let id: String // artist + album name composite
    var name: String
    var artist: String
    var year: Int?
    var genre: String?
    var trackCount: Int
    var totalDuration: Double
    var artPath: String?
    var tracks: [MusicTrack]

    var durationFormatted: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

// MARK: - Music Artist

struct MusicArtist: Identifiable, Hashable {
    var name: String
    var trackCount: Int
    var albumCount: Int
    var totalDuration: Double
    var albums: [MusicAlbum]

    var id: String { name }

    var durationFormatted: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes) min"
    }
}

// MARK: - Artist Profile (enriched)

struct ArtistProfile: Codable {
    let name: String
    let bio: String?
    let imageURL: String?
    let genres: [String]
    let popularity: Int?
    let followers: Int?
    let wikipediaURL: String?
    let trackCount: Int
    let albumCount: Int

    enum CodingKeys: String, CodingKey {
        case name, bio, genres, popularity, followers
        case imageURL = "image_url"
        case wikipediaURL = "wikipedia_url"
        case trackCount = "track_count"
        case albumCount = "album_count"
    }

    var formattedFollowers: String? {
        guard let followers, followers > 0 else { return nil }
        if followers >= 1_000_000 {
            return String(format: "%.1fM fans", Double(followers) / 1_000_000)
        } else if followers >= 1_000 {
            return String(format: "%.0fK fans", Double(followers) / 1_000)
        }
        return "\(followers) fans"
    }
}

// MARK: - Playlist

struct Playlist: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var description: String?
    var coverImagePath: String?
    var trackCount: Int
    var totalDuration: Double
    var tracks: [MusicTrack]
    var createdAt: Date

    var durationFormatted: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes) min"
    }
}

// MARK: - Now Playing State

enum RepeatMode: String, CaseIterable {
    case off
    case all
    case one
}

struct NowPlayingState {
    var currentTrack: MusicTrack?
    var queue: [MusicTrack] = []
    var isPlaying: Bool = false
    var progress: Double = 0 // seconds
    var volume: Double = 0.75 // 0...1
    var shuffle: Bool = false
    var repeatMode: RepeatMode = .off
    var queueIndex: Int = 0

    var progressPercent: Double {
        guard let track = currentTrack, track.duration > 0 else { return 0 }
        return min(progress / track.duration, 1.0)
    }

    var progressFormatted: String {
        let minutes = Int(progress) / 60
        let seconds = Int(progress) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var remainingFormatted: String {
        guard let track = currentTrack else { return "0:00" }
        let remaining = max(track.duration - progress, 0)
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "-%d:%02d", minutes, seconds)
    }
}
