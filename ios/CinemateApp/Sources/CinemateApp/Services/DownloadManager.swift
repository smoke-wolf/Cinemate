import Foundation

@MainActor
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published var activeDownloads: [DownloadRecord] = []
    @Published var completedDownloads: [DownloadRecord] = []
    @Published var isDownloading = false

    private var backgroundSession: URLSession!
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private let db = DownloadDatabase()
    private var serverBaseURL: String = ""
    private var sessionDelegate: DownloadSessionDelegate!

    private init() {
        sessionDelegate = DownloadSessionDelegate()
        sessionDelegate.manager = self

        let config = URLSessionConfiguration.background(withIdentifier: "com.cinemate.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        backgroundSession = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)

        refreshState()
    }

    // MARK: - Configuration

    func configure(serverBaseURL: String) {
        var url = serverBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasSuffix("/") { url = String(url.dropLast()) }
        if !url.hasPrefix("http") { url = "http://\(url)" }
        self.serverBaseURL = url
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
        let id = UUID().uuidString

        let record = DownloadRecord(
            id: id,
            contentType: contentType,
            contentId: contentId,
            title: title,
            subtitle: subtitle,
            thumbnailPath: thumbnailPath,
            status: .downloading,
            fileSize: fileSize,
            bytesDownloaded: 0,
            localFileName: nil,
            downloadedAt: nil,
            errorMessage: nil
        )

        db.insert(record)

        let urlString = "\(serverBaseURL)/api/sync/downloads/\(id)/file"
        guard let url = URL(string: urlString) else {
            var failed = record
            failed.status = .failed
            failed.errorMessage = "Invalid download URL"
            db.update(failed)
            refreshState()
            return
        }

        let task = backgroundSession.downloadTask(with: url)
        task.taskDescription = id
        downloadTasks[id] = task
        task.resume()

        refreshState()
    }

    // MARK: - Controls

    func pauseDownload(id: String) {
        guard let task = downloadTasks[id] else { return }
        task.cancel(byProducingResumeData: { _ in })

        if var record = findRecord(id: id) {
            record.status = .paused
            db.update(record)
        }
        downloadTasks.removeValue(forKey: id)
        refreshState()
    }

    func resumeDownload(id: String) {
        guard var record = findRecord(id: id) else { return }

        record.status = .downloading
        db.update(record)

        let urlString = "\(serverBaseURL)/api/sync/downloads/\(id)/file"
        guard let url = URL(string: urlString) else { return }

        let task = backgroundSession.downloadTask(with: url)
        task.taskDescription = id
        downloadTasks[id] = task
        task.resume()

        refreshState()
    }

    func cancelDownload(id: String) {
        downloadTasks[id]?.cancel()
        downloadTasks.removeValue(forKey: id)

        if var record = findRecord(id: id) {
            record.status = .cancelled
            db.update(record)
        }
        refreshState()
    }

    func deleteDownload(id: String) {
        downloadTasks[id]?.cancel()
        downloadTasks.removeValue(forKey: id)

        if let record = findRecord(id: id), let localFileName = record.localFileName {
            let fileURL = downloadsDirectory(for: record.contentType)
                .appendingPathComponent(localFileName)
            try? FileManager.default.removeItem(at: fileURL)
        }

        db.delete(id: id)
        refreshState()
    }

    // MARK: - Queries

    func localFileURL(contentType: DownloadContentType, contentId: Int) -> URL? {
        guard let record = db.fetch(contentType: contentType, contentId: contentId),
              record.status == .completed,
              let localFileName = record.localFileName else {
            return nil
        }
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

    // MARK: - Delegate Callbacks (called from DownloadSessionDelegate)

    nonisolated func handleDownloadProgress(taskId: String, bytesWritten: Int64, totalBytesWritten: Int64) {
        Task { @MainActor in
            db.updateProgress(id: taskId, bytesDownloaded: totalBytesWritten, status: .downloading)
            refreshState()
        }
    }

    nonisolated func handleDownloadComplete(taskId: String, location: URL) {
        Task { @MainActor in
            guard var record = findRecord(id: taskId) else { return }

            let dir = downloadsDirectory(for: record.contentType)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let sanitized = sanitizeFileName(record.title)
            let fileName = "\(record.contentId)_\(sanitized)"
            let destination = dir.appendingPathComponent(fileName)

            try? FileManager.default.removeItem(at: destination)

            do {
                try FileManager.default.moveItem(at: location, to: destination)
                record.status = .completed
                record.localFileName = fileName
                record.downloadedAt = Date()

                let attrs = try? FileManager.default.attributesOfItem(atPath: destination.path)
                if let size = attrs?[.size] as? Int64, size > 0 {
                    record.fileSize = size
                }
                record.bytesDownloaded = record.fileSize
            } catch {
                record.status = .failed
                record.errorMessage = error.localizedDescription
            }

            db.update(record)
            downloadTasks.removeValue(forKey: taskId)
            refreshState()
        }
    }

    nonisolated func handleDownloadError(taskId: String, error: Error) {
        Task { @MainActor in
            if var record = findRecord(id: taskId) {
                record.status = .failed
                record.errorMessage = error.localizedDescription
                db.update(record)
            }
            downloadTasks.removeValue(forKey: taskId)
            refreshState()
        }
    }

    // MARK: - Private Helpers

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
        return name
            .components(separatedBy: allowed.inverted)
            .joined(separator: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}

// MARK: - URLSession Delegate

final class DownloadSessionDelegate: NSObject, URLSessionDownloadDelegate {
    weak var manager: DownloadManager?

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let taskId = downloadTask.taskDescription else { return }
        manager?.handleDownloadComplete(taskId: taskId, location: location)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let taskId = downloadTask.taskDescription else { return }
        manager?.handleDownloadProgress(taskId: taskId, bytesWritten: bytesWritten, totalBytesWritten: totalBytesWritten)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error, let taskId = task.taskDescription else { return }
        manager?.handleDownloadError(taskId: taskId, error: error)
    }
}
