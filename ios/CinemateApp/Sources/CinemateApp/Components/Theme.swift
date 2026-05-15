import SwiftUI

enum Theme {
    // MARK: - Colors
    static let background = Color(hex: "#0A0A0F")
    static let cardSurface = Color(hex: "#1A1A1A")
    static let elevatedSurface = Color(hex: "#242424")
    static let primaryGold = Color(hex: "#D4A017")
    static let warmAmber = Color(hex: "#ECBF3B")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#9CA3AF")
    static let textTertiary = Color(hex: "#6B7280")
    static let success = Color(hex: "#22C55E")
    static let error = Color(hex: "#EF4444")
    static let warning = Color(hex: "#F97316")

    // MARK: - Gradients
    static let goldGradient = LinearGradient(
        colors: [primaryGold, warmAmber],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let darkGradient = LinearGradient(
        colors: [Color(hex: "#1A1A1A"), Color(hex: "#0A0A0F")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardGradient = LinearGradient(
        colors: [Color(hex: "#242424"), Color(hex: "#1A1A1A")],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Animations
    static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let quickSpring = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let gentleSpring = Animation.spring(response: 0.5, dampingFraction: 0.75)

    // MARK: - Shadows
    static let cardShadow = Color.black.opacity(0.3)
    static let goldGlow = Color(hex: "#D4A017").opacity(0.4)

    // MARK: - Corner Radii
    static let cornerSmall: CGFloat = 8
    static let cornerMedium: CGFloat = 12
    static let cornerLarge: CGFloat = 16
    static let cornerXL: CGFloat = 20
}
