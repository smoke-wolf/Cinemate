import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: LibraryViewModel
    let onSwitchProfile: () -> Void

    private let genreColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink, .teal, .cyan, .mint,
        .indigo, .brown, Color(red: 1.0, green: 0.4, blue: 0.4), Color(red: 0.4, green: 0.8, blue: 0.4),
        Color(red: 0.4, green: 0.4, blue: 1.0), Color(red: 0.9, green: 0.6, blue: 0.2)
    ]

    private let qualityColors: [String: Color] = [
        "4K": .purple,
        "1080p": .blue,
        "720p": .teal,
        "Other": .gray
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                headerSection
                watchStatsSection
                genreBreakdownSection
                qualityDistributionSection
                topRatedSection
                recentlyWatchedSection
                favoriteGenresSection
            }
            .padding(32)
        }
        .background(Color(white: 0.1))
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            if let account = viewModel.currentAccount {
                // Account avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [colorFromHex(account.avatarColor), colorFromHex(account.avatarColor).opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: colorFromHex(account.avatarColor).opacity(0.3), radius: 8)

                    Text(account.initial)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Your viewing stats and tastes")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Profile")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Your viewing stats and tastes")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // Switch Profile / Sign Out buttons
            VStack(spacing: 8) {
                Button(action: onSwitchProfile) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                        Text("Switch Profile")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: onSwitchProfile) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 12))
                        Text("Sign Out")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.red.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.06))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Watch Stats

    private var watchStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Watch Stats")

            HStack(spacing: 20) {
                statCard(
                    icon: "film.fill",
                    value: "\(viewModel.watchedMovieCount)",
                    label: "Movies Watched",
                    color: .orange
                )
                statCard(
                    icon: "clock.fill",
                    value: viewModel.totalWatchTimeFormatted,
                    label: "Total Watch Time",
                    color: .blue
                )
                statCard(
                    icon: "star.fill",
                    value: viewModel.averageRating.map { "\($0)%" } ?? "--",
                    label: "Avg Rating (Watched)",
                    color: .yellow
                )
                statCard(
                    icon: "square.stack.fill",
                    value: "\(viewModel.movies.count)",
                    label: "Total in Library",
                    color: .green
                )
            }
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(white: 0.15))
        .cornerRadius(12)
    }

    // MARK: - Genre Breakdown

    private var genreBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Genre Breakdown")

            if viewModel.genreBreakdown.isEmpty {
                emptyState("No genre data available")
            } else {
                let maxCount = viewModel.genreBreakdown.first?.total ?? 1
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.genreBreakdown.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 12) {
                            Text(item.genre)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 100, alignment: .trailing)

                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(white: 0.2))
                                    .frame(height: 20)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(genreColors[index % genreColors.count].opacity(0.3))
                                    .frame(width: barWidth(count: item.total, max: maxCount), height: 20)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(genreColors[index % genreColors.count])
                                    .frame(width: barWidth(count: item.watched, max: maxCount), height: 20)
                            }
                            .frame(maxWidth: .infinity)

                            Text("\(item.watched)/\(item.total)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.gray)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }

                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 12, height: 12)
                        Text("Watched")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 12, height: 12)
                        Text("Total")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func barWidth(count: Int, max: Int) -> CGFloat {
        guard max > 0 else { return 0 }
        return CGFloat(count) / CGFloat(max) * 400
    }

    // MARK: - Quality Distribution

    private var qualityDistributionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Quality Distribution")

            if viewModel.qualityBreakdown.isEmpty {
                emptyState("No quality data available")
            } else {
                let total = viewModel.qualityBreakdown.reduce(0) { $0 + $1.count }

                HStack(spacing: 24) {
                    // Pie-chart-like ring
                    ZStack {
                        ForEach(Array(pieSlices().enumerated()), id: \.offset) { _, slice in
                            PieSlice(startAngle: slice.start, endAngle: slice.end)
                                .fill(slice.color)
                        }
                        Circle()
                            .fill(Color(white: 0.1))
                            .padding(24)
                        VStack(spacing: 2) {
                            Text("\(total)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("total")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 160, height: 160)

                    // Legend
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.qualityBreakdown, id: \.quality) { item in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(qualityColors[item.quality] ?? .gray)
                                    .frame(width: 12, height: 12)
                                Text(item.quality)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(item.count)")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white)
                                let pct = total > 0 ? Int(Double(item.count) / Double(total) * 100) : 0
                                Text("(\(pct)%)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
                .background(Color(white: 0.15))
                .cornerRadius(12)
            }
        }
    }

    private struct SliceData {
        let start: Angle
        let end: Angle
        let color: Color
    }

    private func pieSlices() -> [SliceData] {
        let total = viewModel.qualityBreakdown.reduce(0) { $0 + $1.count }
        guard total > 0 else { return [] }
        var slices: [SliceData] = []
        var current = Angle.degrees(-90)
        for item in viewModel.qualityBreakdown {
            let sweep = Angle.degrees(Double(item.count) / Double(total) * 360)
            let end = current + sweep
            slices.append(SliceData(
                start: current,
                end: end,
                color: qualityColors[item.quality] ?? .gray
            ))
            current = end
        }
        return slices
    }

    // MARK: - Top Rated

    private var topRatedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Top Rated in Library")

            if viewModel.topRatedMovies.isEmpty {
                emptyState("No rated movies in library")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.topRatedMovies.enumerated()), id: \.element.id) { index, movie in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                                .frame(width: 24, alignment: .trailing)

                            Text(movie.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            if let year = movie.year {
                                Text("(\(String(year)))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            if movie.watched {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                            }

                            if let rating = movie.rating {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.yellow)
                                    Text("\(rating)%")
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(white: 0.2))
                                .cornerRadius(6)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(index % 2 == 0 ? Color(white: 0.13) : Color.clear)
                    }
                }
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(white: 0.2), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Recently Watched

    private var recentlyWatchedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Recently Watched")

            if viewModel.recentlyWatchedMovies.isEmpty {
                emptyState("No watched movies yet")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.recentlyWatchedMovies.enumerated()), id: \.element.id) { index, movie in
                        HStack(spacing: 12) {
                            Text(movie.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            if let year = movie.year {
                                Text("(\(String(year)))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            if !movie.totalWatchTimeFormatted.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                        .foregroundColor(.blue)
                                    Text(movie.totalWatchTimeFormatted)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            }

                            if let lastPlayed = movie.lastPlayed {
                                Text(lastPlayed, style: .relative)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.gray.opacity(0.7))
                                    .frame(width: 90, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(index % 2 == 0 ? Color(white: 0.13) : Color.clear)
                    }
                }
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(white: 0.2), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Favorite Genres

    private var favoriteGenresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Favorite Genres")

            let watchedGenres = viewModel.genreBreakdown
                .filter { $0.watched > 0 }
                .sorted { $0.watched > $1.watched }
                .prefix(3)

            if watchedGenres.isEmpty {
                emptyState("Watch some movies to see your taste profile")
            } else {
                HStack(spacing: 16) {
                    ForEach(Array(watchedGenres.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(genreColors[viewModel.genreBreakdown.firstIndex(where: { $0.genre == item.genre }) ?? index].opacity(0.2))
                                    .frame(width: 72, height: 72)
                                Circle()
                                    .stroke(genreColors[viewModel.genreBreakdown.firstIndex(where: { $0.genre == item.genre }) ?? index], lineWidth: 3)
                                    .frame(width: 72, height: 72)
                                Text("#\(index + 1)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Text(item.genre)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("\(item.watched) watched")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(white: 0.15))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundColor(.gray)
            .padding(.vertical, 12)
    }
}

// MARK: - Pie Slice Shape

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}
