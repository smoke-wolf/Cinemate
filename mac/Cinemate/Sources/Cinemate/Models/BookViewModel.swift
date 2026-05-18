import SwiftUI
import SQLite

@MainActor
final class BookViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var currentlyReading: [Book] = []
    @Published var finishedBooks: [Book] = []
    @Published var authors: [BookAuthor] = []
    @Published var bookmarks: [BookBookmark] = []
    @Published var searchQuery = ""
    @Published var sortOption: BookSortOption = .dateAdded
    @Published var currentSubView: BookSubView = .all
    @Published var formatFilter: String? = nil
    @Published var selectedBook: Book? = nil
    @Published var readingBook: Book? = nil
    @Published var isScanning = false
    @Published var scanProgress = 0

    @Published var ttsInstalled = false
    @Published var ttsInstalling = false
    @Published var ttsInstallLog = ""
    @Published var ttsGenerating = false
    @Published var ttsProgress = ""
    @Published var ttsChapterProgress: (current: Int, total: Int) = (0, 0)

    var accountId: Int64? = nil

    private let ttsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".cinemate/tts")

    func checkTTSInstalled() {
        let marker = ttsDir.appendingPathComponent(".installed")
        let model = ttsDir.appendingPathComponent("models/kokoro-v1.0.onnx")
        ttsInstalled = FileManager.default.fileExists(atPath: marker.path)
            && FileManager.default.fileExists(atPath: model.path)
    }

    func installTTS() {
        guard !ttsInstalling else { return }
        ttsInstalling = true
        ttsInstallLog = "Starting TTS engine install..."

        let scriptPath = Bundle.main.resourcePath
            .map { ($0 as NSString).deletingLastPathComponent + "/../../../scripts/install-tts.sh" }
            ?? ""

        let resolvedScript: String
        if FileManager.default.fileExists(atPath: scriptPath) {
            resolvedScript = scriptPath
        } else {
            let devScript = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("cinemate-v3/mac/scripts/install-tts.sh").path
            if FileManager.default.fileExists(atPath: devScript) {
                resolvedScript = devScript
            } else {
                ttsInstallLog = "Error: install-tts.sh not found"
                ttsInstalling = false
                return
            }
        }

        Task.detached { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [resolvedScript]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
            } catch {
                await MainActor.run {
                    self?.ttsInstallLog = "Failed to start installer: \(error.localizedDescription)"
                    self?.ttsInstalling = false
                }
                return
            }

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    self?.ttsInstallLog = line.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            process.waitUntilExit()

            await MainActor.run {
                self?.ttsInstalling = false
                self?.checkTTSInstalled()
                if self?.ttsInstalled == true {
                    self?.ttsInstallLog = "Kokoro TTS installed successfully!"
                } else {
                    self?.ttsInstallLog = "Installation failed (exit code \(process.terminationStatus))"
                }
            }
        }
    }

    func generateAudiobook(_ book: Book, voice: String = "af_bella", speed: Double = 1.0) {
        guard !ttsGenerating else { return }
        ttsGenerating = true
        ttsProgress = "Preparing..."
        ttsChapterProgress = (0, 0)

        let scriptPath: String
        let devScript = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("cinemate-v3/mac/scripts/book-to-audio.sh").path
        if FileManager.default.fileExists(atPath: devScript) {
            scriptPath = devScript
        } else {
            let bundleScript = Bundle.main.resourcePath
                .map { ($0 as NSString).deletingLastPathComponent + "/../../../scripts/book-to-audio.sh" }
                ?? ""
            scriptPath = bundleScript
        }

        let outputDir = audiobookDirectory(for: book)
        try? FileManager.default.createDirectory(at: URL(fileURLWithPath: outputDir), withIntermediateDirectories: true)

        Task.detached { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath, book.filePath, outputDir, "--voice", voice, "--speed", String(speed)]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
            } catch {
                await MainActor.run {
                    self?.ttsProgress = "Failed: \(error.localizedDescription)"
                    self?.ttsGenerating = false
                }
                return
            }

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
                for line in output.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { continue }

                    Task { @MainActor in
                        if trimmed.hasPrefix("[PROGRESS] STAGE|") {
                            let parts = trimmed.replacingOccurrences(of: "[PROGRESS] STAGE|", with: "")
                                .components(separatedBy: "|")
                            self?.ttsProgress = parts.last ?? trimmed
                        } else if trimmed.hasPrefix("[PROGRESS] CHAPTER|") {
                            let parts = trimmed.replacingOccurrences(of: "[PROGRESS] CHAPTER|", with: "")
                                .components(separatedBy: "|")
                            if parts.count >= 3,
                               let current = Int(parts[0]),
                               let total = Int(parts[1]) {
                                self?.ttsChapterProgress = (current, total)
                                self?.ttsProgress = "Chapter \(current)/\(total): \(parts[2])"
                            }
                        } else if trimmed.hasPrefix("[PROGRESS] DONE|") {
                            self?.ttsProgress = "Complete!"
                        }
                    }
                }
            }

            process.waitUntilExit()

            await MainActor.run {
                self?.ttsGenerating = false
                if process.terminationStatus == 0 {
                    self?.ttsProgress = "Audiobook ready!"
                } else {
                    self?.ttsProgress = "Generation failed"
                }
            }
        }
    }

    func audiobookDirectory(for book: Book) -> String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cinemate/audiobooks", isDirectory: true)
        let safe = book.title.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return base.appendingPathComponent(safe).path
    }

    func audiobookExists(for book: Book) -> Bool {
        let dir = audiobookDirectory(for: book)
        let meta = (dir as NSString).appendingPathComponent("audiobook.json")
        return FileManager.default.fileExists(atPath: meta)
    }

    func audiobookMetadata(for book: Book) -> AudiobookMeta? {
        let dir = audiobookDirectory(for: book)
        let meta = (dir as NSString).appendingPathComponent("audiobook.json")
        guard let data = FileManager.default.contents(atPath: meta) else { return nil }
        return try? JSONDecoder().decode(AudiobookMeta.self, from: data)
    }

    func loadBooks() {
        let aid = accountId
        books = BookDatabase.shared.allBooks(sortBy: sortOption, searchQuery: searchQuery, formatFilter: formatFilter, accountId: aid)
        currentlyReading = BookDatabase.shared.currentlyReading(accountId: aid)
        finishedBooks = BookDatabase.shared.finishedBooks(accountId: aid)
        authors = BookDatabase.shared.allAuthors()
    }

    func search(_ query: String) {
        searchQuery = query
        books = BookDatabase.shared.allBooks(sortBy: sortOption, searchQuery: query, formatFilter: formatFilter, accountId: accountId)
    }

    func sort(by option: BookSortOption) {
        sortOption = option
        books = BookDatabase.shared.allBooks(sortBy: option, searchQuery: searchQuery, formatFilter: formatFilter, accountId: accountId)
    }

    func filterByFormat(_ format: String?) {
        formatFilter = format
        books = BookDatabase.shared.allBooks(sortBy: sortOption, searchQuery: searchQuery, formatFilter: format, accountId: accountId)
    }

    func toggleFavorite(_ book: Book) {
        BookDatabase.shared.toggleFavorite(bookId: book.id, accountId: accountId)
        loadBooks()
    }

    func markFinished(_ book: Book) {
        BookDatabase.shared.markFinished(bookId: book.id, accountId: accountId)
        loadBooks()
    }

    func updateProgress(bookId: Int64, progress: Double, page: Int) {
        BookDatabase.shared.updateProgress(bookId: bookId, progress: progress, currentPage: page, accountId: accountId)
        loadBooks()
    }

    @Published var readAsEbook = false

    func openReader(_ book: Book) {
        selectedBook = nil
        readAsEbook = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.readingBook = book
        }
    }

    func openReaderAsEbook(_ book: Book) {
        selectedBook = nil
        readAsEbook = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.readingBook = book
        }
    }

    func closeReader() {
        readingBook = nil
        loadBooks()
    }

    func showDetail(_ book: Book) {
        selectedBook = book
    }

    func loadBookmarks(for bookId: Int64) {
        bookmarks = BookDatabase.shared.bookmarks(forBook: bookId, accountId: accountId)
    }

    func addBookmark(bookId: Int64, page: Int, note: String?) {
        BookDatabase.shared.addBookmark(bookId: bookId, page: page, note: note, accountId: accountId)
        loadBookmarks(for: bookId)
    }

    func deleteBookmark(id: Int64) {
        BookDatabase.shared.deleteBookmark(id: id)
    }

    func openInBooksApp(_ book: Book) {
        NSWorkspace.shared.open(URL(fileURLWithPath: book.filePath))
    }

    func booksForAuthor(_ name: String) -> [Book] {
        BookDatabase.shared.booksForAuthor(name, accountId: accountId)
    }

    func scan(directory: String) {
        isScanning = true
        scanProgress = 0
        Task {
            let count = await BookScanner.scan(directory: directory) { progress in
                Task { @MainActor in
                    self.scanProgress = progress
                    if progress % 10 == 0 {
                        self.loadBooks()
                    }
                }
            }
            self.isScanning = false
            self.loadBooks()
            print("Book scan complete: \(count) items indexed")
        }
    }
}

