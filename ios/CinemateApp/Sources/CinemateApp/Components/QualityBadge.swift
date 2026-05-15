import SwiftUI

struct QualityBadge: View {
    let quality: String

    private var qualityType: QualityType {
        QualityType(rawValue: quality) ?? .unknown
    }

    var body: some View {
        Text(quality)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(hex: qualityType.badgeColor))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct FormatBadge: View {
    let format: String

    var body: some View {
        Text(format)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        HStack(spacing: 8) {
            QualityBadge(quality: "4K")
            QualityBadge(quality: "1080p")
            QualityBadge(quality: "720p")
            QualityBadge(quality: "480p")
            FormatBadge(format: "PDF")
        }
    }
}
