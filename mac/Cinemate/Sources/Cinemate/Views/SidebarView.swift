import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: LibraryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CINEMATE")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)

            ForEach(LibraryViewModel.Tab.allCases, id: \.self) { tab in
                // Hide Devices tab when no devices are connected
                if tab == .devices && viewModel.downloadManager.connectedDevices.isEmpty {
                    EmptyView()
                } else {
                    SidebarButton(
                        title: tab.rawValue,
                        icon: icon(for: tab),
                        isSelected: viewModel.currentTab == tab,
                        badge: badgeCount(for: tab)
                    ) {
                        viewModel.currentTab = tab
                    }
                }
            }

            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.vertical, 12)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 6) {
                Text("Library")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)

                HStack(spacing: 6) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 11))
                    Text("\(viewModel.movies.count) movies")
                }
                .font(.system(size: 12))
                .foregroundColor(.gray)

                if !viewModel.shows.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "tv")
                            .font(.system(size: 11))
                        Text("\(viewModel.shows.count) shows")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                }

                if !viewModel.musicViewModel.tracks.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note")
                            .font(.system(size: 11))
                        Text("\(viewModel.musicViewModel.tracks.count) tracks")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                }

                if !viewModel.bookViewModel.books.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 11))
                        Text("\(viewModel.bookViewModel.books.count) books")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                }

                if viewModel.totalWatchTime > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                        Text("\(viewModel.totalWatchTimeFormatted) watched")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Current account indicator
            if let account = viewModel.currentAccount {
                HStack(spacing: 8) {
                    Circle()
                        .fill(colorFromHex(account.avatarColor))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text(account.initial)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        )
                    Text(account.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.orange)
                        Text("Scanning... \(viewModel.scanProgress)")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 16)
                }

                Divider()
                    .background(Color.gray.opacity(0.2))
                    .padding(.horizontal, 16)

                // Scan + Sort row
                HStack(spacing: 0) {
                    Button(action: {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        panel.message = "Select your movies folder"
                        if panel.runModal() == .OK, let url = panel.url {
                            viewModel.scan(directory: url.path)
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 11))
                            Text("Scan")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(action: { viewModel.sort(by: option) }) {
                                HStack {
                                    Text(option.rawValue)
                                    if viewModel.sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 9))
                            Text(viewModel.sortOption.rawValue)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding(.horizontal, 12)

                // Quality filter — two rows of 2 for clean layout
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        qualityChip("All", filter: nil)
                        qualityChip("4K", filter: "4K")
                    }
                    HStack(spacing: 6) {
                        qualityChip("1080p", filter: "1080p")
                        qualityChip("720p", filter: "720p")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 200)
        .background(Color(white: 0.06))
    }

    private func qualityChip(_ label: String, filter: String?) -> some View {
        let isActive = viewModel.qualityFilter == filter
        return Button(action: {
            viewModel.qualityFilter = filter
            if viewModel.currentTab != .browse {
                viewModel.currentTab = .browse
            }
        }) {
            Text(label)
                .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                .foregroundColor(isActive ? .black : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.orange : Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    private func icon(for tab: LibraryViewModel.Tab) -> String {
        switch tab {
        case .browse: return "square.grid.2x2"
        case .tvShows: return "tv"
        case .music: return "music.note"
        case .books: return "book.closed"
        case .favorites: return "heart.fill"
        case .recent: return "clock"
        case .downloads: return "arrow.down.circle"
        case .devices: return "laptopcomputer.and.iphone"
        case .lanAdmin: return "network"
        case .profile: return "person.circle"
        case .settings: return "gearshape"
        }
    }

    private func badgeCount(for tab: LibraryViewModel.Tab) -> Int {
        switch tab {
        case .downloads:
            return viewModel.downloadManager.activeDownloads.count
        default:
            return 0
        }
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var badge: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                        )
                }
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}
