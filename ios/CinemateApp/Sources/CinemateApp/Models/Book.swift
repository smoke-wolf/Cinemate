import Foundation

struct Book: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let author: String?
    let genre: String?
    let pageCount: Int
    let format: String
    let filePath: String?
    let fileSize: Int64
    let coverPath: String?
    let description: String?
    let year: Int?
    let dateAdded: String?
    var readingProgress: Double
    var currentPage: Int
    var favorite: Bool
    var finished: Bool

    var progress: Double { readingProgress }

    var readingStatus: ReadingStatus {
        if finished { return .finished }
        if readingProgress > 0 { return .reading }
        return .unread
    }

    var progressDisplay: String {
        guard pageCount > 0 else { return "" }
        return "Page \(currentPage) of \(pageCount)"
    }

    var formatIcon: String {
        switch format.uppercased() {
        case "PDF": return "doc.richtext"
        case "EPUB": return "book"
        default: return "doc"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, author, genre, format, description, year
        case pageCount = "page_count"
        case filePath = "file_path"
        case fileSize = "file_size"
        case coverPath = "cover_path"
        case dateAdded = "date_added"
        case readingProgress = "reading_progress"
        case currentPage = "current_page"
        case favorite, finished
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        author = try c.decodeIfPresent(String.self, forKey: .author)
        genre = try c.decodeIfPresent(String.self, forKey: .genre)
        pageCount = try c.decodeIfPresent(Int.self, forKey: .pageCount) ?? 0
        format = try c.decode(String.self, forKey: .format)
        filePath = try c.decodeIfPresent(String.self, forKey: .filePath)
        fileSize = try c.decodeIfPresent(Int64.self, forKey: .fileSize) ?? 0
        coverPath = try c.decodeIfPresent(String.self, forKey: .coverPath)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        dateAdded = try c.decodeIfPresent(String.self, forKey: .dateAdded)
        readingProgress = try c.decodeIfPresent(Double.self, forKey: .readingProgress) ?? 0
        currentPage = try c.decodeIfPresent(Int.self, forKey: .currentPage) ?? 0
        if let boolVal = try? c.decodeIfPresent(Bool.self, forKey: .favorite) {
            favorite = boolVal
        } else {
            favorite = (try? c.decodeIfPresent(Int.self, forKey: .favorite)).map { $0 != 0 } ?? false
        }
        if let boolVal = try? c.decodeIfPresent(Bool.self, forKey: .finished) {
            finished = boolVal
        } else {
            finished = (try? c.decodeIfPresent(Int.self, forKey: .finished)).map { $0 != 0 } ?? false
        }
    }

    init(id: Int, title: String, author: String?, genre: String?, pageCount: Int,
         format: String, filePath: String?, fileSize: Int64, coverPath: String?,
         description: String?, year: Int?, dateAdded: String?,
         readingProgress: Double, currentPage: Int, favorite: Bool, finished: Bool) {
        self.id = id; self.title = title; self.author = author; self.genre = genre
        self.pageCount = pageCount; self.format = format; self.filePath = filePath
        self.fileSize = fileSize; self.coverPath = coverPath; self.description = description
        self.year = year; self.dateAdded = dateAdded; self.readingProgress = readingProgress
        self.currentPage = currentPage; self.favorite = favorite; self.finished = finished
    }
}

enum ReadingStatus: String {
    case unread = "Unread"
    case reading = "Reading"
    case finished = "Finished"
}

struct BookBookmark: Identifiable, Codable, Hashable {
    let id: Int
    let page: Int
    let note: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, page, note
        case createdAt = "created_at"
    }
}

extension Book {
    static let preview = Book(
        id: 1, title: "Dune", author: "Frank Herbert",
        genre: "Science Fiction", pageCount: 688, format: "PDF",
        filePath: nil, fileSize: 2_500_000, coverPath: nil,
        description: "Set on the desert planet Arrakis, Dune is the story of the boy Paul Atreides, heir to a noble family tasked with ruling an inhospitable world where the only thing of value is the spice melange.",
        year: 1965, dateAdded: nil, readingProgress: 0.34,
        currentPage: 234, favorite: true, finished: false
    )

    static let previewList: [Book] = [
        .preview,
        Book(id: 2, title: "Neuromancer", author: "William Gibson", genre: "Cyberpunk", pageCount: 271, format: "EPUB", filePath: nil, fileSize: 400_000, coverPath: nil, description: nil, year: 1984, dateAdded: nil, readingProgress: 1.0, currentPage: 271, favorite: true, finished: true),
        Book(id: 3, title: "Foundation", author: "Isaac Asimov", genre: "Science Fiction", pageCount: 244, format: "PDF", filePath: nil, fileSize: 1_200_000, coverPath: nil, description: nil, year: 1951, dateAdded: nil, readingProgress: 0, currentPage: 0, favorite: false, finished: false),
    ]
}
