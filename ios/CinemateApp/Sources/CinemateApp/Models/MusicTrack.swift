import Foundation

struct MusicTrack: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let artist: String
    let albumTitle: String?
    let albumId: Int?
    let trackNumber: Int?
    let duration: TimeInterval
    var isFavorite: Bool
    var playCount: Int

    var streamURL: String? {
        "/api/music/stream/\(id)"
    }

    var artworkURL: String? {
        guard let albumId else { return nil }
        return "/api/music/art/\(albumId)"
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, artist, duration
        case albumTitle = "album"
        case albumId = "album_id"
        case trackNumber = "track_number"
        case isFavorite = "is_favorite"
        case playCount = "play_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        albumTitle = try container.decodeIfPresent(String.self, forKey: .albumTitle)
        albumId = try container.decodeIfPresent(Int.self, forKey: .albumId)
        trackNumber = try container.decodeIfPresent(Int.self, forKey: .trackNumber)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        playCount = try container.decodeIfPresent(Int.self, forKey: .playCount) ?? 0
    }

    init(id: Int, title: String, artist: String, albumTitle: String?, albumId: Int?,
         trackNumber: Int?, duration: TimeInterval, isFavorite: Bool, playCount: Int) {
        self.id = id; self.title = title; self.artist = artist
        self.albumTitle = albumTitle; self.albumId = albumId
        self.trackNumber = trackNumber; self.duration = duration
        self.isFavorite = isFavorite; self.playCount = playCount
    }
}

struct MusicAlbum: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let artist: String
    let year: Int?
    let genre: String?
    let trackCount: Int
    let dateAdded: String?

    var title: String { name }

    var artworkURL: String? {
        "/api/music/art/\(id)"
    }

    var trackCountDisplay: String {
        "\(trackCount) track\(trackCount == 1 ? "" : "s")"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, artist, year, genre
        case trackCount = "track_count"
        case dateAdded = "date_added"
    }
}

struct MusicArtist: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let albumCount: Int
    let trackCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case albumCount = "album_count"
        case trackCount = "track_count"
    }
}

struct ArtistProfile: Codable {
    let name: String
    let bio: String?
    let imageURL: String?
    let genres: [String]
    let spotifyId: String?
    let popularity: Int?
    let followers: Int?
    let wikipediaURL: String?
    let trackCount: Int
    let albumCount: Int

    enum CodingKeys: String, CodingKey {
        case name, bio, genres, popularity, followers
        case imageURL = "image_url"
        case spotifyId = "spotify_id"
        case wikipediaURL = "wikipedia_url"
        case trackCount = "track_count"
        case albumCount = "album_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        bio = try c.decodeIfPresent(String.self, forKey: .bio)
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        genres = try c.decodeIfPresent([String].self, forKey: .genres) ?? []
        spotifyId = try c.decodeIfPresent(String.self, forKey: .spotifyId)
        popularity = try c.decodeIfPresent(Int.self, forKey: .popularity)
        followers = try c.decodeIfPresent(Int.self, forKey: .followers)
        wikipediaURL = try c.decodeIfPresent(String.self, forKey: .wikipediaURL)
        trackCount = try c.decodeIfPresent(Int.self, forKey: .trackCount) ?? 0
        albumCount = try c.decodeIfPresent(Int.self, forKey: .albumCount) ?? 0
    }

    var formattedFollowers: String? {
        guard let followers, followers > 0 else { return nil }
        if followers >= 1_000_000 {
            return String(format: "%.1fM", Double(followers) / 1_000_000)
        } else if followers >= 1_000 {
            return String(format: "%.0fK", Double(followers) / 1_000)
        }
        return "\(followers)"
    }
}

struct Playlist: Identifiable, Codable, Hashable {
    let id: Int
    var name: String
    var trackIds: [Int]
    let createdAt: String?

    var trackCountDisplay: String {
        "\(trackIds.count) track\(trackIds.count == 1 ? "" : "s")"
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case trackIds = "track_ids"
        case createdAt = "created_at"
    }
}

extension MusicTrack {
    static let preview = MusicTrack(
        id: 1, title: "Bohemian Rhapsody", artist: "Queen",
        albumTitle: "A Night at the Opera", albumId: 1,
        trackNumber: 11, duration: 354, isFavorite: true, playCount: 42
    )

    static let previewList: [MusicTrack] = [
        .preview,
        MusicTrack(id: 2, title: "Stairway to Heaven", artist: "Led Zeppelin", albumTitle: "Led Zeppelin IV", albumId: 2, trackNumber: 4, duration: 482, isFavorite: false, playCount: 28),
        MusicTrack(id: 3, title: "Hotel California", artist: "Eagles", albumTitle: "Hotel California", albumId: 3, trackNumber: 1, duration: 391, isFavorite: true, playCount: 35),
        MusicTrack(id: 4, title: "Comfortably Numb", artist: "Pink Floyd", albumTitle: "The Wall", albumId: 4, trackNumber: 22, duration: 383, isFavorite: false, playCount: 19),
        MusicTrack(id: 5, title: "November Rain", artist: "Guns N' Roses", albumTitle: "Use Your Illusion I", albumId: 5, trackNumber: 5, duration: 537, isFavorite: false, playCount: 15),
    ]
}

extension MusicAlbum {
    static let preview = MusicAlbum(
        id: 1, name: "A Night at the Opera", artist: "Queen",
        year: 1975, genre: "Rock", trackCount: 12, dateAdded: nil
    )

    static let previewList: [MusicAlbum] = [
        .preview,
        MusicAlbum(id: 2, name: "Led Zeppelin IV", artist: "Led Zeppelin", year: 1971, genre: "Rock", trackCount: 8, dateAdded: nil),
        MusicAlbum(id: 3, name: "Hotel California", artist: "Eagles", year: 1977, genre: "Rock", trackCount: 9, dateAdded: nil),
        MusicAlbum(id: 4, name: "The Wall", artist: "Pink Floyd", year: 1979, genre: "Progressive Rock", trackCount: 26, dateAdded: nil),
    ]
}

extension MusicArtist {
    static let preview = MusicArtist(
        id: 1, name: "Queen", albumCount: 4, trackCount: 45
    )

    static let previewList: [MusicArtist] = [
        .preview,
        MusicArtist(id: 2, name: "Led Zeppelin", albumCount: 3, trackCount: 72),
        MusicArtist(id: 3, name: "Pink Floyd", albumCount: 5, trackCount: 68),
        MusicArtist(id: 4, name: "Eagles", albumCount: 2, trackCount: 34),
    ]
}

extension ArtistProfile {
    static let preview = ArtistProfile.makePreview(
        name: "Queen",
        bio: "Queen are a British rock band formed in London in 1970. Their classic line-up was Freddie Mercury (lead vocals, piano), Brian May (guitar, vocals), Roger Taylor (drums, vocals) and John Deacon (bass). Their earliest works were influenced by progressive rock, hard rock and heavy metal, but the band gradually ventured into more conventional and radio-friendly works.",
        genres: ["rock", "classic rock", "glam rock"],
        popularity: 89,
        followers: 45_000_000,
        trackCount: 45,
        albumCount: 4
    )

    static func makePreview(
        name: String, bio: String?, genres: [String] = [],
        popularity: Int? = nil, followers: Int? = nil,
        trackCount: Int = 0, albumCount: Int = 0
    ) -> ArtistProfile {
        let json: [String: Any] = [
            "name": name, "bio": bio as Any, "genres": genres,
            "popularity": popularity as Any, "followers": followers as Any,
            "track_count": trackCount, "album_count": albumCount,
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(ArtistProfile.self, from: data)
    }
}