// MARK: - Book Scanner

enum BookScanner {
    static func scan(directory: String, progress: @escaping (Int) -> Void) async -> Int {
        let fm = FileManager.default
        let bookExtensions = Set(["epub", "pdf", "mobi", "azw3", "fb2", "djvu", "cbz", "cbr"])

        guard let enumerator = fm.enumerator(atPath: directory) else { return 0 }

        var files: [String] = []
        while let file = enumerator.nextObject() as? String {
            let ext = (file as NSString).pathExtension.lowercased()
            if bookExtensions.contains(ext) {
                files.append((directory as NSString).appendingPathComponent(file))
            }
        }

        var count = 0
        for (index, filePath) in files.enumerated() {
            let attrs = try? fm.attributesOfItem(atPath: filePath)
            let fileSize = (attrs?[.size] as? Int64) ?? 0
            let ext = (filePath as NSString).pathExtension.lowercased()

            // Parse title/author from filename
            let filename = ((filePath as NSString).lastPathComponent as NSString).deletingPathExtension
            var title = filename
            var author: String? = nil

            if filename.contains(" - ") {
                let parts = filename.components(separatedBy: " - ")
                author = parts[0].trimmingCharacters(in: .whitespaces)
                title = parts[1].trimmingCharacters(in: .whitespaces)
            }

            // Clean up
            title = title.replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: ".", with: " ")
                .trimmingCharacters(in: .whitespaces)

            do {
                try BookDatabase.shared.insertBook(
                    title: title,
                    author: author,
                    filePath: filePath,
                    fileSize: fileSize,
                    format: ext.uppercased()
                )
                count += 1
            } catch {
                // Duplicate or other error
            }

            let pct = Int(Double(index + 1) / Double(files.count) * 100)
            progress(pct)
        }

