import Foundation

enum DownloadStatus: String, Codable {
    case queued, downloading, paused, completed, failed, cancelled
}

enum DownloadContentType: String, Codable {
    case media, musicTrack = "music_track", book
}

struct DownloadRecord: Identifiable, Codable {
    let id: String
    let contentType: DownloadContentType
    let contentId: Int
    let title: String
    let subtitle: String?
    let thumbnailPath: String?
    var status: DownloadStatus
    var fileSize: Int64
    var bytesDownloaded: Int64
    var localFileName: String?
    var downloadedAt: Date?
    var errorMessage: String?

    var progress: Double {
        guard fileSize > 0 else { return 0 }
        return Double(bytesDownloaded) / Double(fileSize)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case contentType = "content_type"
        case contentId = "content_id"
        case title
        case subtitle
        case thumbnailPath = "thumbnail_path"
        case status
        case fileSize = "file_size"
        case bytesDownloaded = "bytes_downloaded"
        case localFileName = "local_file_name"
        case downloadedAt = "downloaded_at"
        case errorMessage = "error_message"
    }
}

struct DownloadJobResponse: Codable {
    let jobId: String
    let contentType: String
    let contentId: Int
    let status: String
    let fileName: String?
    let fileSize: Int64?
    let downloadURL: String?

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case contentType = "content_type"
        case contentId = "content_id"
        case status
        case fileName = "file_name"
        case fileSize = "file_size"
        case downloadURL = "download_url"
    }
}

struct DownloadJobsResponse: Codable {
    let jobs: [DownloadJobResponse]
    let total: Int
}
