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
        case compact
        case expanded
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

    private var isInteractive: Bool {
        switch record?.status {
        case .downloading, .queued, .completed, .paused:
            return false
        default:
            return true
        }
    }

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: buttonSize, height: buttonSize)

                switch record?.status {
                case .downloading:
                    downloadingState

                case .queued, .paused:
                    ProgressView()
                        .scaleEffect(style == .compact ? 0.6 : 0.7)
                        .tint(Theme.primaryGold)

                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: iconSize + 2, weight: .bold))
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
        .disabled(!isInteractive)
        .opacity(isInteractive ? 1.0 : 0.85)
    }

    private var downloadingState: some View {
        ZStack {
            Circle()
                .stroke(Theme.textTertiary.opacity(0.3), lineWidth: ringLineWidth)
                .frame(width: buttonSize - 6, height: buttonSize - 6)

            Circle()
                .trim(from: 0, to: max(0.05, record?.progress ?? 0))
                .stroke(Theme.primaryGold, style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
                .frame(width: buttonSize - 6, height: buttonSize - 6)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: record?.progress)

            Image(systemName: "xmark")
                .font(.system(size: style == .compact ? 7 : 9, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var backgroundColor: Color {
        switch record?.status {
        case .completed:
            return Theme.success.opacity(0.15)
        case .failed:
            return Theme.error.opacity(0.15)
        case .downloading, .paused, .queued:
            return Theme.primaryGold.opacity(0.15)
        case .cancelled, nil:
            return Theme.elevatedSurface.opacity(0.9)
        }
    }

    private func handleTap() {
        hapticImpact(.light)

        guard let record = record else {
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
        case .failed, .cancelled:
            downloadManager.retryDownload(id: record.id)
        case .downloading, .queued, .paused, .completed:
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
