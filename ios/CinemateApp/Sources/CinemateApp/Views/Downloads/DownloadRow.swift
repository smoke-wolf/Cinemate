import SwiftUI

struct DownloadRow: View {
    @EnvironmentObject var apiClient: APIClient
    let record: DownloadRecord
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail placeholder
            thumbnailView

            // Title, subtitle, and progress
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                if let subtitle = record.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                // Progress bar for active downloads
                if record.status == .downloading || record.status == .paused || record.status == .queued {
                    HStack(spacing: 8) {
                        GoldProgressBar(progress: record.progress, height: 3)

                        Text(progressText)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.textTertiary)
                    }
                } else {
                    // Size and date for completed/failed
                    HStack(spacing: 6) {
                        Text(record.formattedSize)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)

                        if record.status == .completed, let date = record.downloadedAt {
                            Text("\u{2022}")
                                .font(.system(size: 8))
                                .foregroundStyle(Theme.textTertiary)
                            Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textTertiary)
                        }

                        if record.status == .failed {
                            Text("\u{2022} Failed")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.error)
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            // Action buttons
            actionButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.cardSurface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))
    }

    // MARK: - Thumbnail

    private var thumbnailView: some View {
        CachedAsyncImage(url: apiClient.thumbnailURL(for: record.thumbnailPath)) {
            RoundedRectangle(cornerRadius: Theme.cornerSmall)
                .fill(
                    LinearGradient(
                        colors: [Theme.cardSurface, Theme.elevatedSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: contentTypeIcon)
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.textTertiary)
                }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))
    }

    private var contentTypeIcon: String {
        switch record.contentType {
        case .media: return "film"
        case .musicTrack: return "music.note"
        case .book: return "book"
        }
    }

    // MARK: - Progress Text

    private var progressText: String {
        switch record.status {
        case .queued:
            return "Waiting..."
        case .paused:
            return "\(Int(record.progress * 100))% \u{2022} Paused"
        case .downloading:
            return "\(Int(record.progress * 100))%"
        default:
            return ""
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Group {
            switch record.status {
            case .downloading, .paused:
                circleButton(icon: "xmark", color: Theme.textTertiary, action: onCancel)

            case .queued:
                circleButton(icon: "xmark", color: Theme.textTertiary, action: onCancel)

            case .completed:
                circleButton(icon: "trash", color: Theme.textTertiary, action: onDelete)

            case .failed:
                HStack(spacing: 8) {
                    circleButton(icon: "arrow.clockwise", color: Theme.error, action: onRetry)
                    circleButton(icon: "trash", color: Theme.textTertiary, action: onDelete)
                }

            case .cancelled:
                circleButton(icon: "trash", color: Theme.textTertiary, action: onDelete)
            }
        }
    }

    private func circleButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            hapticImpact(.light)
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(Theme.elevatedSurface)
                .clipShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 8) {
            DownloadRow(
                record: DownloadRecord(
                    id: "1", contentType: .media, contentId: 1,
                    title: "The Dark Knight", subtitle: "2008 \u{2022} Action",
                    thumbnailPath: nil, downloadPath: nil, status: .downloading,
                    fileSize: 2_500_000_000, bytesDownloaded: 1_250_000_000,
                    localFileName: nil, downloadedAt: nil, errorMessage: nil
                ),
                onCancel: {}, onRetry: {}, onDelete: {}
            )

            DownloadRow(
                record: DownloadRecord(
                    id: "2", contentType: .musicTrack, contentId: 2,
                    title: "Bohemian Rhapsody", subtitle: "Queen",
                    thumbnailPath: nil, downloadPath: nil, status: .completed,
                    fileSize: 12_400_000, bytesDownloaded: 12_400_000,
                    localFileName: "song.mp3", downloadedAt: Date(), errorMessage: nil
                ),
                onCancel: {}, onRetry: {}, onDelete: {}
            )

            DownloadRow(
                record: DownloadRecord(
                    id: "3", contentType: .book, contentId: 3,
                    title: "Dune", subtitle: "Frank Herbert",
                    thumbnailPath: nil, downloadPath: nil, status: .failed,
                    fileSize: 5_000_000, bytesDownloaded: 2_000_000,
                    localFileName: nil, downloadedAt: nil, errorMessage: "Connection lost"
                ),
                onCancel: {}, onRetry: {}, onDelete: {}
            )
        }
        .padding()
    }
    .environmentObject(APIClient())
}
