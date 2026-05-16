import SwiftUI
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    @Published var movies: [MediaItem] = []
    @Published var shows: [TVShow] = []
    @Published var favorites: [MediaItem] = []
    @Published var recentlyPlayed: [MediaItem] = []
    @Published var continueWatching: [MediaItem] = []
    @Published var genreRows: [GenreRow] = []
    @Published var searchQuery = ""
    @Published var sortOption: SortOption = .title
    @Published var isScanning = false
    @Published var scanProgress = 0
    @Published var currentTab: Tab = .browse
    @Published var detailItem: MediaItem?
    @Published var playingItem: MediaItem?
    @Published var totalWatchTime: Double = 0
    @Published var qualityFilter: String? = nil
    @Published var genreBreakdown: [(genre: String, total: Int, watched: Int)] = []
    @Published var qualityBreakdown: [(quality: String, count: Int)] = []
    @Published var topRatedMovies: [MediaItem] = []
    @Published var watchedMovieCount: Int = 0
    @Published var averageRating: Int? = nil
    @Published var recentlyWatchedMovies: [MediaItem] = []

    // Account support
    @Published var currentAccountId: Int64? = nil
    @Published var currentAccount: Account? = nil

    // Server connection
    @Published var serverURL: String? = nil

    // Book library
    @Published var bookViewModel = BookViewModel()

    // Music library
    @Published var musicViewModel = MusicViewModel()

    // Download manager
    @Published var downloadManager = MacDownloadManager()

    init() {
        bookViewModel.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        musicViewModel.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    enum Tab: String, CaseIterable {
        case browse = "Browse"
        case tvShows = "TV Shows"
        case music = "Music"
        case books = "Books"
        case favorites = "Favorites"
        case recent = "Recently Played"
        case downloads = "Downloads"
        case devices = "Devices"
        case lanAdmin = "Network"
        case settings = "Settings"
        case profile = "Profile"
    }

    var filteredMovies: [MediaItem] {
        guard let filter = qualityFilter, !filter.isEmpty else { return movies }
        return movies.filter { item in
            guard let q = item.quality else { return false }
            return q.localizedCaseInsensitiveContains(filter)
        }
    }

    var totalWatchTimeFormatted: String {
        guard totalWatchTime > 0 else { return "0m" }
        let hours = Int(totalWatchTime) / 3600
        let minutes = (Int(totalWatchTime) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    func setAccount(_ account: Account) {
        currentAccountId = account.id
        currentAccount = account
        bookViewModel.accountId = account.id
    }

    func switchProfile() {
        currentAccountId = nil
        currentAccount = nil
    }

    func loadLibrary() {
        let aid = currentAccountId
        movies = Database.shared.allMovies(sortBy: sortOption, searchQuery: searchQuery, accountId: aid)
        shows = Database.shared.allShows(accountId: aid)
        favorites = Database.shared.favorites(accountId: aid)
        recentlyPlayed = Database.shared.recentlyPlayed(accountId: aid)
        continueWatching = Database.shared.continueWatching(accountId: aid)
        genreRows = Database.shared.moviesByGenre(accountId: aid).map { GenreRow(genre: $0.0, movies: $0.1) }
        totalWatchTime = Database.shared.totalWatchTime(accountId: aid)
        genreBreakdown = Database.shared.genreBreakdown(accountId: aid)
        qualityBreakdown = Database.shared.qualityBreakdown()
        topRatedMovies = Database.shared.topRated(limit: 10)
        watchedMovieCount = Database.shared.watchedMovieCount(accountId: aid)
        averageRating = Database.shared.averageRating()
        recentlyWatchedMovies = Database.shared.recentlyWatched(limit: 10, accountId: aid)
    }

    private var lastScanRefresh = 0

    func scan(directory: String) {
        isScanning = true
        scanProgress = 0
        lastScanRefresh = 0
        Task {
            let count = await MovieScanner.scan(directory: directory) { progress in
                Task { @MainActor in
                    self.scanProgress = progress
                    if progress - self.lastScanRefresh >= 10 {
                        self.lastScanRefresh = progress
                        self.loadLibrary()
                    }
                }
            }
            self.isScanning = false
            Database.shared.backfillDescriptions()
            Database.shared.backfillGenresAndRatings()
            self.loadLibrary()
            print("Scan complete: \(count) items indexed")
        }
    }

    func search(_ query: String) {
        searchQuery = query
        movies = Database.shared.allMovies(sortBy: sortOption, searchQuery: query, accountId: currentAccountId)
    }

    func sort(by option: SortOption) {
        sortOption = option
        movies = Database.shared.allMovies(sortBy: option, searchQuery: searchQuery, accountId: currentAccountId)
    }

    func toggleFavorite(_ item: MediaItem) {
        Database.shared.toggleFavorite(movieId: item.id, accountId: currentAccountId)
        loadLibrary()
    }

    func toggleWatched(_ item: MediaItem) {
        Database.shared.toggleWatched(movieId: item.id, accountId: currentAccountId)
        loadLibrary()
    }

    func play(_ item: MediaItem) {
        playingItem = item
    }

    func stopPlaying() {
        playingItem = nil
        loadLibrary()
    }

    func showDetail(_ item: MediaItem) {
        detailItem = item
    }
}
