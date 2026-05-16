import Foundation
import SwiftUI

// MARK: - Models

struct MacDownloadRecord: Identifiable, Hashable {
    let id: String
    let contentType: String
    let contentId: Int64
    let title: String
    let subtitle: String?
    var status: String
    let fileSize: Int64
    var bytesDownloaded: Int64
    var localFilePath: String?
    let serverURL: String?
    let sourcePath: String?
    let createdAt: Date
    var completedAt: Date?
    var errorMessage: String?

    var progress: Double {
        guard fileSize > 0 else { return 0 }
        return Double(bytesDownloaded) / Double(fileSize)
    }

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var bytesDownloadedFormatted: String {
        ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
    }

    var isActive: Bool {
        status == "queued" || status == "downloading"
    }

    var isPaused: Bool {
        status == "paused"
    }

    var isCompleted: Bool {
        status == "completed"
    }

    var isFailed: Bool {
        status == "failed"
    }

    var statusIcon: String {
        switch status {
        case "queued": return "clock"
        case "downloading": return "arrow.down.circle.fill"
        case "paused": return "pause.circle.fill"
        case "completed": return "checkmark.circle.fill"
        case "failed": return "exclamationmark.circle.fill"
        case "cancelled": return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }

    var statusColor: Color {
        switch status {
        case "queued": return .orange
        case "downloading": return .blue
        case "paused": return .yellow
        case "completed": return .green
        case "failed": return .red
        case "cancelled": return .gray
        default: return .gray
        }
    }
}

struct ConnectedDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let deviceType: String
    var accountId: Int64?
    var isOnline: Bool
    var lastSeen: Date

    var deviceIcon: String {
        switch deviceType.lowercased() {
        case "iphone": return "iphone"
        case "ipad": return "ipad"
        case "mac", "macos": return "desktopcomputer"
        case "appletv", "tvos": return "appletv"
        case "windows": return "pc"
        case "android": return "smartphone"
        case "web": return "globe"
        default: return "desktopcomputer"
        }
    }

    var lastSeenFormatted: String {
        let interval = Date().timeIntervalSince(lastSeen)
        if interval < 60 { return "Just now" }
        if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
        }
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
        let days = Int(interval / 86400)
        return "\(days)d ago"
    }
}

// MARK: - Download Manager

@MainActor
final class MacDownloadManager: ObservableObject {
    @Published var activeDownloads: [MacDownloadRecord] = []
    @Published var completedDownloads: [MacDownloadRecord] = []
    @Published var connectedDevices: [ConnectedDevice] = []
    @Published var downloadDirectory: URL

    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var copyTasks: [String: Task<Void, Never>] = [:]
    private var progressTimers: [String: Timer] = [:]
    private let session: URLSession

    init() {
        let moviesDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies")
            .appendingPathComponent("Cinemate Downloads")
        self.downloadDirectory = moviesDir

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600
        self.session = URLSession(configuration: config)

        ensureDownloadDirectory()
        loadFromDatabase()
    }

    // MARK: - Directory Management

    private func ensureDownloadDirectory() {
        try? FileManager.default.createDirectory(
            at: downloadDirectory,
            withIntermediateDirectories: true
        )
    }

