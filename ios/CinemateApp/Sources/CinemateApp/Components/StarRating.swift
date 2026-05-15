import SwiftUI

struct StarRating: View {
    let rating: Double // 0-5 scale
    var size: CGFloat = 12
    var color: Color = Theme.warmAmber

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                let starValue = Double(index) + 1
                Image(systemName: starIcon(for: starValue))
                    .font(.system(size: size))
                    .foregroundStyle(starValue <= rating ? color : Theme.textTertiary.opacity(0.3))
            }
        }
    }

    private func starIcon(for value: Double) -> String {
        if value <= rating {
            return "star.fill"
        } else if value - 0.5 <= rating {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

struct RatingDisplay: View {
    let rating: Double? // 0-10 scale

    var body: some View {
        if let rating = rating {
            HStack(spacing: 6) {
                StarRating(rating: rating / 2.0)
                Text(String(format: "%.1f", rating))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.warmAmber)
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 16) {
            StarRating(rating: 4.5)
            StarRating(rating: 3.0, size: 16, color: Theme.primaryGold)
            RatingDisplay(rating: 8.8)
            RatingDisplay(rating: 6.5)
        }
    }
}
