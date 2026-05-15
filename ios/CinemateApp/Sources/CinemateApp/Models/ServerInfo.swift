import Foundation

struct ServerInfo: Identifiable, Codable, Hashable {
    var id: String { url }
    let name: String
    let url: String
    let port: Int
    var isOnline: Bool = false

    var displayURL: String {
        if port == 80 || port == 443 {
            return url
        }
        return "\(url):\(port)"
    }

    var baseURL: URL? {
        URL(string: url.hasPrefix("http") ? url : "http://\(url):\(port)")
    }
}

struct ServerStatus: Codable {
    let name: String
    let version: String
    let mediaCount: Int?
    let uptime: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case name, version
        case mediaCount = "media_count"
        case uptime
    }
}
