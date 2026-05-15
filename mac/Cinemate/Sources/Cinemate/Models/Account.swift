import Foundation

struct Account: Identifiable, Hashable {
    let id: Int64
    var name: String
    var avatarColor: String  // hex color like "#FF6B35"
    var hasPin: Bool
    var createdAt: Date

    var initial: String {
        String(name.prefix(1)).uppercased()
    }
}
