import Foundation
import SwiftUI

actor ImageCacheService {
    static let shared = ImageCacheService()

    private let memoryCache = NSCache<NSString, CacheEntry>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("CinemateImageCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func image(for url: URL) async -> Data? {
        let key = url.absoluteString as NSString

        // Check memory cache
        if let entry = memoryCache.object(forKey: key) {
            return entry.data
        }

        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent(url.absoluteString.hash.description)
        if let data = try? Data(contentsOf: fileURL) {
            let entry = CacheEntry(data: data)
            memoryCache.setObject(entry, forKey: key, cost: data.count)
            return data
        }

        // Download
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Save to memory
            let entry = CacheEntry(data: data)
            memoryCache.setObject(entry, forKey: key, cost: data.count)

            // Save to disk
            try? data.write(to: fileURL)

            return data
        } catch {
            return nil
        }
    }

    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

final class CacheEntry: NSObject {
    let data: Data

    init(data: Data) {
        self.data = data
    }
}
