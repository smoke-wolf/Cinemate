import SwiftUI

struct GoldButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isFullWidth: Bool = false
    var size: ButtonSize = .regular

    enum ButtonSize {
        case small, regular, large

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 8
            case .regular: return 14
            case .large: return 18
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 13
            case .regular: return 15
            case .large: return 17
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .regular: return 16
            case .large: return 20
            }
        }
    }

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            hapticImpact(.medium)
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: size.fontSize, weight: .bold))
            }
            .foregroundStyle(Color.black)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, isFullWidth ? 0 : 24)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(Theme.goldGradient)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))
            .shadow(color: Theme.goldGlow, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(Theme.quickSpring, value: configuration.isPressed)
    }
}

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Theme.primaryGold)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(Theme.primaryGold.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 20) {
            GoldButton(title: "Play Now", icon: "play.fill", action: {}, size: .large)
            GoldButton(title: "Connect", icon: "link", action: {}, isFullWidth: true)
            GoldButton(title: "Small", icon: nil, action: {}, size: .small)
            SecondaryButton(title: "Add to Favorites", icon: "heart", action: {})
        }
        .padding()
    }
}
