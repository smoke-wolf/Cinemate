import SwiftUI

struct TVShowsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var shows: [TVShow] = []
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

                if isLoading && shows.isEmpty {
                    tvShowsSkeletonView
                } else if !isLoading && shows.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tv")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.textTertiary)
                        Text("No TV shows yet")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Text("Your TV shows will appear here")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 80)
                } else {
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

    private var tvShowsSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(0..<6, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        ShimmerView()
                            .aspectRatio(16.0/9.0, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))

                        ShimmerView()
                            .frame(height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        ShimmerView()
                            .frame(width: 80, height: 10)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private func loadShows() async {
        isLoading = true
        defer { isLoading = false }
        do {
            shows = try await apiClient.getTVShows()
        } catch {}
    }
}

struct TVShowCard: View {
    let show: TVShow
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: URL(string: show.thumbnailURL ?? "")) {
                        MediaPlaceholder(icon: "tv")
                    }
                    .aspectRatio(16.0/9.0, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))

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
                            Text(String(year))
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
