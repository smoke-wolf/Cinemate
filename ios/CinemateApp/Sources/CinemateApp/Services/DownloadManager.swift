import Foundation

@MainActor
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published var activeDownloads: [DownloadRecord] = []
    @Published var completedDownloads: [DownloadRecord] = []
    @Published var isDownloading = false

    private var runningTasks: [String: Task<Void, Never>] = [:]
    private let db = DownloadDatabase()
    private var serverBaseURL: String = ""

    private init() {
        cleanStaleDownloads()
        refreshState()
    }

    func configure(serverBaseURL: String) {
        var url = serverBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasSuffix("/") { url = String(url.dropLast()) }
        if !url.hasPrefix("http") { url = "http://\(url)" }
        self.serverBaseURL = url
        print("[DL] configured serverBaseURL=\(url)")
    }

    // MARK: - Enqueue

    func enqueueDownload(
        contentType: DownloadContentType,
        contentId: Int,
        title: String,
        subtitle: String? = nil,
        thumbnailPath: String? = nil,
        fileSize: Int64,
        downloadPath: String
    ) {
        if let existing = (activeDownloads + completedDownloads).first(where: {
            $0.contentType == contentType && $0.contentId == contentId
        }) {
            if existing.status == .completed || existing.status == .downloading { return }
            db.delete(id: existing.id)
        }

        let id = UUID().uuidString
        let record = DownloadRecord(
            id: id, contentType: contentType, contentId: contentId,
            title: title, subtitle: subtitle, thumbnailPath: thumbnailPath,
            downloadPath: downloadPath, status: .downloading,
            fileSize: fileSize, bytesDownloaded: 0,
            localFileName: nil, downloadedAt: nil, errorMessage: nil
        )
        db.insert(record)
        refreshState()

        let path = downloadPath.hasPrefix("/") ? downloadPath : "/\(downloadPath)"
        let urlString = "\(serverBaseURL)\(path)"
        print("[DL] enqueue id=\(id) serverBaseURL='\(serverBaseURL)' urlString='\(urlString)'")
        guard let url = URL(string: urlString) else {
            print("[DL] FAILED: invalid URL from '\(urlString)'")
            var failed = record
            failed.status = .failed
            failed.errorMessage = "Invalid URL"
            db.update(failed)
            refreshState()
            return
        }

        print("[DL] starting task for \(url.absoluteString)")
        let task = Task {
            await self.runDownload(id: id, url: url, contentType: contentType)
        }
        runningTasks[id] = task
    }

    // MARK: - Download Logic

    private func runDownload(id: String, url: URL, contentType: DownloadContentType) async {
        print("[DL] runDownload START id=\(id) url=\(url)")
        do {
            print("[DL] calling URLSession.shared.download...")
            let (tempURL, response) = try await URLSession.shared.download(from: url)
            print("[DL] download finished, tempURL=\(tempURL)")

            guard !Task.isCancelled else {
                print("[DL] task was cancelled")
                try? FileManager.default.removeItem(at: tempURL)
                return
            }

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("[DL] FAILED: server error \(code)")
                failRecord(id: id, message: "Server error \(code)")
                return
            }
            print("[DL] HTTP \(http.statusCode), content-length=\(http.expectedContentLength)")

            guard var record = findRecord(id: id) else {
                print("[DL] record not found after download, cleaning up")
                try? FileManager.default.removeItem(at: tempURL)
                return
            }

            let dir = downloadsDirectory(for: contentType)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let sanitized = sanitizeFileName(record.title)
            let ext = url.pathExtension.isEmpty ? "" : ".\(url.pathExtension)"
            let fileName = "\(record.contentId)_\(sanitized)\(ext)"
            let dest = dir.appendingPathComponent(fileName)
            print("[DL] moving to \(dest.path)")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tempURL, to: dest)

            let attrs = try? FileManager.default.attributesOfItem(atPath: dest.path)
            let size = (attrs?[.size] as? Int64) ?? record.fileSize
            print("[DL] COMPLETED id=\(id) size=\(size)")

            record.status = .completed
            record.localFileName = fileName
            record.downloadedAt = Date()
            record.fileSize = size
            record.bytesDownloaded = size
            db.update(record)
            runningTasks.removeValue(forKey: id)
            refreshState()
        } catch is CancellationError {
            print("[DL] CancellationError id=\(id)")
            return
        } catch {
            print("[DL] ERROR id=\(id): \(error)")
            failRecord(id: id, message: error.localizedDescription)
        }
    }

    private func failRecord(id: String, message: String) {
        if var record = findRecord(id: id) {
            record.status = .failed
            record.errorMessage = message
            db.update(record)
        }
        runningTasks.removeValue(forKey: id)
        refreshState()
    }

    // MARK: - Controls

    func cancelDownload(id: String) {
        runningTasks[id]?.cancel()
        runningTasks.removeValue(forKey: id)
        db.delete(id: id)
        refreshState()
    }

    func retryDownload(id: String) {
        guard let record = findRecord(id: id) else { return }
        let path = record.downloadPath ?? ""
        let contentType = record.contentType
        let contentId = record.contentId
        let title = record.title
        let subtitle = record.subtitle
        let thumbnailPath = record.thumbnailPath
        let fileSize = record.fileSize
        db.delete(id: id)
        refreshState()
        enqueueDownload(
            contentType: contentType, contentId: contentId,
            title: title, subtitle: subtitle,
            thumbnailPath: thumbnailPath, fileSize: fileSize,
            downloadPath: path
        )
    }

    func deleteDownload(id: String) {
        runningTasks[id]?.cancel()
        runningTasks.removeValue(forKey: id)
        if let record = findRecord(id: id), let localFileName = record.localFileName {
            let fileURL = downloadsDirectory(for: record.contentType).appendingPathComponent(localFileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        db.delete(id: id)
        refreshState()
    }

    // MARK: - Queries

    func downloadState(contentType: DownloadContentType, contentId: Int) -> DownloadStatus? {
        let all = activeDownloads + completedDownloads
        return all.first { $0.contentType == contentType && $0.contentId == contentId }?.status
    }

    func localFileURL(contentType: DownloadContentType, contentId: Int) -> URL? {
        guard let record = db.fetch(contentType: contentType, contentId: contentId),
              record.status == .completed,
              let localFileName = record.localFileName else { return nil }
        let url = downloadsDirectory(for: contentType).appendingPathComponent(localFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func isDownloaded(contentType: DownloadContentType, contentId: Int) -> Bool {
        localFileURL(contentType: contentType, contentId: contentId) != nil
    }

    func totalDownloadedSize() -> Int64 {
        completedDownloads.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - State

    func refreshState() {
        let all = db.fetchAll()
        activeDownloads = all.filter {
            $0.status == .queued || $0.status == .downloading || $0.status == .paused || $0.status == .failed
        }
        completedDownloads = all.filter { $0.status == .completed }
        isDownloading = activeDownloads.contains { $0.status == .downloading }
    }

    // MARK: - Helpers

    private func cleanStaleDownloads() {
        for record in db.fetchAll() where record.status == .downloading || record.status == .queued {
            db.delete(id: record.id)
        }
    }

    private func findRecord(id: String) -> DownloadRecord? {
        db.fetchAll().first { $0.id == id }
    }

    private func downloadsDirectory(for contentType: DownloadContentType) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads")
            .appendingPathComponent(contentType.rawValue)
    }

    private func sanitizeFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return name.components(separatedBy: allowed.inverted).joined(separator: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}