        return count
    }
}

// MARK: - Book Database Layer

final class BookDatabase {
    static let shared = BookDatabase()

    private let db: Connection

    // Books table
    private let booksTable = Table("books")
    private let colId = SQLite.Expression<Int64>("id")
    private let colTitle = SQLite.Expression<String>("title")
    private let colAuthor = SQLite.Expression<String?>("author")
    private let colGenre = SQLite.Expression<String?>("genre")
    private let colPublisher = SQLite.Expression<String?>("publisher")
    private let colLanguage = SQLite.Expression<String?>("language")
    private let colDescription = SQLite.Expression<String?>("description")
    private let colPageCount = SQLite.Expression<Int>("page_count")
    private let colFormat = SQLite.Expression<String>("format")
    private let colFilePath = SQLite.Expression<String>("file_path")
    private let colFileSize = SQLite.Expression<Int64>("file_size")
    private let colCoverPath = SQLite.Expression<String?>("cover_path")
    private let colYear = SQLite.Expression<Int?>("year")
    private let colDateAdded = SQLite.Expression<Double>("date_added")

    // Book account data table
    private let bookAccountTable = Table("book_account_data")
    private let colBAAccountId = SQLite.Expression<Int64>("account_id")
    private let colBABookId = SQLite.Expression<Int64>("book_id")
    private let colBAProgress = SQLite.Expression<Double>("reading_progress")
    private let colBACurrentPage = SQLite.Expression<Int>("current_page")
    private let colBAFavorite = SQLite.Expression<Bool>("favorite")
    private let colBAFinished = SQLite.Expression<Bool>("finished")
    private let colBAStartedAt = SQLite.Expression<Double?>("started_at")
    private let colBAFinishedAt = SQLite.Expression<Double?>("finished_at")
    private let colBATotalReadingTime = SQLite.Expression<Double>("total_reading_time")

