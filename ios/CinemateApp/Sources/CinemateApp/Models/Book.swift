import Foundation

struct Book: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let author: String
    let genre: String?
    let pageCount: Int?
    let format: BookFormat
    let coverURL: String?
    let fileURL: String?
    let description: String?
    var currentPage: Int
    var isFinished: Bool
    var isFavorite: Bool
    var bookmarks: [BookBookmark]
    let dateAdded: Date?

    var progress: Double {
        guard let total = pageCount, total > 0 else { return 0 }
        return Double(currentPage) / Double(total)
    }

    var readingStatus: ReadingStatus {
        if isFinished { return .finished }
        if currentPage > 0 { return .reading }
        return .unread
    }

    var progressDisplay: String {
        guard let total = pageCount else { return "" }
        return "Page \(currentPage) of \(total)"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, author, genre, format, description, bookmarks
        case pageCount = "page_count"
        case coverURL = "cover_url"
        case fileURL = "file_url"
        case currentPage = "current_page"
        case isFinished = "is_finished"
        case isFavorite = "is_favorite"
        case dateAdded = "date_added"
    }
}

enum BookFormat: String, Codable, Hashable {
    case pdf = "PDF"
    case epub = "EPUB"

    var icon: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .epub: return "book"
        }
    }
}

enum ReadingStatus: String {
    case unread = "Unread"
    case reading = "Reading"
    case finished = "Finished"
}

struct BookBookmark: Identifiable, Codable, Hashable {
    let id: String
    let page: Int
    let title: String?
    let dateCreated: Date

    enum CodingKeys: String, CodingKey {
        case id, page, title
        case dateCreated = "date_created"
    }
}

extension Book {
    static let preview = Book(
        id: "b1", title: "Dune", author: "Frank Herbert",
        genre: "Science Fiction", pageCount: 688, format: .pdf,
        coverURL: nil, fileURL: "/api/books/b1/file",
        description: "Set on the desert planet Arrakis, Dune is the story of the boy Paul Atreides, heir to a noble family tasked with ruling an inhospitable world where the only thing of value is the spice melange.",
        currentPage: 234, isFinished: false, isFavorite: true,
        bookmarks: [
            BookBookmark(id: "bm1", page: 45, title: "The Spice", dateCreated: Date()),
            BookBookmark(id: "bm2", page: 120, title: "Arrakis", dateCreated: Date()),
        ],
        dateAdded: Date()
    )

    static let previewList: [Book] = [
        .preview,
        Book(id: "b2", title: "Neuromancer", author: "William Gibson", genre: "Cyberpunk", pageCount: 271, format: .epub, coverURL: nil, fileURL: nil, description: "The sky above the port was the color of television, tuned to a dead channel.", currentPage: 271, isFinished: true, isFavorite: true, bookmarks: [], dateAdded: Date()),
        Book(id: "b3", title: "Foundation", author: "Isaac Asimov", genre: "Science Fiction", pageCount: 244, format: .pdf, coverURL: nil, fileURL: nil, description: "A band of psychologists determine that the Galactic Empire will fall in 500 years.", currentPage: 0, isFinished: false, isFavorite: false, bookmarks: [], dateAdded: Date()),
        Book(id: "b4", title: "1984", author: "George Orwell", genre: "Dystopian", pageCount: 328, format: .pdf, coverURL: nil, fileURL: nil, description: "A startling and haunting novel, 1984 creates an imaginary world that is completely convincing.", currentPage: 165, isFinished: false, isFavorite: false, bookmarks: [], dateAdded: Date()),
    ]
}
