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
        try await get("/api/movies")
    }

    func getMovie(id: String) async throws -> MediaItem {
        try await get("/api/movies/\(id)")
    }

    func toggleFavorite(movieId: String) async throws {
        try await post("/api/movies/\(movieId)/favorite", body: EmptyBody())
    }

    func updateWatchProgress(movieId: String, progress: Double) async throws {
        try await post("/api/movies/\(movieId)/progress", body: ["progress": progress])
    }

    // MARK: - TV Shows

    func getTVShows() async throws -> [TVShow] {
        try await get("/api/tvshows")
    }

    func getTVShow(id: String) async throws -> TVShow {
        try await get("/api/tvshows/\(id)")
    }

    // MARK: - Music

    func getAlbums() async throws -> [MusicAlbum] {
        try await get("/api/music/albums")
    }

    func getArtists() async throws -> [MusicArtist] {
        try await get("/api/music/artists")
    }

    func getPlaylists() async throws -> [Playlist] {
        try await get("/api/music/playlists")
    }

    func getRecentTracks() async throws -> [MusicTrack] {
        try await get("/api/music/recent")
    }

    // MARK: - Books

    func getBooks() async throws -> [Book] {
        try await get("/api/books")
    }

    func updateBookProgress(bookId: String, page: Int) async throws {
        try await post("/api/books/\(bookId)/progress", body: ["page": page])
    }

    func addBookBookmark(bookId: String, page: Int, title: String?) async throws {
        let body = BookmarkBody(page: page, title: title ?? "")
        try await post("/api/books/\(bookId)/bookmarks", body: body)
    }

    // MARK: - Accounts

    func getAccounts() async throws -> [Account] {
        try await get("/api/accounts")
    }

    func getAccountStats(accountId: String) async throws -> AccountStats {
        try await get("/api/accounts/\(accountId)/stats")
    }

    func createAccount(_ account: Account) async throws -> Account {
        try await post("/api/accounts", body: account)
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
private struct BookmarkBody: Encodable { let page: Int; let title: String }
