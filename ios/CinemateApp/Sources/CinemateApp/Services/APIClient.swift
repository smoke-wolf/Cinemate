import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case noConnection
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case notFound
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .noConnection: return "Unable to connect to server"
        case .serverError(let code): return "Server error (\(code))"
        case .decodingError: return "Failed to parse server response"
        case .networkError(let error): return error.localizedDescription
        case .unauthorized: return "Authentication required"
        case .notFound: return "Resource not found"
        case .timeout: return "Request timed out"
        }
    }
}

@MainActor
final class APIClient: ObservableObject {
    @Published var baseURL: String = ""
    @Published var isConnected: Bool = false
    @Published var serverStatus: ServerStatus?

    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func configure(url: String) {
        var cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.hasSuffix("/") {
            cleanURL = String(cleanURL.dropLast())
        }
        if !cleanURL.hasPrefix("http") {
            cleanURL = "http://\(cleanURL)"
        }
        self.baseURL = cleanURL
    }

    func testConnection() async throws -> ServerStatus {
        let status: ServerStatus = try await get("/api/status")
        self.isConnected = true
        self.serverStatus = status
        return status
    }

    // MARK: - Movies

    func getMovies() async throws -> [MediaItem] {
        let response: PaginatedResponse<MediaItem> = try await get("/api/library?media_type=movie&limit=500")
        return response.items.map { $0.withServerURLs(base: baseURL) }
    }

    func getMovie(id: String) async throws -> MediaItem {
        let item: MediaItem = try await get("/api/library/\(id)")
        return item.withServerURLs(base: baseURL)
    }

    func toggleFavorite(accountId: Int, movieId: String) async throws {
        try await post("/api/accounts/\(accountId)/favorites/\(movieId)", body: EmptyBody())
    }

    func updateWatchProgress(accountId: Int, movieId: String, position: Double, duration: Double? = nil) async throws {
        try await put("/api/accounts/\(accountId)/progress/\(movieId)",
                      body: WatchProgressBody(position: position, duration: duration))
    }

    // MARK: - TV Shows

    func getTVShows() async throws -> [TVShow] {
        let response: PaginatedResponse<MediaItem> = try await get("/api/library?media_type=tv&limit=500")

        // Apply server URLs to all episodes first so thumbnail/stream URLs are absolute
        let allEpisodes = response.items.map { $0.withServerURLs(base: baseURL) }

        return Dictionary(grouping: allEpisodes, by: { $0.showName ?? $0.title })
            .map { rawName, episodes in
                // Strip trailing year from show name (e.g. "Blue Lights 2023" → "Blue Lights")
                let name = rawName.replacingOccurrences(
                    of: #"\s+\d{4}$"#,
                    with: "",
                    options: .regularExpression
                ).trimmingCharacters(in: .whitespaces)

                // Group episodes by season number, falling back to season 1
                let bySeasonNumber = Dictionary(grouping: episodes, by: { $0.seasonNumber ?? 1 })
                let seasons: [Season] = bySeasonNumber
                    .sorted { $0.key < $1.key }
                    .map { seasonNum, seasonEpisodes in
                        let sortedEps = seasonEpisodes.sorted { ($0.episodeNumber ?? 0) < ($1.episodeNumber ?? 0) }
                        let seasonEpObjects = sortedEps.map { ep in
                            Episode(
                                id: ep.id,
                                number: ep.episodeNumber ?? 0,
                                title: "Episode \(ep.episodeNumber ?? 0)",
                                description: ep.description,
                                duration: ep.duration,
                                thumbnailURL: ep.thumbnailURL,
                                streamURL: ep.streamURL,
                                isWatched: ep.isWatched,
                                watchProgress: ep.watchProgress
                            )
                        }
                        return Season(
                            id: "\(name)-S\(seasonNum)",
                            number: seasonNum,
                            title: "Season \(seasonNum)",
                            episodes: seasonEpObjects
                        )
                    }

                // Use the thumbnail of the first episode that has one, or fall back to /api/thumbnail/{firstId}
                let thumbnailURL = episodes.first(where: { $0.thumbnailURL != nil })?.thumbnailURL
                    ?? episodes.first.map { "\(baseURL)/api/thumbnail/\($0.id)" }

                return TVShow(
                    id: name,
                    title: name,
                    year: episodes.first?.year,
                    genre: episodes.first?.genre ?? [],
                    rating: episodes.first?.rating,
                    description: nil,
                    thumbnailURL: thumbnailURL,
                    seasons: seasons,
                    isFavorite: false,
                    dateAdded: episodes.first?.dateAdded
                )
            }
            .sorted { $0.name < $1.name }
    }

