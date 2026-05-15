import Foundation

struct TVShow: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let year: Int?
    let genre: [String]
    let rating: Double?
    let description: String?
    let thumbnailURL: String?
    let seasons: [Season]
    var isFavorite: Bool
    let dateAdded: Date?

    var totalEpisodes: Int {
        seasons.reduce(0) { $0 + $1.episodes.count }
    }

    var watchedEpisodes: Int {
        seasons.reduce(0) { total, season in
            total + season.episodes.filter { $0.isWatched }.count
        }
    }

    var seasonCount: String {
        "\(seasons.count) Season\(seasons.count == 1 ? "" : "s")"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, year, genre, rating, description, seasons
        case thumbnailURL = "thumbnail_url"
        case isFavorite = "is_favorite"
        case dateAdded = "date_added"
    }
}

struct Season: Identifiable, Codable, Hashable {
    let id: String
    let number: Int
    let title: String?
    let episodes: [Episode]

    var displayTitle: String {
        title ?? "Season \(number)"
    }
}

struct Episode: Identifiable, Codable, Hashable {
    let id: String
    let number: Int
    let title: String
    let description: String?
    let duration: TimeInterval?
    let thumbnailURL: String?
    let streamURL: String?
    var isWatched: Bool
    var watchProgress: Double

    var formattedDuration: String {
        guard let duration = duration else { return "" }
        let minutes = Int(duration) / 60
        return "\(minutes)m"
    }

    var episodeLabel: String {
        "E\(String(format: "%02d", number))"
    }

    enum CodingKeys: String, CodingKey {
        case id, number, title, description, duration
        case thumbnailURL = "thumbnail_url"
        case streamURL = "stream_url"
        case isWatched = "is_watched"
        case watchProgress = "watch_progress"
    }
}

extension TVShow {
    static let preview = TVShow(
        id: "tv1",
        title: "Breaking Bad",
        year: 2008,
        genre: ["Crime", "Drama", "Thriller"],
        rating: 9.5,
        description: "A chemistry teacher diagnosed with inoperable lung cancer turns to manufacturing and selling methamphetamine with a former student in order to secure his family's future.",
        thumbnailURL: nil,
        seasons: [
            Season(id: "s1", number: 1, title: "Season 1", episodes: [
                Episode(id: "e1", number: 1, title: "Pilot", description: "Diagnosed with terminal lung cancer, chemistry teacher Walter White teams up with former student Jesse Pinkman to cook and sell crystal meth.", duration: 3480, thumbnailURL: nil, streamURL: "/api/stream/tv1/s1/e1", isWatched: true, watchProgress: 1.0),
                Episode(id: "e2", number: 2, title: "Cat's in the Bag...", description: "Walt and Jesse attempt to tie up loose ends.", duration: 2880, thumbnailURL: nil, streamURL: "/api/stream/tv1/s1/e2", isWatched: true, watchProgress: 1.0),
                Episode(id: "e3", number: 3, title: "...And the Bag's in the River", description: "Walt wrestles with a difficult decision.", duration: 2880, thumbnailURL: nil, streamURL: "/api/stream/tv1/s1/e3", isWatched: false, watchProgress: 0.45),
                Episode(id: "e4", number: 4, title: "Cancer Man", description: "Walt tells the family about his cancer diagnosis.", duration: 2880, thumbnailURL: nil, streamURL: "/api/stream/tv1/s1/e4", isWatched: false, watchProgress: 0.0),
            ]),
            Season(id: "s2", number: 2, title: "Season 2", episodes: [
                Episode(id: "e5", number: 1, title: "Seven Thirty-Seven", description: "Walt and Jesse face the consequences of their actions.", duration: 2880, thumbnailURL: nil, streamURL: "/api/stream/tv1/s2/e1", isWatched: false, watchProgress: 0.0),
                Episode(id: "e6", number: 2, title: "Grilled", description: "Walt and Jesse find themselves in a dire situation.", duration: 2880, thumbnailURL: nil, streamURL: "/api/stream/tv1/s2/e2", isWatched: false, watchProgress: 0.0),
            ]),
        ],
        isFavorite: true,
        dateAdded: Date()
    )

    static let previewList: [TVShow] = [
        .preview,
        TVShow(id: "tv2", title: "Better Call Saul", year: 2015, genre: ["Crime", "Drama"], rating: 8.9, description: "The trials and tribulations of criminal lawyer Jimmy McGill.", thumbnailURL: nil, seasons: [], isFavorite: false, dateAdded: Date()),
        TVShow(id: "tv3", title: "The Wire", year: 2002, genre: ["Crime", "Drama"], rating: 9.3, description: "Baltimore drug scene, seen through the eyes of drug dealers and law enforcement.", thumbnailURL: nil, seasons: [], isFavorite: true, dateAdded: Date()),
    ]
}
