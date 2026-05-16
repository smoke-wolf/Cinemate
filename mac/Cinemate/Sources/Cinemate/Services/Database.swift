import Foundation
import SQLite
import CommonCrypto
import AppKit

struct TimestampComment: Identifiable {
    let id: Int64
    let mediaId: Int64
    let timestamp: Double
    let text: String
    let createdAt: Date

    var timestampFormatted: String {
        let total = Int(timestamp)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

final class Database {
    static let shared = Database()

    private let db: Connection
    private let media = Table("media")
    private let commentsTable = Table("comments")
    private let accountsTable = Table("accounts")
    private let accountMediaTable = Table("account_media")

    private let colId = SQLite.Expression<Int64>("id")
    private let colTitle = SQLite.Expression<String>("title")
    private let colYear = SQLite.Expression<Int?>("year")
    private let colFilePath = SQLite.Expression<String>("file_path")
    private let colFileSize = SQLite.Expression<Int64>("file_size")
    private let colFormat = SQLite.Expression<String>("format")
    private let colGenre = SQLite.Expression<String?>("genre")
    private let colRating = SQLite.Expression<Int?>("rating")
    private let colQuality = SQLite.Expression<String?>("quality")
    private let colDescription = SQLite.Expression<String?>("description")
    private let colThumbnailPath = SQLite.Expression<String?>("thumbnail_path")
    private let colLastPlayed = SQLite.Expression<Double?>("last_played")
    private let colPlayCount = SQLite.Expression<Int>("play_count")
    private let colFavorite = SQLite.Expression<Bool>("favorite")
    private let colWatched = SQLite.Expression<Bool>("watched")
    private let colWatchProgress = SQLite.Expression<Double>("watch_progress")
    private let colDuration = SQLite.Expression<Double>("duration")
    private let colDateAdded = SQLite.Expression<Double>("date_added")
    private let colMediaType = SQLite.Expression<String>("media_type")
    private let colShowName = SQLite.Expression<String?>("show_name")
    private let colSeasonNumber = SQLite.Expression<Int?>("season_number")
    private let colEpisodeNumber = SQLite.Expression<Int?>("episode_number")
    private let colTotalWatchTime = SQLite.Expression<Double>("total_watch_time")

    // Comments table columns
    private let colCommentId = SQLite.Expression<Int64>("id")
    private let colCommentMediaId = SQLite.Expression<Int64>("media_id")
    private let colCommentTimestamp = SQLite.Expression<Double>("timestamp")
    private let colCommentText = SQLite.Expression<String>("text")
    private let colCommentCreatedAt = SQLite.Expression<Double>("created_at")

    // Accounts table columns
    private let colAccountId = SQLite.Expression<Int64>("id")
    private let colAccountName = SQLite.Expression<String>("name")
    private let colAvatarColor = SQLite.Expression<String>("avatar_color")
    private let colPinHash = SQLite.Expression<String?>("pin_hash")
    private let colAccountCreatedAt = SQLite.Expression<Double>("created_at")

    // Account media table columns
    private let colAMAccountId = SQLite.Expression<Int64>("account_id")
    private let colAMMediaId = SQLite.Expression<Int64>("media_id")
    private let colAMFavorite = SQLite.Expression<Bool>("favorite")
    private let colAMWatched = SQLite.Expression<Bool>("watched")
    private let colAMWatchProgress = SQLite.Expression<Double>("watch_progress")
    private let colAMPlayCount = SQLite.Expression<Int>("play_count")
    private let colAMLastPlayed = SQLite.Expression<Double?>("last_played")
    private let colAMTotalWatchTime = SQLite.Expression<Double>("total_watch_time")
    private let colAMRating = SQLite.Expression<Int?>("rating")

    // Downloads table
    private let downloadsTable = Table("downloads")
    private let colDlId = SQLite.Expression<String>("id")
    private let colDlContentType = SQLite.Expression<String>("content_type")
    private let colDlContentId = SQLite.Expression<Int64>("content_id")
    private let colDlTitle = SQLite.Expression<String>("title")
    private let colDlSubtitle = SQLite.Expression<String?>("subtitle")
    private let colDlStatus = SQLite.Expression<String>("status")
    private let colDlFileSize = SQLite.Expression<Int64>("file_size")
    private let colDlBytesDownloaded = SQLite.Expression<Int64>("bytes_downloaded")
    private let colDlLocalFilePath = SQLite.Expression<String?>("local_file_path")
    private let colDlServerURL = SQLite.Expression<String?>("server_url")
    private let colDlSourcePath = SQLite.Expression<String?>("source_path")
    private let colDlCreatedAt = SQLite.Expression<Double>("created_at")
    private let colDlCompletedAt = SQLite.Expression<Double?>("completed_at")
    private let colDlErrorMessage = SQLite.Expression<String?>("error_message")

    // Known devices table
    private let knownDevicesTable = Table("known_devices")
    private let colDevId = SQLite.Expression<String>("id")
    private let colDevName = SQLite.Expression<String>("name")
    private let colDevType = SQLite.Expression<String>("device_type")
    private let colDevAccountId = SQLite.Expression<Int64?>("account_id")
    private let colDevIsOnline = SQLite.Expression<Bool>("is_online")
    private let colDevLastSeen = SQLite.Expression<Double>("last_seen")

    // Artist profile cache table
    private let artistProfilesTable = Table("artist_profiles")
    private let colApName = SQLite.Expression<String>("name")
    private let colApBio = SQLite.Expression<String?>("bio")
    private let colApImagePath = SQLite.Expression<String?>("image_path")
    private let colApGenres = SQLite.Expression<String>("genres") // JSON array
    private let colApPopularity = SQLite.Expression<Int?>("popularity")
    private let colApFollowers = SQLite.Expression<Int?>("followers")
    private let colApWikipediaURL = SQLite.Expression<String?>("wikipedia_url")
    private let colApCachedAt = SQLite.Expression<Double>("cached_at")

    private init() {
        let dbDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cinemate", isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath = dbDir.appendingPathComponent("library.db").path
        db = try! Connection(dbPath)
        try! db.execute("PRAGMA journal_mode = WAL")
        createTable()
        migrate()
    }

    private func createTable() {
        try! db.run(media.create(ifNotExists: true) { t in
            t.column(colId, primaryKey: .autoincrement)
            t.column(colTitle)
            t.column(colYear)
            t.column(colFilePath, unique: true)
            t.column(colFileSize)
            t.column(colFormat)
            t.column(colGenre)
            t.column(colRating)
            t.column(colQuality)
            t.column(colDescription)
            t.column(colThumbnailPath)
            t.column(colLastPlayed)
            t.column(colPlayCount, defaultValue: 0)
            t.column(colFavorite, defaultValue: false)
            t.column(colWatched, defaultValue: false)
            t.column(colWatchProgress, defaultValue: 0)
            t.column(colDuration, defaultValue: 0)
            t.column(colDateAdded)
            t.column(colMediaType, defaultValue: MediaType.movie.rawValue)
            t.column(colShowName)
            t.column(colSeasonNumber)
            t.column(colEpisodeNumber)
            t.column(colTotalWatchTime, defaultValue: 0)
        })
        try? db.run(media.createIndex(colTitle, ifNotExists: true))
        try? db.run(media.createIndex(colMediaType, ifNotExists: true))
        try? db.run(media.createIndex(colShowName, ifNotExists: true))

        // Comments table
        try! db.run(commentsTable.create(ifNotExists: true) { t in
            t.column(colCommentId, primaryKey: .autoincrement)
            t.column(colCommentMediaId, references: media, colId)
            t.column(colCommentTimestamp)
            t.column(colCommentText)
            t.column(colCommentCreatedAt)
        })
        try? db.run(commentsTable.createIndex(colCommentMediaId, ifNotExists: true))
        try? db.run(commentsTable.createIndex(colCommentTimestamp, ifNotExists: true))

        // Accounts table
        try! db.run(accountsTable.create(ifNotExists: true) { t in
            t.column(colAccountId, primaryKey: .autoincrement)
            t.column(colAccountName)
            t.column(colAvatarColor)
            t.column(colPinHash)
            t.column(colAccountCreatedAt)
        })

        // Account-media join table
        try! db.run(accountMediaTable.create(ifNotExists: true) { t in
            t.column(colAMAccountId)
            t.column(colAMMediaId)
            t.column(colAMFavorite, defaultValue: false)
            t.column(colAMWatched, defaultValue: false)
            t.column(colAMWatchProgress, defaultValue: 0)
            t.column(colAMPlayCount, defaultValue: 0)
            t.column(colAMLastPlayed)
            t.column(colAMTotalWatchTime, defaultValue: 0)
            t.column(colAMRating)
            t.primaryKey(colAMAccountId, colAMMediaId)
        })

        // Downloads tracking table
        try! db.run(downloadsTable.create(ifNotExists: true) { t in
            t.column(colDlId, primaryKey: true)
            t.column(colDlContentType)
            t.column(colDlContentId)
            t.column(colDlTitle)
            t.column(colDlSubtitle)
            t.column(colDlStatus, defaultValue: "queued")
            t.column(colDlFileSize, defaultValue: 0)
            t.column(colDlBytesDownloaded, defaultValue: 0)
            t.column(colDlLocalFilePath)
            t.column(colDlServerURL)
            t.column(colDlSourcePath)
            t.column(colDlCreatedAt)
            t.column(colDlCompletedAt)
            t.column(colDlErrorMessage)
        })
        try? db.run(downloadsTable.createIndex(colDlStatus, ifNotExists: true))
        try? db.run(downloadsTable.createIndex(colDlCreatedAt, ifNotExists: true))

        // Known devices cache
        try! db.run(knownDevicesTable.create(ifNotExists: true) { t in
            t.column(colDevId, primaryKey: true)
            t.column(colDevName)
            t.column(colDevType)
            t.column(colDevAccountId)
            t.column(colDevIsOnline, defaultValue: false)
            t.column(colDevLastSeen)
        })

        // Artist profile cache
        try! db.run(artistProfilesTable.create(ifNotExists: true) { t in
            t.column(colApName, primaryKey: true)
            t.column(colApBio)
            t.column(colApImagePath)
            t.column(colApGenres, defaultValue: "[]")
            t.column(colApPopularity)
            t.column(colApFollowers)
            t.column(colApWikipediaURL)
            t.column(colApCachedAt)
        })
    }

    private func migrate() {
        try? db.run("ALTER TABLE media ADD COLUMN description TEXT")
        try? db.run("ALTER TABLE media ADD COLUMN watched INTEGER NOT NULL DEFAULT 0")
        try? db.run("ALTER TABLE media ADD COLUMN watch_progress REAL NOT NULL DEFAULT 0")
        try? db.run("ALTER TABLE media ADD COLUMN duration REAL NOT NULL DEFAULT 0")
        try? db.run("ALTER TABLE media ADD COLUMN rating INTEGER")
        try? db.run("ALTER TABLE media ADD COLUMN quality TEXT")

        try? db.run("ALTER TABLE media ADD COLUMN total_watch_time REAL NOT NULL DEFAULT 0")

        // Drop old movies table
        let old = (try? db.scalar("SELECT count(*) FROM sqlite_master WHERE type='table' AND name='movies'") as? Int64) ?? 0
        if old > 0 { try? db.execute("DROP TABLE IF EXISTS movies") }
    }

    // MARK: - PIN Hashing

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Account Methods

    @discardableResult
    func createAccount(name: String, avatarColor: String, pin: String? = nil) -> Account {
        let pinHash = pin.map { sha256($0) }
        let now = Date().timeIntervalSince1970
        let rowId = try! db.run(accountsTable.insert(
            colAccountName <- name,
            colAvatarColor <- avatarColor,
            colPinHash <- pinHash,
            colAccountCreatedAt <- now
        ))
        return Account(
            id: rowId,
            name: name,
            avatarColor: avatarColor,
            hasPin: pinHash != nil,
            createdAt: Date(timeIntervalSince1970: now)
        )
    }

    func allAccounts() -> [Account] {
        guard let rows = try? db.prepare(accountsTable.order(colAccountCreatedAt.asc)) else { return [] }
        return rows.map { row in
            Account(
                id: row[colAccountId],
                name: row[colAccountName],
                avatarColor: row[colAvatarColor],
                hasPin: row[colPinHash] != nil,
                createdAt: Date(timeIntervalSince1970: row[colAccountCreatedAt])
            )
        }
    }

    func deleteAccount(id: Int64) {
        try? db.run(accountsTable.filter(colAccountId == id).delete())
        try? db.run(accountMediaTable.filter(colAMAccountId == id).delete())
    }

    func updateAccount(id: Int64, name: String, avatarColor: String) {
        try? db.run(accountsTable.filter(colAccountId == id).update(
            colAccountName <- name,
            colAvatarColor <- avatarColor
        ))
    }

    func verifyPin(accountId: Int64, pin: String) -> Bool {
        guard let row = try? db.pluck(accountsTable.filter(colAccountId == accountId)) else { return false }
        guard let storedHash = row[colPinHash] else { return true }
        return sha256(pin) == storedHash
    }

    func getAccount(id: Int64) -> Account? {
        guard let row = try? db.pluck(accountsTable.filter(colAccountId == id)) else { return nil }
        return Account(
            id: row[colAccountId],
            name: row[colAccountName],
            avatarColor: row[colAvatarColor],
            hasPin: row[colPinHash] != nil,
            createdAt: Date(timeIntervalSince1970: row[colAccountCreatedAt])
        )
    }

    // MARK: - Account-Media Helpers

    private func ensureAccountMedia(accountId: Int64, mediaId: Int64) {
        let row = accountMediaTable.filter(colAMAccountId == accountId && colAMMediaId == mediaId)
        if (try? db.pluck(row)) == nil {
            try? db.run(accountMediaTable.insert(
                colAMAccountId <- accountId,
                colAMMediaId <- mediaId
            ))
        }
    }

    // MARK: - Account-Aware Mutations

    func toggleFavorite(movieId: Int64, accountId: Int64? = nil) {
        if let aid = accountId {
            ensureAccountMedia(accountId: aid, mediaId: movieId)
            let row = accountMediaTable.filter(colAMAccountId == aid && colAMMediaId == movieId)
            if let existing = try? db.pluck(row) {
                try? db.run(row.update(colAMFavorite <- !existing[colAMFavorite]))
            }
        } else {
            let item = media.filter(colId == movieId)
            if let row = try? db.pluck(item) {
                try? db.run(item.update(colFavorite <- !row[colFavorite]))
            }
        }
    }

    func toggleWatched(movieId: Int64, accountId: Int64? = nil) {
        if let aid = accountId {
            ensureAccountMedia(accountId: aid, mediaId: movieId)
            let row = accountMediaTable.filter(colAMAccountId == aid && colAMMediaId == movieId)
            if let existing = try? db.pluck(row) {
                let newWatched = !existing[colAMWatched]
                // We need the media duration from the media table
                let dur: Double
                if let mediaRow = try? db.pluck(media.filter(colId == movieId)) {
                    dur = mediaRow[colDuration]
                } else {
                    dur = 0
                }
                try? db.run(row.update(
                    colAMWatched <- newWatched,
                    colAMWatchProgress <- newWatched ? dur : 0
                ))
            }
        } else {
            let item = media.filter(colId == movieId)
            if let row = try? db.pluck(item) {
                let newWatched = !row[colWatched]
                try? db.run(item.update(
                    colWatched <- newWatched,
                    colWatchProgress <- newWatched ? row[colDuration] : 0
                ))
            }
        }
    }

    func updateProgress(movieId: Int64, progress: Double, accountId: Int64? = nil) {
        if let aid = accountId {
            ensureAccountMedia(accountId: aid, mediaId: movieId)
            let row = accountMediaTable.filter(colAMAccountId == aid && colAMMediaId == movieId)
            try? db.run(row.update(
                colAMWatchProgress <- progress,
                colAMLastPlayed <- Date().timeIntervalSince1970
            ))
        } else {
            let item = media.filter(colId == movieId)
            try? db.run(item.update(
                colWatchProgress <- progress,
                colLastPlayed <- Date().timeIntervalSince1970
            ))
        }
    }

    func updateDuration(movieId: Int64, duration: Double) {
        try? db.run(media.filter(colId == movieId).update(colDuration <- duration))
    }

    func markWatched(movieId: Int64, accountId: Int64? = nil) {
        if let aid = accountId {
            ensureAccountMedia(accountId: aid, mediaId: movieId)
            let row = accountMediaTable.filter(colAMAccountId == aid && colAMMediaId == movieId)
            try? db.run(row.update(colAMWatched <- true))
        } else {
            try? db.run(media.filter(colId == movieId).update(colWatched <- true))
        }
    }

    func markPlayed(movieId: Int64, accountId: Int64? = nil) {
        if let aid = accountId {
            ensureAccountMedia(accountId: aid, mediaId: movieId)
            let row = accountMediaTable.filter(colAMAccountId == aid && colAMMediaId == movieId)
            if let existing = try? db.pluck(row) {
                try? db.run(row.update(
                    colAMLastPlayed <- Date().timeIntervalSince1970,
                    colAMPlayCount <- existing[colAMPlayCount] + 1
                ))
            }
        } else {
            let item = media.filter(colId == movieId)
            if let row = try? db.pluck(item) {
                try? db.run(item.update(
                    colLastPlayed <- Date().timeIntervalSince1970,
                    colPlayCount <- row[colPlayCount] + 1
                ))
            }
        }
    }

    func addWatchTime(movieId: Int64, seconds: Double, accountId: Int64? = nil) {
        guard seconds > 0 else { return }
        if let aid = accountId {
            ensureAccountMedia(accountId: aid, mediaId: movieId)
            let row = accountMediaTable.filter(colAMAccountId == aid && colAMMediaId == movieId)
            if let existing = try? db.pluck(row) {
                try? db.run(row.update(colAMTotalWatchTime <- existing[colAMTotalWatchTime] + seconds))
            }
        } else {
            let item = media.filter(colId == movieId)
            if let row = try? db.pluck(item) {
                try? db.run(item.update(colTotalWatchTime <- row[colTotalWatchTime] + seconds))
            }
        }
    }

    // MARK: - Media Item Building

    private func mediaItem(from row: Row) -> MediaItem {
        MediaItem(
            id: row[colId],
            title: row[colTitle],
            year: row[colYear],
            filePath: row[colFilePath],
            fileSize: row[colFileSize],
            format: row[colFormat],
            genre: row[colGenre],
            rating: row[colRating],
            quality: row[colQuality],
            description_: row[colDescription],
            thumbnailPath: row[colThumbnailPath],
            lastPlayed: row[colLastPlayed].map { Date(timeIntervalSince1970: $0) },
            playCount: row[colPlayCount],
            favorite: row[colFavorite],
            watched: row[colWatched],
            watchProgress: row[colWatchProgress],
            duration: row[colDuration],
            dateAdded: Date(timeIntervalSince1970: row[colDateAdded]),
            mediaType: MediaType(rawValue: row[colMediaType]) ?? .movie,
            showName: row[colShowName],
            seasonNumber: row[colSeasonNumber],
            episodeNumber: row[colEpisodeNumber],
            totalWatchTime: row[colTotalWatchTime]
        )
    }

    /// Build a MediaItem from media row, overlaying account-specific state from account_media.
    private func mediaItemWithAccount(mediaRow: Row, accountId: Int64) -> MediaItem {
        var item = mediaItem(from: mediaRow)
        let amRow = try? db.pluck(
            accountMediaTable.filter(colAMAccountId == accountId && colAMMediaId == item.id)
        )
        if let am = amRow {
            item.favorite = am[colAMFavorite]
            item.watched = am[colAMWatched]
            item.watchProgress = am[colAMWatchProgress]
            item.playCount = am[colAMPlayCount]
            item.lastPlayed = am[colAMLastPlayed].map { Date(timeIntervalSince1970: $0) }
            item.totalWatchTime = am[colAMTotalWatchTime]
        } else {
            // No account_media row yet: defaults
            item.favorite = false
            item.watched = false
            item.watchProgress = 0
            item.playCount = 0
            item.lastPlayed = nil
            item.totalWatchTime = 0
        }
        return item
    }

    private func applySorting(_ query: Table, sortBy: SortOption) -> Table {
        switch sortBy {
        case .title: return query.order(colTitle.asc)
        case .year: return query.order(colYear.desc, colTitle.asc)
        case .dateAdded: return query.order(colDateAdded.desc)
        case .lastPlayed: return query.order(colLastPlayed.desc)
        case .fileSize: return query.order(colFileSize.desc)
        }
    }

    // MARK: - Insert

    func insertMedia(
        title: String, year: Int?, filePath: String, fileSize: Int64, format: String,
        quality: String? = nil, mediaType: MediaType, showName: String? = nil, seasonNumber: Int? = nil, episodeNumber: Int? = nil
    ) throws {
        let existing = try db.pluck(media.filter(colFilePath == filePath))
        if existing != nil { return }

        let lookupKey = (mediaType == .tvEpisode) ? (showName ?? title) : title
        let desc = MovieDescriptions.lookup(lookupKey)
        let genre = MovieDescriptions.genreLookup(lookupKey)
        let rating = MovieDescriptions.ratingLookup(lookupKey)

        try db.run(media.insert(
            colTitle <- title,
            colYear <- year,
            colFilePath <- filePath,
            colFileSize <- fileSize,
            colFormat <- format,
            colGenre <- genre,
            colRating <- rating,
            colQuality <- quality,
            colDescription <- desc,
            colMediaType <- mediaType.rawValue,
            colShowName <- showName,
            colSeasonNumber <- seasonNumber,
            colEpisodeNumber <- episodeNumber,
            colDateAdded <- Date().timeIntervalSince1970
        ))
    }

    // MARK: - Queries (Account-Aware)

    func allMovies(sortBy: SortOption = .title, searchQuery: String = "", accountId: Int64? = nil) -> [MediaItem] {
        var query = media.filter(colMediaType == MediaType.movie.rawValue)
        if !searchQuery.isEmpty {
            query = query.filter(colTitle.like("%\(searchQuery)%"))
        }
        guard let rows = try? db.prepare(applySorting(query, sortBy: sortBy)) else { return [] }
        if let aid = accountId {
            return rows.map { mediaItemWithAccount(mediaRow: $0, accountId: aid) }
        }
        return rows.map(mediaItem)
    }

    func allMedia(sortBy: SortOption = .title, searchQuery: String = "", accountId: Int64? = nil) -> [MediaItem] {
        var query = media as Table
        if !searchQuery.isEmpty {
            let p = "%\(searchQuery)%"
            query = query.filter(colTitle.like(p) || colShowName.like(p))
        }
        guard let rows = try? db.prepare(applySorting(query, sortBy: sortBy)) else { return [] }
        if let aid = accountId {
            return rows.map { mediaItemWithAccount(mediaRow: $0, accountId: aid) }
        }
        return rows.map(mediaItem)
    }

    func allShows(accountId: Int64? = nil) -> [TVShow] {
        let query = media.filter(colMediaType == MediaType.tvEpisode.rawValue)
            .order(colShowName.asc, colSeasonNumber.asc, colEpisodeNumber.asc)
        guard let rows = try? db.prepare(query) else { return [] }

        var showMap: [String: TVShow] = [:]
        for row in rows {
            let item: MediaItem
            if let aid = accountId {
                item = mediaItemWithAccount(mediaRow: row, accountId: aid)
            } else {
                item = mediaItem(from: row)
            }
            let name = item.showName ?? "Unknown Show"
            let season = item.seasonNumber ?? 0

            if showMap[name] == nil {
                showMap[name] = TVShow(name: name, year: item.year, seasons: [:], thumbnailPath: item.thumbnailPath,
                                      description_: MovieDescriptions.lookup(name))
            }
            showMap[name]!.seasons[season, default: []].append(item)
            if let y = item.year, showMap[name]!.year == nil || y < (showMap[name]!.year ?? Int.max) {
                showMap[name]!.year = y
            }
            if showMap[name]!.thumbnailPath == nil, let t = item.thumbnailPath {
                showMap[name]!.thumbnailPath = t
            }
        }
        return showMap.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func episodes(forShow showName: String, season: Int? = nil) -> [MediaItem] {
        var query = media.filter(colMediaType == MediaType.tvEpisode.rawValue && colShowName == showName)
        if let s = season { query = query.filter(colSeasonNumber == s) }
        return (try? db.prepare(query.order(colSeasonNumber.asc, colEpisodeNumber.asc)).map(mediaItem)) ?? []
    }

    func moviesByGenre(accountId: Int64? = nil) -> [(String, [MediaItem])] {
        let query = media.filter(colMediaType == MediaType.movie.rawValue && colGenre != nil)
            .order(colTitle.asc)
        guard let rows = try? db.prepare(query) else { return [] }
        var genreMap: [String: [MediaItem]] = [:]
        for row in rows {
            let item: MediaItem
            if let aid = accountId {
                item = mediaItemWithAccount(mediaRow: row, accountId: aid)
            } else {
                item = mediaItem(from: row)
            }
            if let g = item.genre, !g.isEmpty {
                genreMap[g, default: []].append(item)
            }
        }
        return genreMap.sorted { $0.value.count > $1.value.count }
    }

    func favorites(accountId: Int64? = nil) -> [MediaItem] {
        if let aid = accountId {
            // Join account_media with media where favorite=true
            let amFavs = accountMediaTable.filter(colAMAccountId == aid && colAMFavorite == true)
            guard let amRows = try? db.prepare(amFavs) else { return [] }
            var result: [MediaItem] = []
            for amRow in amRows {
                let mid = amRow[colAMMediaId]
                if let mediaRow = try? db.pluck(media.filter(colId == mid)) {
                    result.append(mediaItemWithAccount(mediaRow: mediaRow, accountId: aid))
                }
            }
            return result.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return (try? db.prepare(media.filter(colFavorite == true).order(colTitle.asc)).map(mediaItem)) ?? []
    }

    func recentlyPlayed(limit: Int = 20, accountId: Int64? = nil) -> [MediaItem] {
        if let aid = accountId {
            let amRecent = accountMediaTable.filter(colAMAccountId == aid && colAMLastPlayed != nil)
                .order(colAMLastPlayed.desc).limit(limit)
            guard let amRows = try? db.prepare(amRecent) else { return [] }
            var result: [MediaItem] = []
            for amRow in amRows {
                let mid = amRow[colAMMediaId]
                if let mediaRow = try? db.pluck(media.filter(colId == mid)) {
                    result.append(mediaItemWithAccount(mediaRow: mediaRow, accountId: aid))
                }
            }
            return result
        }
        return (try? db.prepare(media.filter(colLastPlayed != nil).order(colLastPlayed.desc).limit(limit)).map(mediaItem)) ?? []
    }

    func continueWatching(limit: Int = 20, accountId: Int64? = nil) -> [MediaItem] {
        if let aid = accountId {
            let amContinue = accountMediaTable
                .filter(colAMAccountId == aid && colAMWatchProgress > 0 && colAMWatched == false)
                .order(colAMLastPlayed.desc).limit(limit)
            guard let amRows = try? db.prepare(amContinue) else { return [] }
            var result: [MediaItem] = []
            for amRow in amRows {
                let mid = amRow[colAMMediaId]
                if let mediaRow = try? db.pluck(media.filter(colId == mid)) {
                    result.append(mediaItemWithAccount(mediaRow: mediaRow, accountId: aid))
                }
            }
            return result
        }
        let query = media.filter(colWatchProgress > 0 && colWatched == false).order(colLastPlayed.desc).limit(limit)
        return (try? db.prepare(query).map(mediaItem)) ?? []
    }

    // MARK: - Non-Account Mutations (unchanged)

    func updateThumbnail(movieId: Int64, path: String) {
        try? db.run(media.filter(colId == movieId).update(colThumbnailPath <- path))
    }

    func updateDescription(movieId: Int64, desc: String) {
        try? db.run(media.filter(colId == movieId).update(colDescription <- desc))
    }

    func totalWatchTime(accountId: Int64? = nil) -> Double {
        if let aid = accountId {
            return (try? db.scalar(accountMediaTable.filter(colAMAccountId == aid).select(colAMTotalWatchTime.sum))) ?? 0
        }
        return (try? db.scalar(media.select(colTotalWatchTime.sum))) ?? 0
    }

    func backfillDescriptions() {
        guard let rows = try? db.prepare(media.filter(colDescription == nil)) else { return }
        for row in rows {
            let title = row[colTitle]
            let showName = row[colShowName]
            if let desc = MovieDescriptions.lookup(showName ?? title) {
                try? db.run(media.filter(colId == row[colId]).update(colDescription <- desc))
            }
        }
    }

    func backfillGenresAndRatings() {
        guard let rows = try? db.prepare(media.filter(colGenre == nil || colRating == nil)) else { return }
        for row in rows {
            let key = row[colShowName] ?? row[colTitle]
            var setters: [Setter] = []
            if row[colGenre] == nil, let g = MovieDescriptions.genreLookup(key) {
                setters.append(colGenre <- g)
            }
            if row[colRating] == nil, let r = MovieDescriptions.ratingLookup(key) {
                setters.append(colRating <- r)
            }
            if !setters.isEmpty {
                try? db.run(media.filter(colId == row[colId]).update(setters))
            }
        }
    }

    // MARK: - Counts

    func movieCount() -> Int {
        (try? db.scalar(media.filter(colMediaType == MediaType.movie.rawValue).count)) ?? 0
    }

    func showCount() -> Int {
        let eps = (try? db.prepare(media.filter(colMediaType == MediaType.tvEpisode.rawValue).select(colShowName).group(colShowName))) ?? AnySequence([])
        return Array(eps).count
    }

    func itemsMissingDuration(limit: Int = 100) -> [MediaItem] {
        (try? db.prepare(media.filter(colDuration == 0).limit(limit)).map(mediaItem)) ?? []
    }

    func deleteAll() {
        try? db.run(media.delete())
    }

    // MARK: - Stats Queries (Account-Aware)

    func genreBreakdown(accountId: Int64? = nil) -> [(genre: String, total: Int, watched: Int)] {
        let query = media.filter(colMediaType == MediaType.movie.rawValue && colGenre != nil)
        guard let rows = try? db.prepare(query) else { return [] }
        var totals: [String: Int] = [:]
        var watchedCounts: [String: Int] = [:]
        for row in rows {
            if let g = row[colGenre], !g.isEmpty {
                totals[g, default: 0] += 1
                if let aid = accountId {
                    if let amRow = try? db.pluck(accountMediaTable.filter(colAMAccountId == aid && colAMMediaId == row[colId])),
                       amRow[colAMWatched] {
                        watchedCounts[g, default: 0] += 1
                    }
                } else {
                    if row[colWatched] { watchedCounts[g, default: 0] += 1 }
                }
            }
        }
        return totals.map { (genre: $0.key, total: $0.value, watched: watchedCounts[$0.key] ?? 0) }
            .sorted { $0.total > $1.total }
    }

    func qualityBreakdown() -> [(quality: String, count: Int)] {
        let query = media.filter(colMediaType == MediaType.movie.rawValue)
        guard let rows = try? db.prepare(query) else { return [] }
        var counts: [String: Int] = [:]
        for row in rows {
            let q = row[colQuality] ?? "Unknown"
            let label: String
            if q.contains("2160") || q.uppercased().contains("4K") {
                label = "4K"
            } else if q.contains("1080") {
                label = "1080p"
            } else if q.contains("720") {
                label = "720p"
            } else if q.isEmpty || q == "Unknown" {
                label = "Other"
            } else {
                label = "Other"
            }
            counts[label, default: 0] += 1
        }
        return counts.map { (quality: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    func topRated(limit: Int = 10) -> [MediaItem] {
        let query = media.filter(colMediaType == MediaType.movie.rawValue && colRating != nil)
            .order(colRating.desc, colTitle.asc)
            .limit(limit)
        return (try? db.prepare(query).map(mediaItem)) ?? []
    }

    func watchedMovieCount(accountId: Int64? = nil) -> Int {
        if let aid = accountId {
            let movieIds = media.filter(colMediaType == MediaType.movie.rawValue).select(colId)
            guard let mids = try? db.prepare(movieIds) else { return 0 }
            var count = 0
            for mRow in mids {
                let mid = mRow[colId]
                if let amRow = try? db.pluck(accountMediaTable.filter(colAMAccountId == aid && colAMMediaId == mid)),
                   amRow[colAMWatched] {
                    count += 1
                }
            }
            return count
        }
        return (try? db.scalar(media.filter(colMediaType == MediaType.movie.rawValue && colWatched == true).count)) ?? 0
    }

    func averageRating() -> Int? {
        let query = media.filter(colMediaType == MediaType.movie.rawValue && colWatched == true && colRating != nil)
        guard let rows = try? db.prepare(query) else { return nil }
        var sum = 0
        var count = 0
        for row in rows {
            if let r = row[colRating] {
                sum += r
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return sum / count
    }

    func moviesByQuality(quality: String) -> [MediaItem] {
        let query = media.filter(colMediaType == MediaType.movie.rawValue && colQuality.like("%\(quality)%"))
            .order(colTitle.asc)
        return (try? db.prepare(query).map(mediaItem)) ?? []
    }

    func recentlyWatched(limit: Int = 10, accountId: Int64? = nil) -> [MediaItem] {
        if let aid = accountId {
            let amWatched = accountMediaTable.filter(colAMAccountId == aid && colAMWatched == true && colAMLastPlayed != nil)
                .order(colAMLastPlayed.desc).limit(limit)
            guard let amRows = try? db.prepare(amWatched) else { return [] }
            var result: [MediaItem] = []
            for amRow in amRows {
                let mid = amRow[colAMMediaId]
                if let mediaRow = try? db.pluck(media.filter(colId == mid && colMediaType == MediaType.movie.rawValue)) {
                    result.append(mediaItemWithAccount(mediaRow: mediaRow, accountId: aid))
                }
            }
            return result
        }
        let query = media.filter(colMediaType == MediaType.movie.rawValue && colWatched == true && colLastPlayed != nil)
            .order(colLastPlayed.desc)
            .limit(limit)
        return (try? db.prepare(query).map(mediaItem)) ?? []
    }

    // MARK: - Comments

    func addComment(mediaId: Int64, timestamp: Double, text: String) {
        try? db.run(commentsTable.insert(
            colCommentMediaId <- mediaId,
            colCommentTimestamp <- timestamp,
            colCommentText <- text,
            colCommentCreatedAt <- Date().timeIntervalSince1970
        ))
    }

    func comments(forMedia mediaId: Int64) -> [TimestampComment] {
        let query = commentsTable.filter(colCommentMediaId == mediaId).order(colCommentTimestamp.asc)
        guard let rows = try? db.prepare(query) else { return [] }
        return rows.map { row in
            TimestampComment(
                id: row[colCommentId],
                mediaId: row[colCommentMediaId],
                timestamp: row[colCommentTimestamp],
                text: row[colCommentText],
                createdAt: Date(timeIntervalSince1970: row[colCommentCreatedAt])
            )
        }
    }

    func deleteComment(id: Int64) {
        try? db.run(commentsTable.filter(colCommentId == id).delete())
    }

    func commentsNear(mediaId: Int64, timestamp: Double, window: Double = 3.0) -> [TimestampComment] {
        let lo = timestamp - window
        let hi = timestamp + window
        let query = commentsTable
            .filter(colCommentMediaId == mediaId && colCommentTimestamp >= lo && colCommentTimestamp <= hi)
            .order(colCommentTimestamp.asc)
        guard let rows = try? db.prepare(query) else { return [] }
        return rows.map { row in
            TimestampComment(
                id: row[colCommentId],
                mediaId: row[colCommentMediaId],
                timestamp: row[colCommentTimestamp],
                text: row[colCommentText],
                createdAt: Date(timeIntervalSince1970: row[colCommentCreatedAt])
            )
        }
    }

    // MARK: - Downloads

    func insertDownload(
        id: String, contentType: String, contentId: Int64, title: String,
        subtitle: String?, fileSize: Int64, serverURL: String?, sourcePath: String?
    ) {
        try? db.run(downloadsTable.insert(
            colDlId <- id,
            colDlContentType <- contentType,
            colDlContentId <- contentId,
            colDlTitle <- title,
            colDlSubtitle <- subtitle,
            colDlStatus <- "queued",
            colDlFileSize <- fileSize,
            colDlBytesDownloaded <- Int64(0),
            colDlServerURL <- serverURL,
            colDlSourcePath <- sourcePath,
            colDlCreatedAt <- Date().timeIntervalSince1970
        ))
    }

    func updateDownloadStatus(id: String, status: String) {
        try? db.run(downloadsTable.filter(colDlId == id).update(colDlStatus <- status))
    }

    func updateDownloadProgress(id: String, bytesDownloaded: Int64) {
        try? db.run(downloadsTable.filter(colDlId == id).update(
            colDlBytesDownloaded <- bytesDownloaded
        ))
    }

    func completeDownload(id: String, localFilePath: String) {
        let now = Date().timeIntervalSince1970
        try? db.run(downloadsTable.filter(colDlId == id).update(
            colDlStatus <- "completed",
            colDlLocalFilePath <- localFilePath,
            colDlCompletedAt <- now
        ))
    }

    func failDownload(id: String, error: String) {
        try? db.run(downloadsTable.filter(colDlId == id).update(
            colDlStatus <- "failed",
            colDlErrorMessage <- error
        ))
    }

    func deleteDownload(id: String) {
        try? db.run(downloadsTable.filter(colDlId == id).delete())
    }

    func allDownloads(status: String? = nil) -> [MacDownloadRecord] {
        var query = downloadsTable.order(colDlCreatedAt.desc)
        if let s = status {
            query = downloadsTable.filter(colDlStatus == s).order(colDlCreatedAt.desc)
        }
        guard let rows = try? db.prepare(query) else { return [] }
        return rows.map { row in
            MacDownloadRecord(
                id: row[colDlId],
                contentType: row[colDlContentType],
                contentId: row[colDlContentId],
                title: row[colDlTitle],
                subtitle: row[colDlSubtitle],
                status: row[colDlStatus],
                fileSize: row[colDlFileSize],
                bytesDownloaded: row[colDlBytesDownloaded],
                localFilePath: row[colDlLocalFilePath],
                serverURL: row[colDlServerURL],
                sourcePath: row[colDlSourcePath],
                createdAt: Date(timeIntervalSince1970: row[colDlCreatedAt]),
                completedAt: row[colDlCompletedAt].map { Date(timeIntervalSince1970: $0) },
                errorMessage: row[colDlErrorMessage]
            )
        }
    }

    func activeDownloadCount() -> Int {
        let statuses = ["queued", "downloading", "paused"]
        let query = downloadsTable.filter(statuses.contains(colDlStatus))
        return (try? db.scalar(query.count)) ?? 0
    }

    // MARK: - Known Devices

    func upsertDevice(id: String, name: String, deviceType: String, accountId: Int64?, isOnline: Bool) {
        let existing = try? db.pluck(knownDevicesTable.filter(colDevId == id))
        if existing != nil {
            try? db.run(knownDevicesTable.filter(colDevId == id).update(
                colDevName <- name,
                colDevType <- deviceType,
                colDevAccountId <- accountId,
                colDevIsOnline <- isOnline,
                colDevLastSeen <- Date().timeIntervalSince1970
            ))
        } else {
            try? db.run(knownDevicesTable.insert(
                colDevId <- id,
                colDevName <- name,
                colDevType <- deviceType,
                colDevAccountId <- accountId,
                colDevIsOnline <- isOnline,
                colDevLastSeen <- Date().timeIntervalSince1970
            ))
        }
    }

    func allDevices() -> [ConnectedDevice] {
        let query = knownDevicesTable.order(colDevLastSeen.desc)
        guard let rows = try? db.prepare(query) else { return [] }
        return rows.map { row in
            ConnectedDevice(
                id: row[colDevId],
                name: row[colDevName],
                deviceType: row[colDevType],
                accountId: row[colDevAccountId],
                isOnline: row[colDevIsOnline],
                lastSeen: Date(timeIntervalSince1970: row[colDevLastSeen])
            )
        }
    }

    func onlineDevices() -> [ConnectedDevice] {
        let query = knownDevicesTable.filter(colDevIsOnline == true).order(colDevLastSeen.desc)
        guard let rows = try? db.prepare(query) else { return [] }
        return rows.map { row in
            ConnectedDevice(
                id: row[colDevId],
                name: row[colDevName],
                deviceType: row[colDevType],
                accountId: row[colDevAccountId],
                isOnline: row[colDevIsOnline],
                lastSeen: Date(timeIntervalSince1970: row[colDevLastSeen])
            )
        }
    }

    func markAllDevicesOffline() {
        try? db.run(knownDevicesTable.update(colDevIsOnline <- false))
    }

    func deleteDevice(id: String) {
        _ = try? db.run(knownDevicesTable.filter(colDevId == id).delete())
    }

    // MARK: - Artist Profile Cache

    private static let artistImageCacheDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cinemate")
            .appendingPathComponent("thumbnails")
            .appendingPathComponent("artists")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Returns a cached ArtistProfile if it exists and is less than `maxAge` seconds old (default 7 days).
    func cachedArtistProfile(name: String, maxAge: TimeInterval = 7 * 24 * 3600) -> (profile: ArtistProfile, imagePath: String?)? {
        guard let row = try? db.pluck(artistProfilesTable.filter(colApName == name)) else { return nil }
        let cachedAt = row[colApCachedAt]
        if Date().timeIntervalSince1970 - cachedAt > maxAge { return nil } // stale

        let genres: [String] = {
            let raw = row[colApGenres]
            guard let data = raw.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return arr
        }()

        let profile = ArtistProfile(
            name: row[colApName],
            bio: row[colApBio],
            imageURL: nil, // not stored; we use local image path instead
            genres: genres,
            popularity: row[colApPopularity],
            followers: row[colApFollowers],
            wikipediaURL: row[colApWikipediaURL],
            trackCount: 0,
            albumCount: 0
        )
        return (profile, row[colApImagePath])
    }

    /// Save an ArtistProfile to the cache. `imagePath` is the local file path for the downloaded image.
    func cacheArtistProfile(_ profile: ArtistProfile, imagePath: String?) {
        let genresJSON: String = {
            guard let data = try? JSONEncoder().encode(profile.genres) else { return "[]" }
            return String(data: data, encoding: .utf8) ?? "[]"
        }()

        let existing = try? db.pluck(artistProfilesTable.filter(colApName == profile.name))
        if existing != nil {
            try? db.run(artistProfilesTable.filter(colApName == profile.name).update(
                colApBio <- profile.bio,
                colApImagePath <- imagePath,
                colApGenres <- genresJSON,
                colApPopularity <- profile.popularity,
                colApFollowers <- profile.followers,
                colApWikipediaURL <- profile.wikipediaURL,
                colApCachedAt <- Date().timeIntervalSince1970
            ))
        } else {
            try? db.run(artistProfilesTable.insert(
                colApName <- profile.name,
                colApBio <- profile.bio,
                colApImagePath <- imagePath,
                colApGenres <- genresJSON,
                colApPopularity <- profile.popularity,
                colApFollowers <- profile.followers,
                colApWikipediaURL <- profile.wikipediaURL,
                colApCachedAt <- Date().timeIntervalSince1970
            ))
        }
    }

    /// Returns the path for caching an artist image on disk.
    static func artistImageCachePath(for artistName: String) -> URL {
        let slug = artistName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return artistImageCacheDir.appendingPathComponent("\(slug).jpg")
    }

    /// Download and cache an artist image to disk. Returns the local file path on success.
    static func downloadAndCacheArtistImage(from urlString: String, artistName: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let destURL = artistImageCachePath(for: artistName)

        // If already cached on disk, return it
        if FileManager.default.fileExists(atPath: destURL.path) {
            return destURL.path
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = NSImage(data: data) else { return nil }
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
                return nil
            }
            try jpegData.write(to: destURL)
            return destURL.path
        } catch {
            return nil
        }
    }
}

enum SortOption: String, CaseIterable {
    case title = "Title"
    case year = "Year"
    case dateAdded = "Date Added"
    case lastPlayed = "Last Played"
    case fileSize = "File Size"
}