    func getTVShow(id: String) async throws -> TVShow {
        let shows = try await getTVShows()
        guard let show = shows.first(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        return show
    }

    // MARK: - Music

    func getMusicTracks(search: String? = nil, artist: String? = nil, album: String? = nil, albumId: Int? = nil) async throws -> [MusicTrack] {
        var path = "/api/music/tracks?limit=500"
        if let search { path += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
        if let artist { path += "&artist=\(artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
        if let album { path += "&album=\(album.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
        if let albumId { path += "&album_id=\(albumId)" }
        let response: PaginatedResponse<MusicTrack> = try await get(path)
        return response.items
    }

    func getAlbums() async throws -> [MusicAlbum] {
        let response: PaginatedResponse<MusicAlbum> = try await get("/api/music/albums?limit=500")
        return response.items
    }

    func getArtists() async throws -> [MusicArtist] {
        let response: PaginatedResponse<MusicArtist> = try await get("/api/music/artists?limit=500")
        return response.items
    }

    func getArtistProfile(name: String) async throws -> ArtistProfile {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return try await get("/api/music/artists/\(encoded)/profile")
    }

    func artistImageURL(name: String) -> URL? {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return URL(string: "\(baseURL)/api/music/artists/\(encoded)/image")
    }

    func getPlaylists(accountId: Int) async throws -> [Playlist] {
        let response: PlaylistsResponse = try await get("/api/accounts/\(accountId)/playlists")
        return response.playlists
    }

    func getRecentTracks(accountId: Int) async throws -> [MusicTrack] {
        let response: ItemsResponse<MusicTrack> = try await get("/api/accounts/\(accountId)/music/recently-played")
        return response.items
    }

    func getMusicFavorites(accountId: Int) async throws -> [MusicTrack] {
        let response: ItemsResponse<MusicTrack> = try await get("/api/accounts/\(accountId)/music/favorites")
        return response.items
    }

    func toggleMusicFavorite(accountId: Int, trackId: Int) async throws {
        try await post("/api/accounts/\(accountId)/music/favorites/\(trackId)", body: EmptyBody())
    }

    func createPlaylist(accountId: Int, name: String, description: String? = nil) async throws -> Playlist {
        try await post("/api/accounts/\(accountId)/playlists",
                       body: CreatePlaylistBody(name: name, description: description))
    }

    func addTrackToPlaylist(accountId: Int, playlistId: Int, trackId: Int) async throws {
        try await post("/api/accounts/\(accountId)/playlists/\(playlistId)/tracks",
                       body: AddTrackBody(trackIds: [trackId]))
    }

    func logPlay(accountId: Int, trackId: Int, duration: Double) async throws {
        try await post("/api/accounts/\(accountId)/music/history",
                       body: PlayHistoryBody(trackId: trackId, durationListened: duration))
    }

    func getPlaylistDetail(accountId: Int, playlistId: Int) async throws -> PlaylistDetail {
        try await get("/api/accounts/\(accountId)/playlists/\(playlistId)")
    }

    func streamURL(trackId: Int) -> URL? {
        URL(string: "\(baseURL)/api/music/stream/\(trackId)")
    }

    func albumArtURL(albumId: Int) -> URL? {
        URL(string: "\(baseURL)/api/music/art/\(albumId)")
    }

    // MARK: - Books

    func getBooks(search: String? = nil, format: String? = nil) async throws -> [Book] {
        var path = "/api/books?limit=500"
        if let search { path += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
        if let format { path += "&format=\(format)" }
        let response: PaginatedResponse<Book> = try await get(path)
        return response.items
    }

    func getBookStats() async throws -> BookStats {
        try await get("/api/books/stats")
    }

    func updateBookProgress(accountId: Int, bookId: Int, progress: Double, page: Int) async throws {
        try await put("/api/books/accounts/\(accountId)/books/\(bookId)/progress",
                      body: BookProgressBody(progress: progress, currentPage: page))
    }

    func toggleBookFavorite(accountId: Int, bookId: Int) async throws {
        try await post("/api/books/accounts/\(accountId)/books/\(bookId)/favorite", body: EmptyBody())
    }

    func addBookBookmark(accountId: Int, bookId: Int, page: Int, note: String?) async throws {
        try await post("/api/books/accounts/\(accountId)/books/\(bookId)/bookmarks",
                       body: BookmarkBody(page: page, note: note))
    }

    func bookCoverURL(bookId: Int) -> URL? {
        URL(string: "\(baseURL)/api/books/cover/\(bookId)")
    }

    func bookReadURL(bookId: Int) -> URL? {
        URL(string: "\(baseURL)/api/books/read/\(bookId)")
    }

    func bookEpubURL(bookId: Int, chapter: Int = 0) -> URL? {
        URL(string: "\(baseURL)/api/books/read/\(bookId)/epub?chapter=\(chapter)")
    }

    // MARK: - Accounts

    func getAccounts() async throws -> [Account] {
        let response: AccountsResponse = try await get("/api/accounts")
        return response.accounts
    }

    func getAccountStats(accountId: Int) async throws -> AccountStats {
        try await get("/api/accounts/\(accountId)/stats")
    }

    func createAccount(_ account: Account) async throws -> Account {
        try await post("/api/accounts", body: account)
    }

    // MARK: - Sync & Downloads

    func registerDevice(deviceId: String, name: String, deviceType: String, accountId: Int? = nil) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/api/sync/devices/register") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = DeviceRegistrationBody(deviceId: deviceId, name: name, deviceType: deviceType, accountId: accountId)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError(
                DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Expected JSON object"))
            )
        }
        return json
    }

    func deviceHeartbeat(deviceId: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/sync/devices/\(deviceId)/heartbeat") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(EmptyBody())

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func createDownloadJobs(deviceId: String, items: [(contentType: String, contentId: Int)]) async throws -> [DownloadJobResponse] {
        let body = DownloadJobsRequestBody(
            deviceId: deviceId,
            items: items.map { DownloadJobItem(contentType: $0.contentType, contentId: $0.contentId) }
        )
        let response: DownloadJobsResponse = try await post("/api/sync/downloads", body: body)
        return response.jobs
    }

    func reportLibrary(deviceId: String, items: [(contentType: String, contentId: Int, hash: String?, size: Int64)]) async throws {
        let body = LibraryReportBody(
            items: items.map {
                LibraryReportItem(contentType: $0.contentType, contentId: $0.contentId, hash: $0.hash, size: $0.size)
            }
        )
        try await post("/api/sync/devices/\(deviceId)/report-library", body: body) as Void
    }

    // MARK: - Streaming URLs

    func streamURL(for path: String) -> URL? {
        URL(string: "\(baseURL)\(path)")
    }

    func thumbnailURL(for path: String?) -> URL? {
        guard let path = path else { return nil }
        return URL(string: "\(baseURL)\(path)")
    }

    // MARK: - Generic Methods

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)
            try validateResponse(response)
            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response)
            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func post<B: Encodable>(_ path: String, body: B) async throws {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    private func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response)
            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func put<B: Encodable>(_ path: String, body: B) async throws {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        switch httpResponse.statusCode {
        case 200...299: return
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        default: throw APIError.serverError(httpResponse.statusCode)
        }
    }
}

private struct EmptyBody: Encodable {}
private struct BookmarkBody: Encodable { let page: Int; let note: String? }
private struct CreatePlaylistBody: Encodable { let name: String; let description: String? }
private struct AddTrackBody: Encodable {
    let trackIds: [Int]
    enum CodingKeys: String, CodingKey { case trackIds = "track_ids" }
}
private struct PlayHistoryBody: Encodable {
    let trackId: Int
    let durationListened: Double
    enum CodingKeys: String, CodingKey {
        case trackId = "track_id"
        case durationListened = "duration_listened"
    }
}
private struct BookProgressBody: Encodable {
    let progress: Double
    let currentPage: Int?
    enum CodingKeys: String, CodingKey {
        case progress
        case currentPage = "current_page"
    }
}

private struct WatchProgressBody: Encodable {
    let position: Double
    let duration: Double?
}

struct PaginatedResponse<T: Decodable>: Decodable {
    let items: [T]
    let total: Int
    let limit: Int
    let offset: Int
}

struct ItemsResponse<T: Decodable>: Decodable {
    let items: [T]
}

struct PlaylistsResponse: Decodable {
    let playlists: [Playlist]
}

struct PlaylistDetail: Decodable {
    let id: Int
    let name: String
    let description: String?
    let trackCount: Int
    let totalDuration: Double?
    let tracks: [MusicTrack]

