import SwiftUI

struct DownloadQueueView: View {
    @ObservedObject var downloadManager: MacDownloadManager

    private let cardBg = Color(white: 0.11)
    private let cardBorder = Color.white.opacity(0.06)
    private let accentBlue = Color(red: 0.3, green: 0.55, blue: 1.0)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                downloadLocationSection

                if downloadManager.activeDownloads.isEmpty && downloadManager.completedDownloads.isEmpty {
                    emptyState
                } else {
                    if !downloadManager.activeDownloads.isEmpty {
                        activeSection
                    }
                    if !downloadManager.completedDownloads.isEmpty {
                        completedSection
                    }
                }
            }
            .padding(32)
        }
        .background(Color(white: 0.1))
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [accentBlue.opacity(0.2), accentBlue.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentBlue, accentBlue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Downloads")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("\(downloadManager.activeDownloads.count) active, \(downloadManager.completedDownloads.count) completed")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            Spacer()

            if !downloadManager.completedDownloads.isEmpty {
                Button(action: { downloadManager.clearCompleted() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Clear Completed")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Download Location

    private var downloadLocationSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 14))
                .foregroundColor(accentBlue.opacity(0.7))

            VStack(alignment: .leading, spacing: 2) {
                Text("Download Location")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                Text(downloadManager.downloadDirectory.path)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button(action: { downloadManager.setDownloadDirectory() }) {
                Text("Change")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Button(action: {
                NSWorkspace.shared.open(downloadManager.downloadDirectory)
            }) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.to.line")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.08))
            Text("No Downloads")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
            Text("Downloads from your server or external drives will appear here")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.15))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Active Downloads

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Downloads")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 1) {
                ForEach(downloadManager.activeDownloads) { record in
                    activeDownloadRow(record)
                }
            }
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(cardBorder, lineWidth: 1)
            )
        }
    }

    private func activeDownloadRow(_ record: MacDownloadRecord) -> some View {
        HStack(spacing: 14) {
            // Status icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(record.statusColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: record.statusIcon)
                    .font(.system(size: 16))
                    .foregroundColor(record.statusColor)
            }

            // Title and progress
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(record.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if let subtitle = record.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [accentBlue, accentBlue.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * record.progress, height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(record.bytesDownloadedFormatted) of \(record.fileSizeFormatted)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(record.progress * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(accentBlue)
                }

                if let error = record.errorMessage, record.isFailed {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                        .lineLimit(2)
                }
            }

            // Controls
            HStack(spacing: 8) {
                if record.isFailed {
                    Button(action: { downloadManager.retryDownload(id: record.id) }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                } else if record.isPaused {
                    Button(action: { downloadManager.resumeDownload(id: record.id) }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                } else if record.status == "downloading" {
                    Button(action: { downloadManager.pauseDownload(id: record.id) }) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.yellow)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { downloadManager.cancelDownload(id: record.id) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardBg)
    }

    // MARK: - Completed Downloads

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completed")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 1) {
                ForEach(downloadManager.completedDownloads) { record in
                    completedDownloadRow(record)
                }
            }
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(cardBorder, lineWidth: 1)
            )
        }
    }

    private func completedDownloadRow(_ record: MacDownloadRecord) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(record.fileSizeFormatted)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    if let completed = record.completedAt {
                        Text(completedTimeString(completed))
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if let path = record.localFilePath {
                    Button(action: { downloadManager.revealInFinder(path: path) }) {
                        Image(systemName: "folder")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { downloadManager.deleteDownloadRecord(id: record.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardBg)
    }

    private func completedTimeString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
