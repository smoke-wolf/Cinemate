import SwiftUI

struct TVShowsView: View {
    let shows: [TVShow]
    let onPlay: (MediaItem) -> Void
    let onFavorite: (MediaItem) -> Void
    let onDetail: (MediaItem) -> Void

    @State private var selectedShow: TVShow?
    @State private var selectedSeason: Int?

    var body: some View {
        if shows.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "tv")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text("No TV shows found")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let show = selectedShow {
            showDetailView(show)
        } else {
            showGridView
        }
    }

    private var showGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 24)], spacing: 24) {
                ForEach(shows) { show in
                    ShowCard(show: show) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedShow = show
                            selectedSeason = nil
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private func showDetailView(_ show: TVShow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedShow = nil
                            selectedSeason = nil
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(show.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)

                        HStack(spacing: 12) {
                            if let year = show.year {
                                Text(String(year)).foregroundColor(.gray)
                            }
                            Text("\(show.episodeCount) episodes").foregroundColor(.gray)
                            Text("\(show.sortedSeasons.count) season\(show.sortedSeasons.count == 1 ? "" : "s")").foregroundColor(.gray)

                            if show.watchedCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("\(show.watchedCount)/\(show.episodeCount) watched")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .font(.system(size: 13))
                    }
                    Spacer()
                }

                if let desc = show.description_ {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(white: 0.06))

            // Season pills
            if show.sortedSeasons.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SeasonPill(label: "All", isSelected: selectedSeason == nil) {
                            selectedSeason = nil
                        }
                        ForEach(show.sortedSeasons, id: \.self) { season in
                            SeasonPill(label: "Season \(season)", isSelected: selectedSeason == season) {
                                selectedSeason = season
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                }
                .background(Color(white: 0.08))
            }

            // Episodes
            ScrollView {
                let episodes: [MediaItem] = {
                    if let s = selectedSeason { return show.seasons[s] ?? [] }
                    return show.allEpisodes
                }()

                LazyVStack(spacing: 2) {
                    ForEach(episodes) { episode in
                        EpisodeRow(episode: episode,
                                   onPlay: { onPlay(episode) },
                                   onFavorite: { onFavorite(episode) },
                                   onDetail: { onDetail(episode) })
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
    }
}

struct ShowCard: View {
    let show: TVShow
    let onTap: () -> Void

    @State private var isHovered = false
    @State private var thumbnailImage: NSImage?

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    Color(white: 0.15)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay {
                            if let image = thumbnailImage {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .layoutPriority(-1)
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "tv")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray.opacity(0.5))
                                    Text("\(show.episodeCount) episodes")
                                        .font(.caption)
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                            }
                        }
                        .overlay {
                            if isHovered {
                                Color.black.opacity(0.4)
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    if show.watchedCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                            Text("\(show.watchedCount)/\(show.episodeCount)")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.85))
                        .cornerRadius(4)
                        .padding(8)
                    }
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
                }
                .scaleEffect(isHovered ? 1.03 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHovered)

                Text(show.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let year = show.year { Text(String(year)) }
                    Text("\(show.sortedSeasons.count)S \(show.episodeCount)E")
                }
                .font(.system(size: 12))
                .foregroundColor(.gray)
            }
        }
        .buttonStyle(.plain)
        .task {
            if let firstEp = show.allEpisodes.first {
                if let path = await ThumbnailGenerator.generate(for: firstEp) {
                    thumbnailImage = NSImage(contentsOfFile: path)
                }
            }
        }
    }
}

struct EpisodeRow: View {
    let episode: MediaItem
    let onPlay: () -> Void
    let onFavorite: () -> Void
    let onDetail: () -> Void

    @State private var isHovered = false
    @State private var thumbnailImage: NSImage?

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            ZStack {
                Color(white: 0.15)
                    .frame(width: 160, height: 90)
                    .overlay {
                        if let image = thumbnailImage {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .layoutPriority(-1)
                        } else {
                            Image(systemName: "film")
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                    .overlay {
                        if isHovered {
                            Color.black.opacity(0.4)
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                if episode.watchProgress > 0 && !episode.watched && episode.duration > 0 {
                    VStack {
                        Spacer()
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.orange)
                                .frame(width: geo.size.width * CGFloat(episode.watchProgress / episode.duration), height: 3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 3)
                    }
                    .frame(width: 160, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(width: 160, height: 90)
            .contentShape(Rectangle())
            .onTapGesture(perform: onPlay)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(episode.episodeLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)

                    if episode.watched {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                }

                if let desc = episode.description_ {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Text(episode.fileSizeFormatted)
                    Text(episode.fileExtension)
                    if !episode.durationFormatted.isEmpty {
                        Text(episode.durationFormatted)
                    }
                    if episode.playCount > 0 {
                        Label("\(episode.playCount)x", systemImage: "play.fill")
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onDetail) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)

                Button(action: onFavorite) {
                    Image(systemName: episode.favorite ? "heart.fill" : "heart")
                        .foregroundColor(episode.favorite ? .red : .gray)
                }
                .buttonStyle(.plain)

                Button(action: onPlay) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isHovered ? Color.white.opacity(0.04) : Color.clear)
        .cornerRadius(8)
        .onHover { isHovered = $0 }
        .task {
            if let path = await ThumbnailGenerator.generate(for: episode) {
                thumbnailImage = NSImage(contentsOfFile: path)
            }
        }
    }
}

struct SeasonPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(isSelected ? Color.white : Color.white.opacity(0.1))
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}