    enum CodingKeys: String, CodingKey {
        case id, name, description, tracks
        case trackCount = "track_count"
        case totalDuration = "total_duration"
    }
}

// MARK: - Sync Request/Response Types

private struct DeviceRegistrationBody: Encodable {
    let deviceId: String
    let name: String
    let deviceType: String
    let accountId: Int?

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case name
        case deviceType = "device_type"
        case accountId = "account_id"
    }
}

private struct DownloadJobsRequestBody: Encodable {
    let deviceId: String
    let items: [DownloadJobItem]

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case items
    }
}

private struct DownloadJobItem: Encodable {
    let contentType: String
    let contentId: Int

    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case contentId = "content_id"
    }
}

private struct LibraryReportBody: Encodable {
    let items: [LibraryReportItem]
}

private struct LibraryReportItem: Encodable {
    let contentType: String
    let contentId: Int
    let hash: String?
    let size: Int64

    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case contentId = "content_id"
        case hash
        case size
    }
}

struct BookStats: Codable {
    let totalBooks: Int
    let totalAuthors: Int
    let totalPages: Int
    let totalSizeBytes: Int64
    let formatBreakdown: [FormatCount]?

    struct FormatCount: Codable {
        let format: String
        let count: Int
    }

    enum CodingKeys: String, CodingKey {
        case totalBooks = "total_books"
        case totalAuthors = "total_authors"
        case totalPages = "total_pages"
        case totalSizeBytes = "total_size_bytes"
        case formatBreakdown = "format_breakdown"
    }
}
