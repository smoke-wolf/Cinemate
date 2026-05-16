import CryptoKit
import Foundation
import SwiftUI

actor ImageCacheService {
    static let shared = ImageCacheService()

    // MARK: - Configuration

    /// Maximum total size of the on-disk cache before the oldest files are evicted.
    private let maxDiskCacheSize: Int64 = 200 * 1024 * 1024 // 200 MB

    // MARK: - Storage

    private let memoryCache = NSCache<NSString, CacheEntry>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    // MARK: - Init

    private init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("CinemateImageCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    // MARK: - Public API

    /// Returns image data for `url`, consulting memory cache → disk cache → network in order.
    func image(for url: URL) async -> Data? {
        let key = url.absoluteString as NSString

        // 1. Memory cache (fastest — no I/O)
        if let entry = memoryCache.object(forKey: key) {
            return entry.data
        }

        // 2. Disk cache — uses a stable SHA256 filename so hits survive process restarts
        let fileURL = diskURL(for: url)
        if let data = await loadFromDisk(at: fileURL) {
            // Promote to memory cache so repeated access within a session stays fast
            let entry = CacheEntry(data: data)
            memoryCache.setObject(entry, forKey: key, cost: data.count)
            return data
        }

        // 3. Network fetch
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Persist to memory
            let entry = CacheEntry(data: data)
            memoryCache.setObject(entry, forKey: key, cost: data.count)

            // Persist to disk (fire-and-forget; errors are non-fatal)
            await saveToDisk(data, at: fileURL)

            return data
        } catch {
            return nil
        }
    }

    /// Wipes both the memory cache and the entire disk cache directory.
    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Returns the total byte size of the on-disk cache.
    /// (NSCache does not expose its current byte usage, so only disk size is reported.)
    func cacheSize() -> Int64 {
        return diskCacheSize()
    }

    // MARK: - Disk helpers

    /// Derives a stable filename from the URL using SHA256, avoiding Swift's randomised String.hash.
    private func diskURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent(hex)
    }

    /// Reads data from `fileURL` off the main thread and bumps the file's modification date so
    /// the LRU trimmer knows this file was recently accessed.
    private func loadFromDisk(at fileURL: URL) async -> Data? {
        return await Task.detached(priority: .utility) { [fileURL] () -> Data? in
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            // Touch the file so access time is updated for LRU eviction
            try? FileManager.default.setAttributes(
                [.modificationDate: Date()],
                ofItemAtPath: fileURL.path
            )
            return data
        }.value
    }

    /// Writes `data` to `fileURL` off the main thread, then trims the disk cache if needed.
    private func saveToDisk(_ data: Data, at fileURL: URL) async {
        await Task.detached(priority: .utility) { [data, fileURL] in
            try? data.write(to: fileURL, options: .atomic)
        }.value
        // Trim after every write so the cache never silently grows beyond the limit
        await trimDiskCacheIfNeeded()
    }

    // MARK: - Disk cache size

    private func diskCacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }

    // MARK: - Disk cache trimming

    /// Evicts the least-recently-used files until the total disk cache size is within
    /// `maxDiskCacheSize`. File modification date is used as the LRU proxy (updated on each
    /// cache read via `loadFromDisk`).
    private func trimDiskCacheIfNeeded() async {
        await Task.detached(priority: .background) { [cacheDirectory, maxDiskCacheSize] in
            let fm = FileManager.default
            let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]

            guard let enumerator = fm.enumerator(
                at: cacheDirectory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            ) else { return }

            // Build a list of (url, size, modDate) for every cached file
            var entries: [(url: URL, size: Int64, modDate: Date)] = []
            for case let fileURL as URL in enumerator {
                guard let values = try? fileURL.resourceValues(forKeys: resourceKeys),
                      let size = values.fileSize,
                      let modDate = values.contentModificationDate else { continue }
                entries.append((url: fileURL, size: Int64(size), modDate: modDate))
            }

            // Check whether we're within limits before touching anything
            let totalSize = entries.reduce(0) { $0 + $1.size }
            guard totalSize > maxDiskCacheSize else { return }

            // Sort oldest-first (LRU) and delete until we're back under the limit
            entries.sort { $0.modDate < $1.modDate }
            var runningSize = totalSize
            for entry in entries {
                guard runningSize > maxDiskCacheSize else { break }
                try? fm.removeItem(at: entry.url)
                runningSize -= entry.size
            }
        }.value
    }
}

// MARK: - Cache entry wrapper

final class CacheEntry: NSObject {
    let data: Data

    init(data: Data) {
        self.data = data
    }
}