    func setDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose download location"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            downloadDirectory = url
            ensureDownloadDirectory()
        }
    }

    // MARK: - Load From Database

    func loadFromDatabase() {
        let all = Database.shared.allDownloads()
        activeDownloads = all.filter { $0.isActive || $0.isPaused }
        completedDownloads = all.filter { $0.isCompleted }
        connectedDevices = Database.shared.allDevices()
    }

    // MARK: - Download from Server

    func downloadFromServer(
        contentType: String,
        contentId: Int64,
        title: String,
        subtitle: String? = nil,
        fileSize: Int64,
        serverURL: String,
        fileName: String
    ) {
        let recordId = UUID().uuidString

        Database.shared.insertDownload(
            id: recordId,
            contentType: contentType,
            contentId: contentId,
            title: title,
            subtitle: subtitle,
            fileSize: fileSize,
            serverURL: serverURL,
            sourcePath: nil
        )

        var record = MacDownloadRecord(
            id: recordId,
            contentType: contentType,
            contentId: contentId,
            title: title,
            subtitle: subtitle,
            status: "downloading",
            fileSize: fileSize,
            bytesDownloaded: 0,
            localFilePath: nil,
            serverURL: serverURL,
            sourcePath: nil,
            createdAt: Date(),
            completedAt: nil,
            errorMessage: nil
        )

        activeDownloads.insert(record, at: 0)
        Database.shared.updateDownloadStatus(id: recordId, status: "downloading")

        guard let url = URL(string: serverURL) else {
            failDownload(id: recordId, error: "Invalid server URL")
            return
        }

        let task = session.downloadTask(with: url) { [weak self] tempURL, response, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let error = error {
                    self.failDownload(id: recordId, error: error.localizedDescription)
                    return
                }

                guard let tempURL = tempURL else {
                    self.failDownload(id: recordId, error: "No data received")
                    return
                }

                let destURL = self.downloadDirectory.appendingPathComponent(fileName)
                do {
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destURL)

                    Database.shared.completeDownload(id: recordId, localFilePath: destURL.path)
                    record.status = "completed"
                    record.localFilePath = destURL.path
                    record.bytesDownloaded = fileSize
                    record.completedAt = Date()

                    self.activeDownloads.removeAll { $0.id == recordId }
                    self.completedDownloads.insert(record, at: 0)
                } catch {
                    self.failDownload(id: recordId, error: error.localizedDescription)
                }
            }
        }

        downloadTasks[recordId] = task

        // Observe progress
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self, weak task] _ in
            guard let task = task else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let received = task.countOfBytesReceived
                if received > 0 {
                    Database.shared.updateDownloadProgress(id: recordId, bytesDownloaded: received)
                    if let idx = self.activeDownloads.firstIndex(where: { $0.id == recordId }) {
                        self.activeDownloads[idx].bytesDownloaded = received
                    }
                }
            }
        }
        progressTimers[recordId] = timer

        task.resume()
    }

    // MARK: - Copy from Drive

    func copyFromDrive(sourcePath: String, destinationName: String, title: String, contentId: Int64 = 0) {
        let recordId = UUID().uuidString
        let sourceURL = URL(fileURLWithPath: sourcePath)

        let fileSize: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: sourcePath),
           let size = attrs[.size] as? Int64 {
            fileSize = size
        } else {
            fileSize = 0
        }

        Database.shared.insertDownload(
            id: recordId,
            contentType: "file",
            contentId: contentId,
            title: title,
            subtitle: nil,
            fileSize: fileSize,
            serverURL: nil,
            sourcePath: sourcePath
        )

        let record = MacDownloadRecord(
            id: recordId,
            contentType: "file",
            contentId: contentId,
            title: title,
            subtitle: nil,
            status: "downloading",
            fileSize: fileSize,
            bytesDownloaded: 0,
            localFilePath: nil,
            serverURL: nil,
            sourcePath: sourcePath,
            createdAt: Date(),
            completedAt: nil,
            errorMessage: nil
        )

        activeDownloads.insert(record, at: 0)
        Database.shared.updateDownloadStatus(id: recordId, status: "downloading")

        let destURL = downloadDirectory.appendingPathComponent(destinationName)

        let task = Task { [weak self] in
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }

                // Copy in chunks for progress reporting
                let inputHandle = try FileHandle(forReadingFrom: sourceURL)
                FileManager.default.createFile(atPath: destURL.path, contents: nil)
                let outputHandle = try FileHandle(forWritingTo: destURL)

                let chunkSize = 1024 * 1024 // 1MB chunks
                var totalCopied: Int64 = 0

                while true {
                    let data = inputHandle.readData(ofLength: chunkSize)
                    if data.isEmpty { break }
                    outputHandle.write(data)
                    totalCopied += Int64(data.count)

                    await MainActor.run { [weak self, totalCopied] in
                        guard let self = self else { return }
                        Database.shared.updateDownloadProgress(id: recordId, bytesDownloaded: totalCopied)
                        if let idx = self.activeDownloads.firstIndex(where: { $0.id == recordId }) {
                            self.activeDownloads[idx].bytesDownloaded = totalCopied
                        }
                    }

                    if Task.isCancelled { break }
                }

                inputHandle.closeFile()
                outputHandle.closeFile()

                if Task.isCancelled {
                    try? FileManager.default.removeItem(at: destURL)
                    await MainActor.run { [weak self] in
                        self?.activeDownloads.removeAll { $0.id == recordId }
                        Database.shared.updateDownloadStatus(id: recordId, status: "cancelled")
                    }
                    return
                }

                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    Database.shared.completeDownload(id: recordId, localFilePath: destURL.path)
                    self.activeDownloads.removeAll { $0.id == recordId }
                    var completed = record
                    completed.status = "completed"
                    completed.localFilePath = destURL.path
                    completed.bytesDownloaded = fileSize
                    completed.completedAt = Date()
                    self.completedDownloads.insert(completed, at: 0)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.failDownload(id: recordId, error: error.localizedDescription)
                }
            }
        }
        copyTasks[recordId] = task
    }

    // MARK: - Pause / Resume / Cancel

    func pauseDownload(id: String) {
        downloadTasks[id]?.suspend()
        progressTimers[id]?.invalidate()
        Database.shared.updateDownloadStatus(id: id, status: "paused")
        if let idx = activeDownloads.firstIndex(where: { $0.id == id }) {
            activeDownloads[idx].status = "paused"
        }
    }

    func resumeDownload(id: String) {
        downloadTasks[id]?.resume()
        Database.shared.updateDownloadStatus(id: id, status: "downloading")
        if let idx = activeDownloads.firstIndex(where: { $0.id == id }) {
            activeDownloads[idx].status = "downloading"
        }

        // Restart progress timer
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let task = self?.downloadTasks[id] else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let received = task.countOfBytesReceived
                if received > 0 {
                    Database.shared.updateDownloadProgress(id: id, bytesDownloaded: received)
                    if let idx = self.activeDownloads.firstIndex(where: { $0.id == id }) {
                        self.activeDownloads[idx].bytesDownloaded = received
                    }
                }
            }
        }
        progressTimers[id] = timer
    }

    func cancelDownload(id: String) {
        downloadTasks[id]?.cancel()
        downloadTasks.removeValue(forKey: id)
        progressTimers[id]?.invalidate()
        progressTimers.removeValue(forKey: id)
        copyTasks[id]?.cancel()
        copyTasks.removeValue(forKey: id)

        Database.shared.updateDownloadStatus(id: id, status: "cancelled")
        activeDownloads.removeAll { $0.id == id }
    }

    func deleteDownloadRecord(id: String) {
        // Remove file if exists
        if let record = completedDownloads.first(where: { $0.id == id }),
           let path = record.localFilePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        Database.shared.deleteDownload(id: id)
        completedDownloads.removeAll { $0.id == id }
        activeDownloads.removeAll { $0.id == id }
    }

    func retryDownload(id: String) {
        guard let record = activeDownloads.first(where: { $0.id == id }) ?? completedDownloads.first(where: { $0.id == id }) else {
            return
        }
        deleteDownloadRecord(id: id)

        if let serverURL = record.serverURL {
            let fileName = URL(string: serverURL)?.lastPathComponent ?? "\(record.title).mp4"
            downloadFromServer(
                contentType: record.contentType,
                contentId: record.contentId,
                title: record.title,
                subtitle: record.subtitle,
                fileSize: record.fileSize,
                serverURL: serverURL,
                fileName: fileName
            )
        } else if let sourcePath = record.sourcePath {
            let fileName = URL(fileURLWithPath: sourcePath).lastPathComponent
            copyFromDrive(
                sourcePath: sourcePath,
                destinationName: fileName,
                title: record.title,
                contentId: record.contentId
            )
        }
    }

    func clearCompleted() {
        for record in completedDownloads {
            Database.shared.deleteDownload(id: record.id)
        }
        completedDownloads.removeAll()
    }

    func revealInFinder(path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    // MARK: - Device Management

    func refreshDevices(serverURL: String) {
        guard let url = URL(string: "\(serverURL)/api/sync/devices") else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let wrapper = try? JSONDecoder().decode(DeviceListResponse.self, from: data) {
                    let devices = wrapper.devices
                    Database.shared.markAllDevicesOffline()
                    for device in devices {
                        Database.shared.upsertDevice(
                            id: device.id,
                            name: device.name,
                            deviceType: device.device_type,
                            accountId: device.account_id,
                            isOnline: device.is_online
                        )
                    }
                    connectedDevices = Database.shared.allDevices()
                }
            } catch {
                // Silently handle network errors for device refresh
                connectedDevices = Database.shared.allDevices()
            }
        }
    }

    // MARK: - Private Helpers

    private func failDownload(id: String, error: String) {
        Database.shared.failDownload(id: id, error: error)
        progressTimers[id]?.invalidate()
        progressTimers.removeValue(forKey: id)
        downloadTasks.removeValue(forKey: id)
        if let idx = activeDownloads.firstIndex(where: { $0.id == id }) {
            activeDownloads[idx].status = "failed"
            activeDownloads[idx].errorMessage = error
        }
    }
}

// MARK: - API Response Model

private struct DeviceListResponse: Codable {
    let devices: [DeviceAPIResponse]
    let total: Int?
}

private struct DeviceAPIResponse: Codable {
    let id: String
    let name: String
    let device_type: String
    let account_id: Int64?
    let is_online: Bool
}
