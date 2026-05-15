import SwiftUI

struct MoviesView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var movies: [MediaItem] = MediaItem.previewList
    @State private var isLoading = false
    @State private var selectedMovie: MediaItem?
    @State private var searchText = ""

    private var continueWatching: [MediaItem] {
        movies.filter { $0.watchProgress > 0 && $0.watchProgress < 1 }
    }

    private var favorites: [MediaItem] {
        movies.filter { $0.isFavorite }
    }

    private var recentlyAdded: [MediaItem] {
        movies.sorted { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
    }

    private var genres: [String: [MediaItem]] {
        var genreMap: [String: [MediaItem]] = [:]
        for movie in movies {
            for genre in movie.genre {
                genreMap[genre, default: []].append(movie)
            }
        }
        return genreMap
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        // Continue Watching
                        if !continueWatching.isEmpty {
                            MediaCarousel(
                                title: "Continue Watching",
                                items: continueWatching,
                                showProgress: true
                            ) { movie in
                                selectedMovie = movie
                            }
                        }

                        // Favorites
                        if !favorites.isEmpty {
                            MediaCarousel(
                                title: "My Favorites",
                                items: favorites
                            ) { movie in
                                selectedMovie = movie
                            }
                        }

                        // Recently Added
                        MediaCarousel(
                            title: "Recently Added",
                            items: recentlyAdded
                        ) { movie in
                            selectedMovie = movie
                        }

                        // Genre Rows
                        ForEach(Array(genres.keys.sorted()), id: \.self) { genre in
                            if let genreMovies = genres[genre], !genreMovies.isEmpty {
                                MediaCarousel(
                                    title: genre,
                                    items: genreMovies
                                ) { movie in
                                    selectedMovie = movie
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100) // Tab bar spacing
                }
                .refreshable {
                    await loadMovies()
                }
            }
            .navigationTitle("Movies")
            .cinemateToolbarBackground(Theme.background)
            .cinemateToolbarColorScheme(.dark)
            .navigationDestination(item: $selectedMovie) { movie in
                MovieDetailView(movie: movie)
            }
        }
        .task {
            await loadMovies()
        }
    }

    private func loadMovies() async {
        isLoading = true
        defer { isLoading = false }
        do {
            movies = try await apiClient.getMovies()
        } catch {
            // Keep preview data in demo mode
        }
    }
}

struct MediaCarousel: View {
    let title: String
    let items: [MediaItem]
    var showProgress: Bool = false
    let onTap: (MediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Button(action: {}) {
                    Text("See All")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.primaryGold)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(items) { item in
                        MovieCard(movie: item, showProgress: showProgress) {
                            onTap(item)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    MoviesView()
        .environmentObject(APIClient())
        .preferredColorScheme(.dark)
}
