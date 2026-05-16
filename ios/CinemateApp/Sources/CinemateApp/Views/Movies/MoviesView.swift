import SwiftUI

struct SeeAllDestination: Hashable {
    let title: String
    let items: [MediaItem]
}

struct MoviesView: View {
    @EnvironmentObject var apiClient: APIClient
    let account: Account
    @State private var movies: [MediaItem] = []
    @State private var isLoading = false
    @State private var selectedMovie: MediaItem?
    @State private var searchText = ""
    @State private var seeAllDestination: SeeAllDestination?

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

                if isLoading && movies.isEmpty {
                    moviesSkeletonView
                } else if !isLoading && movies.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.textTertiary)
                        Text("No movies yet")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Text("Your movie library will appear here")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 80)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 28) {
                            if !continueWatching.isEmpty {
                                MediaCarousel(
                                    title: "Continue Watching",
                                    items: continueWatching,
                                    showProgress: true,
                                    onSeeAll: {
                                        seeAllDestination = SeeAllDestination(title: "Continue Watching", items: continueWatching)
                                    }
                                ) { movie in
                                    selectedMovie = movie
                                }
                            }

                            if !favorites.isEmpty {
                                MediaCarousel(
                                    title: "My Favorites",
                                    items: favorites,
                                    onSeeAll: {
                                        seeAllDestination = SeeAllDestination(title: "My Favorites", items: favorites)
                                    }
                                ) { movie in
                                    selectedMovie = movie
                                }
                            }

                            MediaCarousel(
                                title: "Recently Added",
                                items: recentlyAdded,
                                onSeeAll: {
                                    seeAllDestination = SeeAllDestination(title: "Recently Added", items: recentlyAdded)
                                }
                            ) { movie in
                                selectedMovie = movie
                            }

                            ForEach(Array(genres.keys.sorted()), id: \.self) { genre in
                                if let genreMovies = genres[genre], !genreMovies.isEmpty {
                                    MediaCarousel(
                                        title: genre,
                                        items: genreMovies,
                                        onSeeAll: {
                                            seeAllDestination = SeeAllDestination(title: genre, items: genreMovies)
                                        }
                                    ) { movie in
                                        selectedMovie = movie
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        await loadMovies()
                    }
                }
            }
            .navigationTitle("Movies")
            .cinemateToolbarBackground(Theme.background)
            .cinemateToolbarColorScheme(.dark)
            .navigationDestination(item: $selectedMovie) { movie in
                MovieDetailView(movie: movie, account: account)
            }
            .navigationDestination(item: $seeAllDestination) { dest in
                SeeAllView(title: dest.title, items: dest.items, account: account)
            }
        }
        .task {
            await loadMovies()
        }
    }

    private var moviesSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 14) {
                        ShimmerView()
                            .frame(width: 140, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(0..<5, id: \.self) { _ in
                                    ShimmerCard(width: 140, height: 200)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func loadMovies() async {
        isLoading = true
        defer { isLoading = false }
        do {
            movies = try await apiClient.getMovies()
        } catch {}
    }
}

struct MediaCarousel: View {
    let title: String
    let items: [MediaItem]
    var showProgress: Bool = false
    var onSeeAll: (() -> Void)? = nil
    let onTap: (MediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Button(action: { onSeeAll?() }) {
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
    MoviesView(account: Account.previewAccounts[0])
        .environmentObject(APIClient())
        .preferredColorScheme(.dark)
}