    // Book bookmarks table
    private let bookmarksTable = Table("book_bookmarks")
    private let colBMId = SQLite.Expression<Int64>("id")
    private let colBMAccountId = SQLite.Expression<Int64>("account_id")
    private let colBMBookId = SQLite.Expression<Int64>("book_id")
    private let colBMPage = SQLite.Expression<Int>("page")
    private let colBMNote = SQLite.Expression<String?>("note")
    private let colBMCreatedAt = SQLite.Expression<Double>("created_at")

    private init() {
        let dbDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cinemate", isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath = dbDir.appendingPathComponent("library.db").path
        do {
            db = try Connection(dbPath)
        } catch {
            fatalError("Failed to open Cinemate book database at \(dbPath): \(error)")
        }
        createTables()
    }

    private func createTables() {
        do {
            try db.run(booksTable.create(ifNotExists: true) { t in
                t.column(colId, primaryKey: .autoincrement)
                t.column(colTitle)
                t.column(colAuthor)
                t.column(colGenre)
                t.column(colPublisher)
                t.column(colLanguage)
                t.column(colDescription)
                t.column(colPageCount, defaultValue: 0)
                t.column(colFormat)
                t.column(colFilePath, unique: true)
                t.column(colFileSize, defaultValue: 0)
                t.column(colCoverPath)
                t.column(colYear)
                t.column(colDateAdded)
            })
            try? db.run(booksTable.createIndex(colTitle, ifNotExists: true))
            try? db.run(booksTable.createIndex(colAuthor, ifNotExists: true))
            try? db.run(booksTable.createIndex(colFormat, ifNotExists: true))

            try db.run(bookAccountTable.create(ifNotExists: true) { t in
                t.column(colBAAccountId)
                t.column(colBABookId)
                t.column(colBAProgress, defaultValue: 0)
                t.column(colBACurrentPage, defaultValue: 0)
                t.column(colBAFavorite, defaultValue: false)
                t.column(colBAFinished, defaultValue: false)
                t.column(colBAStartedAt)
                t.column(colBAFinishedAt)
                t.column(colBATotalReadingTime, defaultValue: 0)
                t.primaryKey(colBAAccountId, colBABookId)
            })

            try db.run(bookmarksTable.create(ifNotExists: true) { t in
                t.column(colBMId, primaryKey: .autoincrement)
                t.column(colBMAccountId)
                t.column(colBMBookId)
                t.column(colBMPage)
                t.column(colBMNote)
                t.column(colBMCreatedAt)
            })
            try? db.run(bookmarksTable.createIndex(colBMBookId, ifNotExists: true))
        } catch {
            fatalError("Failed to create Cinemate book tables: \(error)")
        }
    }

    // MARK: - Insert

    func insertBook(title: String, author: String?, filePath: String, fileSize: Int64, format: String) throws {
        let existing = try db.pluck(booksTable.filter(colFilePath == filePath))
        if existing != nil { return }

        try db.run(booksTable.insert(
            colTitle <- title,
            colAuthor <- author,
            colFormat <- format,
            colFilePath <- filePath,
            colFileSize <- fileSize,
            colDateAdded <- Date().timeIntervalSince1970
        ))
    }

    // MARK: - Book Item Building

    private func bookItem(from row: Row) -> Book {
        Book(
            id: row[colId],
            title: row[colTitle],
            author: row[colAuthor],
            genre: row[colGenre],
            publisher: row[colPublisher],
            language: row[colLanguage],
            description_: row[colDescription],
            pageCount: row[colPageCount],
            format: row[colFormat],
            filePath: row[colFilePath],
            fileSize: row[colFileSize],
            coverPath: row[colCoverPath],
            year: row[colYear],
            dateAdded: Date(timeIntervalSince1970: row[colDateAdded]),
            readingProgress: 0,
            currentPage: 0,
            favorite: false,
            finished: false,
            startedAt: nil,
            finishedAt: nil,
            totalReadingTime: 0
        )
    }

