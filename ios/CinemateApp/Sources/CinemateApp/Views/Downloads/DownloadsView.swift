import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject var downloadManager: DownloadManager

    @State private var showClearAllConfirmation = false

    private var activeDownloads: [DownloadRecord] {
        downloadManager.activeDownloads
    }

    private var completedDownloads: [DownloadRecord] {
        downloadManager.completedDownloads
    }

    private var completedMedia: [DownloadRecord] {
        completedDownloads.filter { $0.contentType == .media }
    }

    private var completedMusic: [DownloadRecord] {
        completedDownloads.filter { $0.contentType == .musicTrack }
    }

    private var completedBooks: [DownloadRecord] {
        completedDownloads.filter { $0.contentType == .book }
    }

    private var hasAnyDownloads: Bool {
        !activeDownloads.isEmpty || !completedDownloads.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if hasAnyDownloads {
                    downloadsList
                } else {
                    emptyState
                }
            }
            .navigationTitle("Downloads")
            .cinemateToolbarBackground(Theme.background)
            .cinemateToolbarColorScheme(.dark)
            .alert("Clear All Downloads", isPresented: $showClearAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearAllDownloads()
                }
            } message: {
                Text("This will remove all downloaded files and free up storage. Active downloads will be cancelled.")
            }
        }
    }

    // MARK: - Downloads List

    private var downloadsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Active Downloads Section
                if !activeDownloads.isEmpty {
                    sectionHeader(title: "Active Downloads", count: activeDownloads.count)

                    LazyVStack(spacing: 6) {
                        ForEach(activeDownloads) { record in
                            DownloadRow(
                                record: record,
                                onPause: { downloadManager.pauseDownload(id: record.id) },
                                onResume: { downloadManager.resumeDownload(id: record.id) },
                                onCancel: { downloadManager.cancelDownload(id: record.id) },
                                onRetry: { retryDownload(record) },
                                onDelete: { downloadManager.deleteDownload(id: record.id) }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }

                // Completed Section - Media
                if !completedMedia.isEmpty {
                    completedSection(title: "Movies & TV", icon: "film.fill", items: completedMedia)
                }

                // Completed Section - Music
                if !completedMusic.isEmpty {
                    completedSection(title: "Music", icon: "music.note", items: completedMusic)
                }

                // Completed Section - Books
                if !completedBooks.isEmpty {
                    completedSection(title: "Books", icon: "book.fill", items: completedBooks)
                }

                // Storage Section
                storageSection
                    .padding(.top, 8)
            }
            .padding(.bottom, 140)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, count: Int? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            if let count {
                Text("\(count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.goldGradient)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Completed Section

    private func completedSection(title: String, icon: String, items: [DownloadRecord]) -> some View {
        VStack(spacing: 0) {
            // Section header with icon
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.primaryGold)

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text("\(items.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                Text(totalSize(for: items))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)

            LazyVStack(spacing: 6) {
                ForEach(items) { record in
                    DownloadRow(
                        record: record,
                        onPause: {},
                        onResume: {},
                        onCancel: {},
                        onRetry: {},
                        onDelete: { downloadManager.deleteDownload(id: record.id) }
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Storage")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }

            // Storage bar
            VStack(spacing: 8) {
                HStack {
                    Label {
                        Text("Downloads")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    } icon: {
                        Circle()
                            .fill(Theme.primaryGold)
                            .frame(width: 8, height: 8)
                    }

                    Spacer()

                    Text(formattedTotalSize)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                }

                storageBar

                HStack {
                    Text("\(formattedTotalSize) used")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer()
                    Text("\(formattedAvailableSpace) available")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding()
            .background(Theme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))

            // Clear All button
            if !completedDownloads.isEmpty {
                Button(action: {
                    hapticImpact(.medium)
                    showClearAllConfirmation = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Clear All Downloads")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Theme.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.horizontal)
    }

    private var storageBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.elevatedSurface)
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.goldGradient)
                    .frame(width: geometry.size.width * storageRatio, height: 8)
            }
        }
        .frame(height: 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 56))
                .foregroundStyle(Theme.textTertiary)
                .padding(.bottom, 4)

            Text("No Downloads")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Text("Movies, music, and books you download\nwill appear here for offline access.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }

    // MARK: - Helpers

    private func retryDownload(_ record: DownloadRecord) {
        downloadManager.deleteDownload(id: record.id)
        downloadManager.enqueueDownload(
            contentType: record.contentType,
            contentId: record.contentId,
            title: record.title,
            subtitle: record.subtitle,
            thumbnailPath: record.thumbnailPath,
            fileSize: record.fileSize,
            downloadPath: "/api/sync/downloads/\(record.id)/file"
        )
    }

    private func clearAllDownloads() {
        hapticNotification(.warning)
        let allIds = activeDownloads.map(\.id) + completedDownloads.map(\.id)
        for id in allIds {
            downloadManager.deleteDownload(id: id)
        }
    }

    private func totalSize(for records: [DownloadRecord]) -> String {
        let total = records.reduce(Int64(0)) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private var formattedTotalSize: String {
        let total = downloadManager.totalDownloadedSize()
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private var formattedAvailableSpace: String {
        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? "/"
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: path)
        let freeSpace = (attrs?[.systemFreeSize] as? Int64) ?? 0
        return ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file)
    }

    private var storageRatio: CGFloat {
        let used = downloadManager.totalDownloadedSize()
        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? "/"
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: path)
        let totalSpace = (attrs?[.systemSize] as? Int64) ?? 1
        guard totalSpace > 0 else { return 0 }
        return min(CGFloat(used) / CGFloat(totalSpace), 1.0)
    }
}

#Preview {
    DownloadsView()
        .environmentObject(DownloadManager.shared)
        .preferredColorScheme(.dark)
}
