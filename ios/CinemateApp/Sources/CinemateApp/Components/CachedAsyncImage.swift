import SwiftUI

struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: () -> Placeholder

    @State private var imageData: Data?
    @State private var isLoading = true

    init(url: URL?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
    }

    private func makeImage(_ img: PlatformImage) -> Image {
        #if os(iOS)
        return Image(uiImage: img)
        #else
        return Image(nsImage: img)
        #endif
    }

    var body: some View {
        Group {
            if let data = imageData, let platformImage = PlatformImage(data: data) {
                makeImage(platformImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url = url else {
                isLoading = false
                return
            }
            imageData = await ImageCacheService.shared.image(for: url)
            isLoading = false
        }
    }
}

struct MediaPlaceholder: View {
    let icon: String
    var aspectRatio: CGFloat = 16.0 / 9.0

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Theme.cardSurface, Theme.elevatedSurface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.textTertiary)
            }
    }
}

struct AlbumArtPlaceholder: View {
    var size: CGFloat = 60

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.cornerSmall)
            .fill(
                LinearGradient(
                    colors: [Theme.cardSurface, Theme.elevatedSurface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.35))
                    .foregroundStyle(Theme.textTertiary)
            }
    }
}

struct BookCoverPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#2A1810"), Color(hex: "#1A1A1A")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.primaryGold.opacity(0.5))
                    Rectangle()
                        .fill(Theme.primaryGold.opacity(0.2))
                        .frame(width: 40, height: 2)
                }
            }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 16) {
            MediaPlaceholder(icon: "film")
                .frame(width: 200, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            AlbumArtPlaceholder(size: 80)

            BookCoverPlaceholder()
                .frame(width: 120, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
