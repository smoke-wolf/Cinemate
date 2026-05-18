import SwiftUI

struct OfflineLibraryView: View {
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var downloadManager: DownloadManager

    var onReconnect: () -> Void

    @State private var isReconnecting = false
    @State private var reconnectError: String?

    private var musicDownloads: [DownloadRecord] {
        downloadManager.completedDownloads.filter { $0.contentType == .musicTrack }
    }

    private var bookDownloads: [DownloadRecord] {
        downloadManager.completedDownloads.filter { $0.contentType == .book }
    }

    private var mediaDownloads: [DownloadRecord] {
        downloadManager.completedDownloads.filter { $0.contentType == .media }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        offlineBanner
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .padding(.bottom, 16)

                        if !musicDownloads.isEmpty {
                            sectionHeader(title: "Music", icon: "music.note", count: musicDownloads.count)
                            musicSection
                        }

                        if !bookDownloads.isEmpty {
                            sectionHeader(title: "Books", icon: "book.fill", count: bookDownloads.count)
                            bookSection
                        }

                        if !mediaDownloads.isEmpty {
                            sectionHeader(title: "Movies & TV", icon: "film.fill", count: mediaDownloads.count)
                            mediaSection
                        }
                    }
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Offline Library")
            .cinemateToolbarBackground(Theme.background)
            .cinemateToolbarColorScheme(.dark)
        }
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.primaryGold)

                Text("You're offline. Downloaded content is available below.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)

                Spacer()
            }

            if let error = reconnectError {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GoldButton(
                title: isReconnecting ? "Connecting..." : "Reconnect",
                icon: isReconnecting ? nil : "arrow.clockwise",
                action: attemptReconnect,
                isFullWidth: true,
                size: .small
            )
            .disabled(isReconnecting)
            .opacity(isReconnecting ? 0.6 : 1.0)
        }
        .padding(16)
        .background(Theme.primaryGold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .stroke(Theme.primaryGold.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.primaryGold)

            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Text("\(count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Music Section

    private var musicSection: some View {
        LazyVStack(spacing: 4) {
            ForEach(musicDownloads) { record in
                musicRow(record: record)
            }
        }
        .padding(.horizontal)
    }

    private func musicRow(record: DownloadRecord) -> some View {
        Button(action: {
            hapticImpact(.light)
            audioPlayer.playDownloadedTrack(record: record)
        }) {
            HStack(spacing: 12) {
                // Thumbnail
                CachedAsyncImage(url: apiClient.thumbnailURL(for: record.thumbnailPath)) {
                    AlbumArtPlaceholder(size: 48)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))

                // Title + Artist
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    if let subtitle = record.subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Play icon
                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.primaryGold)
                    .frame(width: 32, height: 32)
                    .background(Theme.primaryGold.opacity(0.12))
                    .clipShape(Circle())
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Theme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Book Section

    private var bookSection: some View {
        LazyVStack(spacing: 4) {
            ForEach(bookDownloads) { record in
                contentRow(record: record, icon: "book.fill")
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Media Section

    private var mediaSection: some View {
        LazyVStack(spacing: 4) {
            ForEach(mediaDownloads) { record in
                contentRow(record: record, icon: "film.fill")
            }
        }
        .padding(.horizontal)
    }

    private func contentRow(record: DownloadRecord, icon: String) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            CachedAsyncImage(url: apiClient.thumbnailURL(for: record.thumbnailPath)) {
                RoundedRectangle(cornerRadius: Theme.cornerSmall)
                    .fill(Theme.elevatedSurface)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.textTertiary)
                    }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))

            // Title + Subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                if let subtitle = record.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Downloaded indicator
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.success)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))
    }

    // MARK: - Reconnect

    private func attemptReconnect() {
        guard !isReconnecting else { return }
        isReconnecting = true
        reconnectError = nil

        Task {
            do {
                _ = try await apiClient.testConnection()
                await MainActor.run {
                    isReconnecting = false
                    onReconnect()
                }
            } catch {
                await MainActor.run {
                    isReconnecting = false
                    reconnectError = "Could not reach server. Check your connection."
                }
            }
        }
    }
}
