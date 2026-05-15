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

struct AccountStats: Codable {
    let moviesWatched: Int
    let totalWatchTime: TimeInterval
    let averageRating: Double
    let tracksPlayed: Int
    let listeningTime: TimeInterval
    let booksRead: Int
    let pagesRead: Int
    let favoriteGenres: [String]
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