    private func bookItemWithAccount(mediaRow: Row, accountId: Int64) -> Book {
        var item = bookItem(from: mediaRow)
        let amRow = try? db.pluck(
            bookAccountTable.filter(colBAAccountId == accountId && colBABookId == item.id)
        )
        if let am = amRow {
            item.readingProgress = am[colBAProgress]
            item.currentPage = am[colBACurrentPage]
            item.favorite = am[colBAFavorite]
            item.finished = am[colBAFinished]
            item.startedAt = am[colBAStartedAt].map { Date(timeIntervalSince1970: $0) }
            item.finishedAt = am[colBAFinishedAt].map { Date(timeIntervalSince1970: $0) }
            item.totalReadingTime = am[colBATotalReadingTime]
        }
        return item
    }

    // MARK: - Queries

    func allBooks(sortBy: BookSortOption = .dateAdded, searchQuery: String = "", formatFilter: String? = nil, accountId: Int64? = nil) -> [Book] {
        var query = booksTable as SQLite.Table
        if !searchQuery.isEmpty {
            let p = "%\(searchQuery)%"
            query = query.filter(colTitle.like(p) || colAuthor.like(p))
        }
        if let fmt = formatFilter, !fmt.isEmpty {
            query = query.filter(colFormat == fmt)
        }

        switch sortBy {
        case .title: query = query.order(colTitle.asc)
        case .author: query = query.order(colAuthor.asc, colTitle.asc)
        case .dateAdded: query = query.order(colDateAdded.desc)
        case .year: query = query.order(colYear.desc, colTitle.asc)
        }

        guard let rows = try? db.prepare(query) else { return [] }
        if let aid = accountId {
            return rows.map { bookItemWithAccount(mediaRow: $0, accountId: aid) }
        }
        return rows.map(bookItem)
    }

    func currentlyReading(accountId: Int64? = nil) -> [Book] {
        guard let aid = accountId else { return [] }
        let amReading = bookAccountTable
            .filter(colBAAccountId == aid && colBAProgress > 0 && colBAFinished == false)
            .order(colBAStartedAt.desc)
        guard let amRows = try? db.prepare(amReading) else { return [] }
        var result: [Book] = []
        for amRow in amRows {
            let bid = amRow[colBABookId]
            if let bookRow = try? db.pluck(booksTable.filter(colId == bid)) {
                result.append(bookItemWithAccount(mediaRow: bookRow, accountId: aid))
            }
        }
        return result
    }

    func finishedBooks(accountId: Int64? = nil) -> [Book] {
        guard let aid = accountId else { return [] }
        let amFinished = bookAccountTable
            .filter(colBAAccountId == aid && colBAFinished == true)
            .order(colBAFinishedAt.desc)
        guard let amRows = try? db.prepare(amFinished) else { return [] }
        var result: [Book] = []
        for amRow in amRows {
            let bid = amRow[colBABookId]
            if let bookRow = try? db.pluck(booksTable.filter(colId == bid)) {
                result.append(bookItemWithAccount(mediaRow: bookRow, accountId: aid))
            }
        }
        return result
    }

    func allAuthors() -> [BookAuthor] {
        let query = booksTable.select(colAuthor, colId.count)
            .filter(colAuthor != nil)
            .group(colAuthor)
            .order(colId.count.desc)
        guard let rows = try? db.prepare(query) else { return [] }
        return rows.compactMap { row in
            guard let name = row[colAuthor], !name.isEmpty else { return nil }
            return BookAuthor(name: name, bookCount: row[colId.count])
        }
    }

    func booksForAuthor(_ name: String, accountId: Int64? = nil) -> [Book] {
        let query = booksTable.filter(colAuthor.like("%\(name)%")).order(colYear.desc, colTitle.asc)
        guard let rows = try? db.prepare(query) else { return [] }
        if let aid = accountId {
            return rows.map { bookItemWithAccount(mediaRow: $0, accountId: aid) }
        }
        return rows.map(bookItem)
    }

    // MARK: - Account Helpers

