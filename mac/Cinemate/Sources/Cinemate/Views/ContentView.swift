import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: LibraryViewModel
    let onSwitchProfile: () -> Void

    var body: some View {
        ZStack {
            if let playing = viewModel.playingItem {
                VideoPlayerView(
                    item: playing,
                    onClose: { viewModel.stopPlaying() },
                    accountId: viewModel.currentAccountId
                )
            } else if let readingBook = viewModel.bookViewModel.readingBook {
                BookReaderView(
                    book: readingBook,
                    onClose: { viewModel.bookViewModel.closeReader() },
                    accountId: viewModel.currentAccountId,
                    readAsEbook: viewModel.bookViewModel.readAsEbook
                )
            } else {
                mainView
            }
        }
        .sheet(item: $viewModel.detailItem) { item in
            MovieDetailSheet(
                movie: item,
                onPlay: { viewModel.play(item) },
                onFavorite: { viewModel.toggleFavorite(item) },
                onToggleWatched: { viewModel.toggleWatched(item) }
            )
        }
        .sheet(item: $viewModel.bookViewModel.selectedBook) { book in
            BookDetailView(
                book: book,
                onRead: { viewModel.bookViewModel.openReader(book) },
                onFavorite: { viewModel.bookViewModel.toggleFavorite(book) },
                onMarkFinished: { viewModel.bookViewModel.markFinished(book) },
                onOpenInBooks: { viewModel.bookViewModel.openInBooksApp(book) },
                viewModel: viewModel.bookViewModel
            )
        }
        .onAppear {
            viewModel.loadLibrary()
            viewModel.bookViewModel.loadBooks()
            if viewModel.movies.isEmpty && viewModel.shows.isEmpty {
                let defaultPath = "/Volumes/Maliq Backup/Movies RF"
                if FileManager.default.fileExists(atPath: defaultPath) {
                    viewModel.scan(directory: defaultPath)
                }
            }
            detectRunningServer()
        }
        .preferredColorScheme(.dark)
    }

    private var mainView: some View {
        HStack(spacing: 0) {
            SidebarView(viewModel: viewModel)

            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField("Search movies & shows...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .onChange(of: viewModel.searchQuery) { _, newValue in
                            viewModel.search(newValue)
                        }

                    if !viewModel.searchQuery.isEmpty {
                        Button(action: { viewModel.search("") }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(white: 0.08))

                Divider().background(Color.gray.opacity(0.2))

                switch viewModel.currentTab {
                case .browse:
                    browseView
                case .tvShows:
                    TVShowsView(
                        shows: viewModel.shows,
                        onPlay: { viewModel.play($0) },
                        onFavorite: { viewModel.toggleFavorite($0) },
                        onDetail: { viewModel.showDetail($0) }
                    )
                case .music:
                    MusicView(viewModel: viewModel.musicViewModel)
                case .books:
                    booksTabView
                case .favorites:
                    MovieGrid(
                        movies: viewModel.favorites,
                        onTap: { viewModel.showDetail($0) },
                        onPlay: { viewModel.play($0) },
                        onFavorite: { viewModel.toggleFavorite($0) }
                    )
                case .recent:
                    MovieGrid(
                        movies: viewModel.recentlyPlayed,
                        onTap: { viewModel.showDetail($0) },
                        onPlay: { viewModel.play($0) },
                        onFavorite: { viewModel.toggleFavorite($0) }
                    )
                case .downloads:
                    DownloadQueueView(downloadManager: viewModel.downloadManager)
                case .devices:
                    DevicesView(downloadManager: viewModel.downloadManager, serverURL: viewModel.serverURL)
                case .lanAdmin:
                    LANAdminView(viewModel: viewModel)
                case .profile:
                    ProfileView(viewModel: viewModel, onSwitchProfile: onSwitchProfile)
                case .settings:
                    SettingsView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.1))
        }
    }

    @ViewBuilder
    private var booksTabView: some View {
        BooksView(viewModel: viewModel.bookViewModel)
    }

    @ViewBuilder
    private var browseView: some View {
        if viewModel.qualityFilter != nil {
            MovieGrid(
                movies: viewModel.filteredMovies,
                onTap: { viewModel.showDetail($0) },
                onPlay: { viewModel.play($0) },
                onFavorite: { viewModel.toggleFavorite($0) }
            )
        } else if viewModel.searchQuery.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if !viewModel.continueWatching.isEmpty {
                        MovieRow(
                            title: "Continue Watching",
                            movies: viewModel.continueWatching,
                            onTap: { viewModel.showDetail($0) },
                            onPlay: { viewModel.play($0) },
                            onFavorite: { viewModel.toggleFavorite($0) }
                        )
                    }

                    if !viewModel.favorites.isEmpty {
                        MovieRow(
                            title: "My Favorites",
                            movies: viewModel.favorites,
                            onTap: { viewModel.showDetail($0) },
                            onPlay: { viewModel.play($0) },
                            onFavorite: { viewModel.toggleFavorite($0) }
                        )
                    }

                    MovieRow(
                        title: "Recently Added",
                        movies: Array(viewModel.movies.prefix(30)),
                        onTap: { viewModel.showDetail($0) },
                        onPlay: { viewModel.play($0) },
                        onFavorite: { viewModel.toggleFavorite($0) }
                    )

                    ForEach(viewModel.genreRows) { row in
                        MovieRow(
                            title: row.genre,
                            movies: row.movies,
                            onTap: { viewModel.showDetail($0) },
                            onPlay: { viewModel.play($0) },
                            onFavorite: { viewModel.toggleFavorite($0) }
                        )
                    }
                }
                .padding(.vertical, 24)
            }
        } else {
            MovieGrid(
                movies: viewModel.movies,
                onTap: { viewModel.showDetail($0) },
                onPlay: { viewModel.play($0) },
                onFavorite: { viewModel.toggleFavorite($0) }
            )
        }
    }

    private func detectRunningServer() {
        for port in ["9876", "8000"] {
            guard let url = URL(string: "http://localhost:\(port)/api/server/info") else { continue }
            URLSession.shared.dataTask(with: url) { _, response, _ in
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    DispatchQueue.main.async {
                        let addr = "http://localhost:\(port)"
                        viewModel.serverURL = addr
                        viewModel.musicViewModel.serverURL = addr
                    }
                }
            }.resume()
        }
    }
}
