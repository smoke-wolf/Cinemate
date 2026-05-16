import Foundation
import SwiftUI

struct Account: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var colorHex: String
    var hasPIN: Bool
    var pinHash: String?
    var useBiometrics: Bool

    var color: Color {
        Color(hex: colorHex)
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case colorHex = "avatar_color"
        case hasPIN = "has_pin"
        case pinHash = "pin_hash"
        case useBiometrics = "use_biometrics"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? c.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try c.decode(String.self, forKey: .id)
        }
        name = try c.decode(String.self, forKey: .name)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#D4A017"
        hasPIN = try c.decodeIfPresent(Bool.self, forKey: .hasPIN) ?? false
        pinHash = try c.decodeIfPresent(String.self, forKey: .pinHash)
        useBiometrics = try c.decodeIfPresent(Bool.self, forKey: .useBiometrics) ?? false
    }

    init(id: String = UUID().uuidString, name: String, colorHex: String = "#D4A017",
         hasPIN: Bool = false, pinHash: String? = nil, useBiometrics: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.hasPIN = hasPIN
        self.pinHash = pinHash
        self.useBiometrics = useBiometrics
    }
}

struct AccountsResponse: Codable {
    let accounts: [Account]
}

struct AccountStats: Codable {
    let accountId: Int
    let accountName: String
    let watchedCount: Int
    let favoritesCount: Int
    let totalWatchTimeSeconds: Double
    let totalWatchTimeHours: Double
    let totalPlays: Int

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case accountName = "account_name"
        case watchedCount = "watched_count"
        case favoritesCount = "favorites_count"
        case totalWatchTimeSeconds = "total_watch_time_seconds"
        case totalWatchTimeHours = "total_watch_time_hours"
        case totalPlays = "total_plays"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accountId = try c.decodeIfPresent(Int.self, forKey: .accountId) ?? 0
        accountName = try c.decodeIfPresent(String.self, forKey: .accountName) ?? ""
        watchedCount = try c.decodeIfPresent(Int.self, forKey: .watchedCount) ?? 0
        favoritesCount = try c.decodeIfPresent(Int.self, forKey: .favoritesCount) ?? 0
        totalWatchTimeSeconds = try c.decodeIfPresent(Double.self, forKey: .totalWatchTimeSeconds) ?? 0
        totalWatchTimeHours = try c.decodeIfPresent(Double.self, forKey: .totalWatchTimeHours) ?? 0
        totalPlays = try c.decodeIfPresent(Int.self, forKey: .totalPlays) ?? 0
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        if hex.count == 6 {
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        } else {
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}
