import SwiftUI

struct TVShowsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var shows: [TVShow] = TVShow.previewList
    @State private var isLoading = false
    @State private var selectedShow: TVShow?

    let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(shows) { show in
                            TVShowCard(show: show) {
                                selectedShow = show
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await loadShows()
                }
            }
            .navigationTitle("TV Shows")
            .cinemateToolbarBackground(Theme.background)
            .cinemateToolbarColorScheme(.dark)
            .navigationDestination(item: $selectedShow) { show in
                TVShowDetailView(show: show)
            }
        }
        .task {
            await loadShows()
        }
    }

    private func loadShows() async {
        isLoading = true
        defer { isLoading = false }
        do {
            shows = try await apiClient.getTVShows()
        } catch {
            // Keep preview data
        }
    }
}

struct TVShowCard: View {
    let show: TVShow
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: nil) {
                        MediaPlaceholder(icon: "tv")
                    }
                    .aspectRatio(16.0/9.0, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))

                    // Episode count badge
                    Text(show.seasonCount)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(show.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let year = show.year {
                            Text("\(year)")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        if let rating = show.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.warmAmber)
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.warmAmber)
                            }
                        }
                    }

                    // Watch progress
                    if show.totalEpisodes > 0 {
                        let progress = Double(show.watchedEpisodes) / Double(show.totalEpisodes)
                        if progress > 0 && progress < 1 {
                            HStack(spacing: 6) {
                                GoldProgressBar(progress: progress, height: 2)
                                Text("\(show.watchedEpisodes)/\(show.totalEpisodes)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    TVShowsView()
        .environmentObject(APIClient())
        .preferredColorScheme(.dark)
}
