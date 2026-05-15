import Foundation

struct MusicTrack: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let artist: String
    let albumTitle: String?
    let albumId: String?
    let trackNumber: Int?
    let duration: TimeInterval
    let streamURL: String?
    let artworkURL: String?
    var isFavorite: Bool
    var playCount: Int

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, artist, duration
        case albumTitle = "album_title"
        case albumId = "album_id"
        case trackNumber = "track_number"
        case streamURL = "stream_url"
        case artworkURL = "artwork_url"
        case isFavorite = "is_favorite"
        case playCount = "play_count"
    }
}

struct MusicAlbum: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let artist: String
    let year: Int?
    let genre: String?
    let artworkURL: String?
    let tracks: [MusicTrack]
    let dateAdded: Date?

    var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }

    var formattedDuration: String {
        let totalMinutes = Int(totalDuration) / 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(totalMinutes) min"
    }

    var trackCountDisplay: String {
        "\(tracks.count) track\(tracks.count == 1 ? "" : "s")"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, artist, year, genre, tracks
        case artworkURL = "artwork_url"
        case dateAdded = "date_added"
    }
}

struct MusicArtist: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let artworkURL: String?
    let albums: [MusicAlbum]
    let trackCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, albums
        case artworkURL = "artwork_url"
        case trackCount = "track_count"
    }
}

struct Playlist: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var tracks: [MusicTrack]
    let createdDate: Date?
    var artworkURL: String?

    var trackCountDisplay: String {
        "\(tracks.count) track\(tracks.count == 1 ? "" : "s")"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, tracks
        case createdDate = "created_date"
        case artworkURL = "artwork_url"
    }
}

extension MusicTrack {
    static let preview = MusicTrack(
        id: "t1", title: "Bohemian Rhapsody", artist: "Queen",
        albumTitle: "A Night at the Opera", albumId: "a1",
        trackNumber: 11, duration: 354, streamURL: "/api/music/stream/t1",
        artworkURL: nil, isFavorite: true, playCount: 42
    )

    static let previewList: [MusicTrack] = [
        .preview,
        MusicTrack(id: "t2", title: "Stairway to Heaven", artist: "Led Zeppelin", albumTitle: "Led Zeppelin IV", albumId: "a2", trackNumber: 4, duration: 482, streamURL: "/api/music/stream/t2", artworkURL: nil, isFavorite: false, playCount: 28),
        MusicTrack(id: "t3", title: "Hotel California", artist: "Eagles", albumTitle: "Hotel California", albumId: "a3", trackNumber: 1, duration: 391, streamURL: "/api/music/stream/t3", artworkURL: nil, isFavorite: true, playCount: 35),
        MusicTrack(id: "t4", title: "Comfortably Numb", artist: "Pink Floyd", albumTitle: "The Wall", albumId: "a4", trackNumber: 22, duration: 383, streamURL: "/api/music/stream/t4", artworkURL: nil, isFavorite: false, playCount: 19),
        MusicTrack(id: "t5", title: "November Rain", artist: "Guns N' Roses", albumTitle: "Use Your Illusion I", albumId: "a5", trackNumber: 5, duration: 537, streamURL: "/api/music/stream/t5", artworkURL: nil, isFavorite: false, playCount: 15),
    ]
}

extension MusicAlbum {
    static let preview = MusicAlbum(
        id: "a1", title: "A Night at the Opera", artist: "Queen",
        year: 1975, genre: "Rock", artworkURL: nil,
        tracks: MusicTrack.previewList, dateAdded: Date()
    )

    static let previewList: [MusicAlbum] = [
        .preview,
        MusicAlbum(id: "a2", title: "Led Zeppelin IV", artist: "Led Zeppelin", year: 1971, genre: "Rock", artworkURL: nil, tracks: [], dateAdded: Date()),
        MusicAlbum(id: "a3", title: "Hotel California", artist: "Eagles", year: 1977, genre: "Rock", artworkURL: nil, tracks: [], dateAdded: Date()),
        MusicAlbum(id: "a4", title: "The Wall", artist: "Pink Floyd", year: 1979, genre: "Progressive Rock", artworkURL: nil, tracks: [], dateAdded: Date()),
    ]
}

extension MusicArtist {
    static let preview = MusicArtist(
        id: "ar1", name: "Queen", artworkURL: nil,
        albums: MusicAlbum.previewList, trackCount: 45
    )

    static let previewList: [MusicArtist] = [
        .preview,
        MusicArtist(id: "ar2", name: "Led Zeppelin", artworkURL: nil, albums: [], trackCount: 72),
        MusicArtist(id: "ar3", name: "Pink Floyd", artworkURL: nil, albums: [], trackCount: 68),
        MusicArtist(id: "ar4", name: "Eagles", artworkURL: nil, albums: [], trackCount: 34),
    ]
}
