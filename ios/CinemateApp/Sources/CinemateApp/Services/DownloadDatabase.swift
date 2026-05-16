import Foundation
import SQLite3

final class DownloadDatabase {
    private var db: OpaquePointer?

    private static var dbPath: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("cinemate_downloads.db")
    }

    init() {
        let path = Self.dbPath.path
        if sqlite3_open(path, &db) != SQLITE_OK {
            print("[DownloadDatabase] Failed to open database at \(path)")
            db = nil
            return
        }
        createTable()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    // MARK: - Schema

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS downloads (
            id TEXT PRIMARY KEY,
            content_type TEXT NOT NULL,
            content_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            subtitle TEXT,
            thumbnail_path TEXT,
            status TEXT NOT NULL DEFAULT 'queued',
            file_size INTEGER NOT NULL DEFAULT 0,
            bytes_downloaded INTEGER NOT NULL DEFAULT 0,
            local_file_name TEXT,
            downloaded_at REAL,
            error_message TEXT
        );
        """
        execute(sql)
    }

    // MARK: - CRUD

    func insert(_ record: DownloadRecord) {
        let sql = """
        INSERT OR REPLACE INTO downloads
            (id, content_type, content_id, title, subtitle, thumbnail_path,
             status, file_size, bytes_downloaded, local_file_name, downloaded_at, error_message)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            printError("insert prepare")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (record.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (record.contentType.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 3, Int32(record.contentId))
        sqlite3_bind_text(stmt, 4, (record.title as NSString).utf8String, -1, nil)
        bindOptionalText(stmt, index: 5, value: record.subtitle)
        bindOptionalText(stmt, index: 6, value: record.thumbnailPath)
        sqlite3_bind_text(stmt, 7, (record.status.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 8, record.fileSize)
        sqlite3_bind_int64(stmt, 9, record.bytesDownloaded)
        bindOptionalText(stmt, index: 10, value: record.localFileName)
        if let downloadedAt = record.downloadedAt {
            sqlite3_bind_double(stmt, 11, downloadedAt.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, 11)
        }
        bindOptionalText(stmt, index: 12, value: record.errorMessage)

        if sqlite3_step(stmt) != SQLITE_DONE {
            printError("insert step")
        }
    }

    func update(_ record: DownloadRecord) {
        insert(record)
    }

    func updateProgress(id: String, bytesDownloaded: Int64, status: DownloadStatus) {
        let sql = "UPDATE downloads SET bytes_downloaded = ?, status = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            printError("updateProgress prepare")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, bytesDownloaded)
        sqlite3_bind_text(stmt, 2, (status.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (id as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) != SQLITE_DONE {
            printError("updateProgress step")
        }
    }

    func delete(id: String) {
        let sql = "DELETE FROM downloads WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            printError("delete prepare")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) != SQLITE_DONE {
            printError("delete step")
        }
    }

    // MARK: - Queries

    func fetchAll() -> [DownloadRecord] {
        query("SELECT * FROM downloads ORDER BY downloaded_at DESC, title ASC;")
    }

    func fetch(contentType: DownloadContentType, contentId: Int) -> DownloadRecord? {
        let sql = "SELECT * FROM downloads WHERE content_type = ? AND content_id = ? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            printError("fetch prepare")
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (contentType.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(contentId))

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return recordFromStatement(stmt)
    }

    func fetchByStatus(_ status: DownloadStatus) -> [DownloadRecord] {
        let sql = "SELECT * FROM downloads WHERE status = ? ORDER BY title ASC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            printError("fetchByStatus prepare")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (status.rawValue as NSString).utf8String, -1, nil)

        var results: [DownloadRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(recordFromStatement(stmt))
        }
        return results
    }

    // MARK: - Helpers

    private func query(_ sql: String) -> [DownloadRecord] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            printError("query prepare")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var results: [DownloadRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(recordFromStatement(stmt))
        }
        return results
    }

    private func recordFromStatement(_ stmt: OpaquePointer?) -> DownloadRecord {
        let id = columnText(stmt, index: 0) ?? ""
        let contentTypeRaw = columnText(stmt, index: 1) ?? "media"
        let contentId = Int(sqlite3_column_int(stmt, 2))
        let title = columnText(stmt, index: 3) ?? ""
        let subtitle = columnText(stmt, index: 4)
        let thumbnailPath = columnText(stmt, index: 5)
        let statusRaw = columnText(stmt, index: 6) ?? "queued"
        let fileSize = sqlite3_column_int64(stmt, 7)
        let bytesDownloaded = sqlite3_column_int64(stmt, 8)
        let localFileName = columnText(stmt, index: 9)
        let downloadedAtRaw = sqlite3_column_type(stmt, 10) == SQLITE_NULL
            ? nil : sqlite3_column_double(stmt, 10)
        let errorMessage = columnText(stmt, index: 11)

        return DownloadRecord(
            id: id,
            contentType: DownloadContentType(rawValue: contentTypeRaw) ?? .media,
            contentId: contentId,
            title: title,
            subtitle: subtitle,
            thumbnailPath: thumbnailPath,
            status: DownloadStatus(rawValue: statusRaw) ?? .queued,
            fileSize: fileSize,
            bytesDownloaded: bytesDownloaded,
            localFileName: localFileName,
            downloadedAt: downloadedAtRaw.map { Date(timeIntervalSince1970: $0) },
            errorMessage: errorMessage
        )
    }

    private func columnText(_ stmt: OpaquePointer?, index: Int32) -> String? {
        guard let cStr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cStr)
    }

    private func bindOptionalText(_ stmt: OpaquePointer?, index: Int32, value: String?) {
        if let value {
            sqlite3_bind_text(stmt, index, (value as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func execute(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg {
                print("[DownloadDatabase] SQL error: \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
        }
    }

    private func printError(_ context: String) {
        if let db {
            let msg = String(cString: sqlite3_errmsg(db))
            print("[DownloadDatabase] \(context): \(msg)")
        }
    }
}
