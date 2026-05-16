import SwiftUI

struct DevicesView: View {
    @ObservedObject var downloadManager: MacDownloadManager
    let serverURL: String?

    @State private var isRefreshing = false
    @State private var expandedDeviceId: String? = nil

    private let cardBg = Color(white: 0.11)
    private let cardBorder = Color.white.opacity(0.06)
    private let accentTeal = Color(red: 0.2, green: 0.75, blue: 0.7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                if downloadManager.connectedDevices.isEmpty {
                    emptyState
                } else {
                    onlineSection
                    if !offlineDevices.isEmpty {
                        offlineSection
                    }
                }
            }
            .padding(32)
        }
        .background(Color(white: 0.1))
        .onAppear {
            refreshDevices()
        }
    }

    private var onlineDevices: [ConnectedDevice] {
        downloadManager.connectedDevices.filter { $0.isOnline }
    }

    private var offlineDevices: [ConnectedDevice] {
        downloadManager.connectedDevices.filter { !$0.isOnline }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [accentTeal.opacity(0.2), accentTeal.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentTeal, accentTeal.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Devices")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("\(onlineDevices.count) online, \(offlineDevices.count) offline")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            Spacer()

            Button(action: { refreshDevices() }) {
                HStack(spacing: 5) {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(accentTeal)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    Text("Refresh")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "laptopcomputer.trianglebadge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.08))
            Text("No Devices Found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
            Text(serverURL != nil
                 ? "No devices are connected to your Cinemate server.\nOpen Cinemate on another device to get started."
                 : "Connect to a Cinemate server to see other devices on your network."
            )
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.15))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Online Devices

    private var onlineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Online")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(onlineDevices.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(accentTeal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentTeal.opacity(0.1))
                    .cornerRadius(10)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(onlineDevices) { device in
                    deviceCard(device, online: true)
                }
            }
        }
    }

    // MARK: - Offline Devices

    private var offlineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Offline")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(offlineDevices.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(offlineDevices) { device in
                    deviceCard(device, online: false)
                }
            }
        }
    }

    // MARK: - Device Card

    private func deviceCard(_ device: ConnectedDevice, online: Bool) -> some View {
        let isExpanded = expandedDeviceId == device.id
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedDeviceId = expandedDeviceId == device.id ? nil : device.id
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Device icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(online ? accentTeal.opacity(0.1) : Color.white.opacity(0.04))
                            .frame(width: 44, height: 44)
                        Image(systemName: device.deviceIcon)
                            .font(.system(size: 18))
                            .foregroundColor(online ? accentTeal : .gray)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(device.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(online ? .white : .gray)
                                .lineLimit(1)

                            // Online dot
                            Circle()
                                .fill(online ? .green : Color(white: 0.3))
                                .frame(width: 8, height: 8)
                        }

                        Text(device.deviceType.capitalized)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }

                if isExpanded {
                    Divider().background(Color.white.opacity(0.06))

                    VStack(alignment: .leading, spacing: 8) {
                        deviceInfoRow(icon: "clock", label: "Last Seen", value: device.lastSeenFormatted)
                        deviceInfoRow(icon: "antenna.radiowaves.left.and.right", label: "Status", value: online ? "Connected" : "Disconnected")

                        if online {
                            HStack(spacing: 8) {
                                Button(action: {
                                    // Future: sync library with device
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 10))
                                        Text("Sync")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundColor(accentTeal)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(accentTeal.opacity(0.1))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(online ? accentTeal.opacity(0.15) : cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func deviceInfoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Helpers

    private func refreshDevices() {
        guard let url = serverURL else { return }
        isRefreshing = true
        downloadManager.refreshDevices(serverURL: url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isRefreshing = false
        }
    }
}
