import SwiftUI

struct DownloadButton: View {
    let contentType: DownloadContentType
    let contentId: Int
    let title: String
    let subtitle: String?
    let thumbnailPath: String?
    let fileSize: Int64
    let downloadPath: String

    var style: Style = .compact

    @EnvironmentObject var downloadManager: DownloadManager

    enum Style {
        case compact   // Icon-sized for card overlays
        case expanded  // Slightly larger for detail views
    }

    private var record: DownloadRecord? {
        let all = downloadManager.activeDownloads + downloadManager.completedDownloads
        return all.first { $0.contentType == contentType && $0.contentId == contentId }
    }

    private var iconSize: CGFloat {
        style == .compact ? 14 : 18
    }

    private var buttonSize: CGFloat {
        style == .compact ? 32 : 40
    }

    private var ringLineWidth: CGFloat {
        style == .compact ? 2.5 : 3.0
    }

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                // Background circle
                Circle()
                    .fill(backgroundColor)
                    .frame(width: buttonSize, height: buttonSize)

                // State-specific content
                switch record?.status {
                case .downloading:
                    downloadingState

                case .paused:
                    Image(systemName: "pause.fill")
                        .font(.system(size: iconSize - 2, weight: .semibold))
                        .foregroundStyle(Theme.warmAmber)

                case .queued:
                    ProgressView()
                        .scaleEffect(style == .compact ? 0.6 : 0.7)
                        .tint(Theme.textSecondary)

                case .completed:
                    Image(systemName: "checkmark")
                        .font(.system(size: iconSize - 1, weight: .bold))
                        .foregroundStyle(Theme.success)

                case .failed:
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: iconSize - 1, weight: .semibold))
                        .foregroundStyle(Theme.error)

                case .cancelled, nil:
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Downloading State (circular progress ring)

    private var downloadingState: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(Theme.textTertiary.opacity(0.3), lineWidth: ringLineWidth)
                .frame(width: buttonSize - 6, height: buttonSize - 6)

            // Progress ring
            Circle()
                .trim(from: 0, to: record?.progress ?? 0)
                .stroke(Theme.primaryGold, style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
                .frame(width: buttonSize - 6, height: buttonSize - 6)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: record?.progress)

            // Percentage text (only in expanded)
            if style == .expanded {
                Text("\(Int((record?.progress ?? 0) * 100))")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
            } else {
                // Pause icon hint
                Image(systemName: "pause.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: - Background

    private var backgroundColor: Color {
        switch record?.status {
        case .completed:
            return Theme.success.opacity(0.15)
        case .failed:
            return Theme.error.opacity(0.15)
        case .downloading, .paused, .queued:
            return Theme.elevatedSurface.opacity(0.9)
        case .cancelled, nil:
            return Theme.elevatedSurface.opacity(0.9)
        }
    }

    // MARK: - Action

    private func handleTap() {
        hapticImpact(.light)

        guard let record = record else {
            // Not downloaded -- enqueue
            downloadManager.enqueueDownload(
                contentType: contentType,
                contentId: contentId,
                title: title,
                subtitle: subtitle,
                thumbnailPath: thumbnailPath,
                fileSize: fileSize,
                downloadPath: downloadPath
            )
            return
        }

        switch record.status {
        case .downloading:
            downloadManager.pauseDownload(id: record.id)
        case .paused:
            downloadManager.resumeDownload(id: record.id)
        case .failed, .cancelled:
            downloadManager.deleteDownload(id: record.id)
            downloadManager.enqueueDownload(
                contentType: contentType,
                contentId: contentId,
                title: title,
                subtitle: subtitle,
                thumbnailPath: thumbnailPath,
                fileSize: fileSize,
                downloadPath: downloadPath
            )
        case .completed:
            // Already downloaded, no action
            break
        case .queued:
            // Waiting in queue, no action
            break
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        HStack(spacing: 20) {
            // These will render as "not downloaded" state
            DownloadButton(
                contentType: .media,
                contentId: 1,
                title: "Test Movie",
                subtitle: nil,
                thumbnailPath: nil,
                fileSize: 1_500_000_000,
                downloadPath: "/api/media/1/download",
                style: .compact
            )

            DownloadButton(
                contentType: .media,
                contentId: 2,
                title: "Test Movie 2",
                subtitle: nil,
                thumbnailPath: nil,
                fileSize: 2_000_000_000,
                downloadPath: "/api/media/2/download",
                style: .expanded
            )
        }
    }
    .environmentObject(DownloadManager.shared)
}