    private func ensureAccountBook(accountId: Int64, bookId: Int64) {
        let row = bookAccountTable.filter(colBAAccountId == accountId && colBABookId == bookId)
        if (try? db.pluck(row)) == nil {
            try? db.run(bookAccountTable.insert(
                colBAAccountId <- accountId,
                colBABookId <- bookId
            ))
        }
    }

    func toggleFavorite(bookId: Int64, accountId: Int64? = nil) {
        guard let aid = accountId else { return }
        ensureAccountBook(accountId: aid, bookId: bookId)
        let row = bookAccountTable.filter(colBAAccountId == aid && colBABookId == bookId)
        if let existing = try? db.pluck(row) {
            try? db.run(row.update(colBAFavorite <- !existing[colBAFavorite]))
        }
    }

    func markFinished(bookId: Int64, accountId: Int64? = nil) {
        guard let aid = accountId else { return }
        ensureAccountBook(accountId: aid, bookId: bookId)
        let row = bookAccountTable.filter(colBAAccountId == aid && colBABookId == bookId)
        if let existing = try? db.pluck(row) {
            let newFinished = !existing[colBAFinished]
            var setters: [SQLite.Setter] = [colBAFinished <- newFinished]
            if newFinished {
                setters.append(colBAProgress <- 1.0)
                setters.append(colBAFinishedAt <- Date().timeIntervalSince1970)
            } else {
                setters.append(colBAFinishedAt <- nil as Double?)
            }
            try? db.run(row.update(setters))
        }
    }

    func updateProgress(bookId: Int64, progress: Double, currentPage: Int, accountId: Int64? = nil) {
        guard let aid = accountId else { return }
        ensureAccountBook(accountId: aid, bookId: bookId)
        let row = bookAccountTable.filter(colBAAccountId == aid && colBABookId == bookId)
        var setters: [SQLite.Setter] = [
            colBAProgress <- progress,
            colBACurrentPage <- currentPage,
        ]
        if let existing = try? db.pluck(row), existing[colBAStartedAt] == nil {
            setters.append(colBAStartedAt <- Date().timeIntervalSince1970)
        }
        if progress >= 0.95 {
            setters.append(colBAFinished <- true)
            setters.append(colBAFinishedAt <- Date().timeIntervalSince1970)
        }
        try? db.run(row.update(setters))
    }

    func addReadingTime(bookId: Int64, seconds: Double, accountId: Int64? = nil) {
        guard let aid = accountId, seconds > 0 else { return }
        ensureAccountBook(accountId: aid, bookId: bookId)
        let row = bookAccountTable.filter(colBAAccountId == aid && colBABookId == bookId)
        if let existing = try? db.pluck(row) {
            try? db.run(row.update(colBATotalReadingTime <- existing[colBATotalReadingTime] + seconds))
        }
    }

    // MARK: - Bookmarks

    func bookmarks(forBook bookId: Int64, accountId: Int64? = nil) -> [BookBookmark] {
        var query = bookmarksTable.filter(colBMBookId == bookId)
        if let aid = accountId {
            query = query.filter(colBMAccountId == aid)
        }
        query = query.order(colBMPage.asc)
        guard let rows = try? db.prepare(query) else { return [] }
        return rows.map { row in
            BookBookmark(
                id: row[colBMId],
                bookId: row[colBMBookId],
                page: row[colBMPage],
                note: row[colBMNote],
                createdAt: Date(timeIntervalSince1970: row[colBMCreatedAt])
            )
        }
    }

    func addBookmark(bookId: Int64, page: Int, note: String?, accountId: Int64? = nil) {
        guard let aid = accountId else { return }
        try? db.run(bookmarksTable.insert(
            colBMAccountId <- aid,
            colBMBookId <- bookId,
            colBMPage <- page,
            colBMNote <- note,
            colBMCreatedAt <- Date().timeIntervalSince1970
        ))
    }

    func deleteBookmark(id: Int64) {
        try? db.run(bookmarksTable.filter(colBMId == id).delete())
    }

    // MARK: - Stats

    func bookCount() -> Int {
        (try? db.scalar(booksTable.count)) ?? 0
    }

    func authorCount() -> Int {
        let query = booksTable.select(colAuthor).filter(colAuthor != nil).group(colAuthor)
        return (try? Array(db.prepare(query)).count) ?? 0
    }
}
