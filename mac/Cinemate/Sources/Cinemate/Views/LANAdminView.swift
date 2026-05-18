import SwiftUI
import Network

// MARK: - Network Interface Model

struct NetworkInterface: Identifiable, Hashable {
    let id: String
    let name: String        // e.g. "en0"
    let ip: String          // e.g. "192.168.1.35"
    let displayName: String // e.g. "Wi-Fi"

    /// Map BSD interface names to human-readable labels
    static func friendlyName(for bsdName: String) -> String {
        switch bsdName {
        case "en0": return "Wi-Fi"
        case "en1": return "Ethernet"
        case "en2": return "Ethernet 2"
        case "en3": return "Thunderbolt Bridge"
        case "en4": return "USB Ethernet"
        case "en5": return "Thunderbolt Ethernet"
        case "bridge0": return "Bridge"
        case "awdl0": return "AWDL"
        case "llw0": return "Low Latency WLAN"
        case "utun0", "utun1", "utun2", "utun3": return "VPN Tunnel"
        default:
            if bsdName.hasPrefix("en") { return "Ethernet" }
            if bsdName.hasPrefix("utun") { return "VPN Tunnel" }
            if bsdName.hasPrefix("bridge") { return "Bridge" }
            return bsdName
        }
    }
}

// MARK: - Network Section Picker

enum NetworkSection: String, CaseIterable {
    case lan = "LAN"
    case wan = "WAN"
}

struct LANAdminView: View {
    @ObservedObject var viewModel: LibraryViewModel

    @State private var selectedSection: NetworkSection = .lan
    @State private var serverName = "Cinemate Server"
    @State private var serverPort = "9876"
    @State private var hostname = "Detecting..."
    @State private var networkInterfaces: [NetworkInterface] = []
    @State private var primaryIP = "Detecting..."
    @State private var uptime = "0m"
    @State private var allowAllDevices = true
    @State private var requirePINForNewConnections = false
    @State private var allowedIPs: [String] = []
    @State private var newIPAddress = ""
    @State private var connectedClients: [LANClient] = []
    @State private var pingLatency: String = "--"
    @State private var startTime = Date()
    @State private var connectionPIN = ""
    @State private var pinSaved = false
    @State private var serverProcess: Process? = nil
    @State private var serverRunning = false
    @State private var serverLog: [String] = []
    @State private var showLog = false
    @State private var serverStarting = false
    @State private var clientPollTimer: Timer?
    @State private var uptimeTimer: Timer?
    @State private var copiedURL: String? = nil
    @State private var showQRCode = false
    @State private var qrURL = ""

    private let accentGold = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let warmAmber = Color(red: 0.93, green: 0.76, blue: 0.20)
    private let cardBg = Color(white: 0.11)
    private let cardBorder = Color.white.opacity(0.06)

    var body: some View {
        VStack(spacing: 0) {
            // Section picker
            networkSectionPicker
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 8)

            // Content based on selected section
            switch selectedSection {
            case .lan:
                lanContent
            case .wan:
                WANSettingsView(viewModel: viewModel)
            }
        }
        .background(Color(white: 0.1))
        .onAppear {
            detectHostname()
            detectAllInterfaces()
            startTime = Date()
            startUptimeTimer()
            checkServerRunning()
            fetchConnectedClients()
            clientPollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
                fetchConnectedClients()
            }
        }
        .onDisappear {
            clientPollTimer?.invalidate()
            uptimeTimer?.invalidate()
        }
    }

    // MARK: - Network Section Picker

    private var networkSectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(NetworkSection.allCases, id: \.self) { section in
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedSection = section } }) {
                    Text(section.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selectedSection == section ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedSection == section ? accentGold : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
        )
        .frame(maxWidth: 280)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - LAN Content

    private var lanContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                serverControlCard
                if serverRunning && !networkInterfaces.isEmpty {
                    networkAddressesCard
                }
                connectedClientsCard
                accessControlCard
                serverInfoCard
            }
            .padding(32)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [accentGold.opacity(0.2), accentGold.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: "network")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [warmAmber, accentGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("LAN Admin")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Text("Server management and access control")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    if hostname != "Detecting..." {
                        Text("·")
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.5))
                        Text(hostname)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: - Server Control Card

    private var serverControlCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Server")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                statusBadge
            }

            HStack(spacing: 20) {
                // Big status circle
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.1))
                        .frame(width: 80, height: 80)
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 60, height: 60)

                    if serverStarting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(accentGold)
                    } else {
                        Image(systemName: serverRunning ? "checkmark.circle.fill" : "power")
                            .font(.system(size: 26))
                            .foregroundColor(statusColor)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    // Primary URL
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Primary URL")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                            if serverRunning {
                                let url = "http://\(primaryIP):\(serverPort)"
                                HStack(spacing: 6) {
                                    Text(url)
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white)
                                        .textSelection(.enabled)
                                    Button(action: { copyURL(url) }) {
                                        Image(systemName: copiedURL == url ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: 10))
                                            .foregroundColor(copiedURL == url ? .green : .gray)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Text(viewModel.serverURL ?? "Not running")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                    .textSelection(.enabled)
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Latency")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                            Text(serverRunning ? pingLatency : "--")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Uptime")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                            Text(serverRunning ? uptime : "--")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mode")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                            Text(viewModel.serverURL != nil ? "Remote" : (serverRunning ? "Local" : "Offline"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }
                        if networkInterfaces.count > 1 {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Interfaces")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.gray)
                                Text("\(networkInterfaces.count)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }

                Spacer()

                // Start/Stop button
                VStack(spacing: 8) {
                    Button(action: {
                        if serverRunning {
                            stopServer()
                        } else if !serverStarting {
                            startServer()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: serverRunning ? "stop.fill" : "play.fill")
                                .font(.system(size: 12))
                            Text(serverStarting ? "Starting..." : (serverRunning ? "Stop Server" : "Start Server"))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(serverRunning ? .white : .black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(serverRunning ? Color.red.opacity(0.8) : accentGold)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(serverStarting)

                    if serverRunning {
                        Button(action: { showLog.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "terminal")
                                    .font(.system(size: 10))
                                Text("Logs")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }

                    if !serverRunning && !serverStarting {
                        Button(action: { showTerminalCommand.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "terminal")
                                    .font(.system(size: 10))
                                Text("Manual Start")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if showTerminalCommand && !serverRunning {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Paste this into Terminal to start the server:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                        Button(action: { showTerminalCommand = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 0) {
                        Text(serverStartCommand())
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.green.opacity(0.9))
                            .textSelection(.enabled)
                            .padding(10)

                        Spacer()

                        Button(action: {
                            copyCommandToClipboard()
                            copiedURL = "terminal_cmd"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                if copiedURL == "terminal_cmd" { copiedURL = nil }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: copiedURL == "terminal_cmd" ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11))
                                Text(copiedURL == "terminal_cmd" ? "Copied!" : "Copy")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(copiedURL == "terminal_cmd" ? .green : accentGold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(copiedURL == "terminal_cmd" ? Color.green.opacity(0.1) : accentGold.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 10)
                    }
                    .background(Color(white: 0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
            }

            if showLog && !serverLog.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Server Log")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                        Spacer()
                        Button("Clear") { serverLog.removeAll() }
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(serverLog.suffix(50).enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.green.opacity(0.8))
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                    .frame(height: 150)
                }
                .background(Color(white: 0.06))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Network Addresses Card

    private var networkAddressesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Network Addresses")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(networkInterfaces.count) interface\(networkInterfaces.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
            }

            Text("Your server is reachable at any of these addresses. Share the appropriate one based on the client's network.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.35))

            VStack(spacing: 2) {
                ForEach(networkInterfaces) { iface in
                    let url = "http://\(iface.ip):\(serverPort)"
                    HStack(spacing: 12) {
                        // Interface icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(interfaceColor(iface.name).opacity(0.1))
                                .frame(width: 36, height: 36)
                            Image(systemName: interfaceIcon(iface.name))
                                .font(.system(size: 14))
                                .foregroundColor(interfaceColor(iface.name))
                        }

                        // Interface details
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(iface.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                Text(iface.name)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.6))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.white.opacity(0.04))
                                    .cornerRadius(4)
                            }
                            Text(url)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(accentGold.opacity(0.9))
                                .textSelection(.enabled)
                        }

                        Spacer()

                        // Action buttons
                        HStack(spacing: 6) {
                            // QR Code button
                            Button(action: {
                                qrURL = url
                                showQRCode.toggle()
                            }) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .padding(7)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            // Copy button
                            Button(action: { copyURL(url) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: copiedURL == url ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 11))
                                    Text(copiedURL == url ? "Copied" : "Copy")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(copiedURL == url ? .green : .gray)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(copiedURL == url ? Color.green.opacity(0.1) : Color.white.opacity(0.06))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(copiedURL == url ? Color.green.opacity(0.2) : Color.white.opacity(0.04), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.02))
                }
            }
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )

            // QR Code section (shown when toggled)
            if showQRCode && !qrURL.isEmpty {
                VStack(spacing: 12) {
                    HStack {
                        Text("Scan to connect")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                        Button(action: { showQRCode = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    QRCodeView(url: qrURL, size: 160)

                    Text(qrURL)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.03))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Connected Clients

    private var connectedClientsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Connected Clients")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(connectedClients.count) active")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
            }

            if connectedClients.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "laptopcomputer.and.arrow.down")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.08))
                    Text("No clients connected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                    Text(serverRunning
                         ? "Devices on your network can connect using any address above"
                         : "Start the server to allow LAN connections")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.15))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 1) {
                    ForEach(connectedClients) { client in
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(activityColor(client.activity).opacity(0.1))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "desktopcomputer")
                                    .font(.system(size: 14))
                                    .foregroundColor(activityColor(client.activity))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.deviceName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                Text(client.ipAddress)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(activityColor(client.activity))
                                    .frame(width: 6, height: 6)
                                Text(client.activity.displayText)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }

                            Button(action: { kickClient(client) }) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.02))
                    }
                }
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Access Control

    private var accessControlCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Access Control")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 0) {
                // Allow all row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow All LAN Devices")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Any device on your local network can connect")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Toggle("", isOn: $allowAllDevices)
                        .toggleStyle(.switch)
                        .tint(accentGold)
                        .labelsHidden()
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.06))

                if !allowAllDevices {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Allowed IPs")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)

                        ForEach(allowedIPs, id: \.self) { ip in
                            HStack {
                                Image(systemName: "checkmark.shield")
                                    .font(.system(size: 11))
                                    .foregroundColor(.green.opacity(0.7))
                                Text(ip)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: { allowedIPs.removeAll { $0 == ip } }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(6)
                        }

                        HStack(spacing: 8) {
                            TextField("192.168.1.x", text: $newIPAddress)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(6)
                                .frame(width: 180)
                                .onSubmit { addIP() }

                            Button("Add") { addIP() }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(accentGold)
                                .cornerRadius(6)
                                .buttonStyle(.plain)
                                .disabled(newIPAddress.isEmpty)
                        }
                    }
                    .padding(14)

                    Divider().background(Color.white.opacity(0.06))
                }

                // PIN row
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Require PIN for New Connections")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("New devices must enter a PIN to access the library")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Toggle("", isOn: $requirePINForNewConnections)
                            .toggleStyle(.switch)
                            .tint(accentGold)
                            .labelsHidden()
                    }
                    .padding(14)

                    if requirePINForNewConnections {
                        Divider().background(Color.white.opacity(0.04)).padding(.horizontal, 14)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Connection PIN")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)

                            HStack(spacing: 10) {
                                SecureField("Enter 4-8 digit PIN", text: $connectionPIN)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(8)
                                    .frame(width: 200)
                                    .onChange(of: connectionPIN) { _, newValue in
                                        connectionPIN = String(newValue.filter(\.isNumber).prefix(8))
                                        pinSaved = false
                                    }

                                Button(action: {
                                    pinSaved = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        pinSaved = false
                                    }
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: pinSaved ? "checkmark" : "square.and.arrow.down")
                                            .font(.system(size: 11))
                                        Text(pinSaved ? "Saved" : "Save")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(pinSaved ? .green : .black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(pinSaved ? Color.green.opacity(0.15) : accentGold)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .disabled(connectionPIN.count < 4)
                            }

                            if !connectionPIN.isEmpty && connectionPIN.count < 4 {
                                Text("PIN must be at least 4 digits")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange.opacity(0.8))
                            }

                            Text("Clients connecting from the LAN will be prompted for this PIN before accessing your library.")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.25))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Server Info

    private var serverInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Server Details")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                infoTile(icon: "server.rack", label: "Name", value: serverName)
                infoTile(icon: "number", label: "Port", value: serverPort)
                infoTile(icon: "desktopcomputer", label: "Hostname", value: hostname)
                infoTile(icon: "clock", label: "Uptime", value: serverRunning ? uptime : "--")
                infoTile(icon: "antenna.radiowaves.left.and.right", label: "Protocol", value: "Bonjour")
                infoTile(icon: "network", label: "Interfaces", value: "\(networkInterfaces.count) active")
            }

            // Show all IPs in a compact list under the grid
            if !networkInterfaces.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bound Addresses")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)

                    ForEach(networkInterfaces) { iface in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(interfaceColor(iface.name))
                                .frame(width: 5, height: 5)
                            Text(iface.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 90, alignment: .leading)
                            Text(iface.ip)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                            Text("(\(iface.name))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    private func infoTile(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(accentGold.opacity(0.6))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(serverStarting ? "Starting" : (serverRunning ? "Running" : "Stopped"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(statusColor.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        if serverStarting { return .orange }
        if serverRunning { return .green }
        return Color(white: 0.4)
    }

    // MARK: - Interface Helpers

    private func interfaceIcon(_ name: String) -> String {
        switch name {
        case "en0": return "wifi"
        case "en1", "en2", "en4", "en5": return "cable.connector"
        case "en3": return "bolt.horizontal"
        case "bridge0": return "arrow.triangle.branch"
        case "awdl0", "llw0": return "antenna.radiowaves.left.and.right"
        default:
            if name.hasPrefix("utun") { return "lock.shield" }
            if name.hasPrefix("en") { return "cable.connector" }
            return "network"
        }
    }

    private func interfaceColor(_ name: String) -> Color {
        switch name {
        case "en0": return .blue
        case "en1", "en2": return .green
        case "en3", "en4", "en5": return .purple
        case "bridge0": return .orange
        case "awdl0", "llw0": return .cyan
        default:
            if name.hasPrefix("utun") { return .pink }
            return accentGold
        }
    }

    // MARK: - Server Process Management

    private func startServer() {
        let serverDir = NSHomeDirectory() + "/cinemate-v3/server"
        let mainPy = serverDir + "/main.py"

        guard FileManager.default.fileExists(atPath: mainPy) else {
            serverLog.append("[error] Server not found at \(serverDir)")
            serverLog.append("[error] Expected main.py at \(mainPy)")
            showLog = true
            return
        }

        serverStarting = true
        showLog = true
        serverLog.append("[info] Starting Cinemate server...")

        let port = serverPort
        let ip = primaryIP

        DispatchQueue.global(qos: .userInitiated).async {
            let killProc = Process()
            killProc.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
            killProc.arguments = ["-ti", ":\(port)"]
            let killPipe = Pipe()
            killProc.standardOutput = killPipe
            killProc.standardError = Pipe()
            try? killProc.run()
            killProc.waitUntilExit()
            let killData = killPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: killData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                for pidStr in output.components(separatedBy: .newlines) {
                    if let pid = Int32(pidStr.trimmingCharacters(in: .whitespaces)) {
                        kill(pid, SIGTERM)
                        DispatchQueue.main.async {
                            self.serverLog.append("[info] Killed existing process on port \(port) (PID \(pid))")
                        }
                    }
                }
                Thread.sleep(forTimeInterval: 0.5)
            }

            let process = Process()
            let pipe = Pipe()

            let venvPython = serverDir + "/venv/bin/python3"
            if FileManager.default.fileExists(atPath: venvPython) {
                process.executableURL = URL(fileURLWithPath: venvPython)
                process.arguments = ["-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", port]
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["python3", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", port]
            }

            process.currentDirectoryURL = URL(fileURLWithPath: serverDir)
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + serverDir + "/venv/bin"
            env["VIRTUAL_ENV"] = serverDir + "/venv"
            env["PYTHONUNBUFFERED"] = "1"
            process.environment = env
            process.standardOutput = pipe
            process.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                DispatchQueue.main.async {
                    for line in str.components(separatedBy: .newlines) where !line.isEmpty {
                        self.serverLog.append(line)
                    }
                }
            }

            process.terminationHandler = { proc in
                let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
                let finalOutput = String(data: remaining, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    self.serverRunning = false
                    self.serverStarting = false
                    self.serverProcess = nil
                    for line in finalOutput.components(separatedBy: .newlines) where !line.isEmpty {
                        self.serverLog.append(line)
                    }
                    if proc.terminationStatus != 0 {
                        self.serverLog.append("[error] Server exited with code \(proc.terminationStatus)")
                    } else {
                        self.serverLog.append("[info] Server stopped (exit code: 0)")
                    }
                    self.showLog = true
                }
            }

            DispatchQueue.main.async {
                self.serverLog.append("[info] Launching: \(process.executableURL?.path ?? "nil") \(process.arguments?.joined(separator: " ") ?? "")")
                self.serverLog.append("[info] Working dir: \(process.currentDirectoryURL?.path ?? "nil")")
            }

            do {
                try process.run()
                DispatchQueue.main.async {
                    self.serverProcess = process
                    self.serverLog.append("[info] Process launched (PID \(process.processIdentifier))")
                }

                let healthURL = URL(string: "http://localhost:\(port)/api/server/info")!
                DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                    self.pollHealth(url: healthURL, ip: ip, port: port, attempts: 0)
                }
            } catch {
                DispatchQueue.main.async {
                    self.serverStarting = false
                    self.serverLog.append("[error] Failed to start: \(error.localizedDescription)")
                    self.showLog = true
                }
            }
        }
    }

    private func pollHealth(url: URL, ip: String, port: String, attempts: Int) {
        guard attempts < 20 else {
            DispatchQueue.main.async {
                self.serverStarting = false
                self.serverLog.append("[error] Server failed to respond after 20 attempts")
                self.showLog = true
            }
            return
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                DispatchQueue.main.async {
                    self.serverStarting = false
                    self.serverRunning = true
                    self.startTime = Date()
                    let serverAddr = "http://\(ip):\(port)"
                    self.viewModel.serverURL = serverAddr
                    self.viewModel.musicViewModel.serverURL = serverAddr
                    self.serverLog.append("[info] Server running on \(serverAddr)")
                    self.pingServer()
                }
            } else {
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                    self.pollHealth(url: url, ip: ip, port: port, attempts: attempts + 1)
                }
            }
        }.resume()
    }

    private func killProcessesOnPort(_ port: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
        proc.arguments = ["-ti", ":\(port)"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else { return }
        for pidStr in output.components(separatedBy: .newlines) {
            if let pid = Int32(pidStr.trimmingCharacters(in: .whitespaces)) {
                kill(pid, SIGTERM)
                DispatchQueue.main.async {
                    self.serverLog.append("[info] Killed existing process on port \(port) (PID \(pid))")
                }
            }
        }
    }

    private func stopServer() {
        serverProcess?.terminate()
        serverProcess = nil
        serverRunning = false
        serverLog.append("[info] Server stopped by user")
        let port = serverPort
        DispatchQueue.global(qos: .userInitiated).async {
            self.killProcessesOnPort(port)
        }
    }

    @State private var showTerminalCommand = false

    private func serverStartCommand() -> String {
        let serverDir = NSHomeDirectory() + "/cinemate-v3/server"
        let venvPython = serverDir + "/venv/bin/python3"
        let port = serverPort

        if FileManager.default.fileExists(atPath: venvPython) {
            return "cd \(serverDir) && source venv/bin/activate && python3 -m uvicorn main:app --host 0.0.0.0 --port \(port)"
        } else {
            return "cd \(serverDir) && python3 -m uvicorn main:app --host 0.0.0.0 --port \(port)"
        }
    }

    private func copyCommandToClipboard() {
        let cmd = serverStartCommand()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
    }

    private func checkServerRunning() {
        let url = URL(string: "http://localhost:\(serverPort)/api/server/info")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    let wasRunning = self.serverRunning
                    self.serverRunning = true
                    if !wasRunning { self.startTime = Date() }
                    let serverAddr = "http://\(self.primaryIP):\(self.serverPort)"
                    self.viewModel.serverURL = serverAddr
                    self.viewModel.musicViewModel.serverURL = serverAddr
                    if self.serverLog.isEmpty {
                        self.serverLog.append("[info] Detected running server on port \(self.serverPort)")
                    }
                }
            }
        }.resume()
    }

    private func fetchConnectedClients() {
        guard serverRunning else { return }
        let url = URL(string: "http://localhost:\(serverPort)/api/sync/devices")!
        URLSession.shared.dataTask(with: url) { data, response, _ in
            guard let data = data,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let devices = json["devices"] as? [[String: Any]] else { return }

            let clients = devices.compactMap { d -> LANClient? in
                guard let id = d["id"] as? String,
                      let name = d["name"] as? String else { return nil }
                let isOnline = (d["is_online"] as? Int ?? 0) == 1
                guard isOnline else { return nil }
                let ip = d["ip_address"] as? String ?? ""
                return LANClient(id: id, deviceName: name, ipAddress: ip, activity: .browsing)
            }
            DispatchQueue.main.async {
                self.connectedClients = clients
            }
        }.resume()
    }

    private func pingServer() {
        guard serverRunning else { return }
        let start = Date()
        let url = URL(string: "http://localhost:\(serverPort)/api/server/info")!
        URLSession.shared.dataTask(with: url) { _, response, _ in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    let ms = Int(Date().timeIntervalSince(start) * 1000)
                    self.pingLatency = "\(ms)ms"
                }
            }
        }.resume()
    }

    // MARK: - Helpers

    private func activityColor(_ activity: LANClient.Activity) -> Color {
        switch activity {
        case .watching: return .green
        case .browsing: return .blue
        case .idle: return .gray
        }
    }

    private func kickClient(_ client: LANClient) {
        connectedClients.removeAll { $0.id == client.id }
    }

    private func addIP() {
        let trimmed = newIPAddress.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !allowedIPs.contains(trimmed) else { return }
        allowedIPs.append(trimmed)
        newIPAddress = ""
    }

    private func copyURL(_ url: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        copiedURL = url
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedURL == url {
                copiedURL = nil
            }
        }
    }

    // MARK: - Network Detection

    private func detectHostname() {
        hostname = ProcessInfo.processInfo.hostName
        // Clean up ".local" suffix for display
        if hostname.hasSuffix(".local") || hostname.hasSuffix(".local.") {
            // Keep it as-is; it's the Bonjour hostname which is useful
        }
    }

    private func detectAllInterfaces() {
        var interfaces: [NetworkInterface] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }

                let family = interface.ifa_addr.pointee.sa_family
                if family == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)

                    // Skip loopback and Apple internal interfaces
                    if name == "lo0" { continue }
                    if name == "awdl0" { continue }
                    if name == "llw0" { continue }
                    if name.hasPrefix("utun") { continue }

                    var hostnameBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostnameBuffer, socklen_t(hostnameBuffer.count), nil, 0, NI_NUMERICHOST
                    )
                    let ip = String(cString: hostnameBuffer)

                    if ip != "127.0.0.1" && !ip.isEmpty {
                        let friendly = NetworkInterface.friendlyName(for: name)
                        interfaces.append(NetworkInterface(
                            id: "\(name)-\(ip)",
                            name: name,
                            ip: ip,
                            displayName: friendly
                        ))
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        // Sort: en0 first, then en1, then others alphabetically
        interfaces.sort { a, b in
            let aOrder = interfaceSortOrder(a.name)
            let bOrder = interfaceSortOrder(b.name)
            if aOrder != bOrder { return aOrder < bOrder }
            return a.name < b.name
        }

        networkInterfaces = interfaces

        // Set primary IP (prefer en0, then en1, then first available)
        if let en0 = interfaces.first(where: { $0.name == "en0" }) {
            primaryIP = en0.ip
        } else if let en1 = interfaces.first(where: { $0.name == "en1" }) {
            primaryIP = en1.ip
        } else if let first = interfaces.first {
            primaryIP = first.ip
        } else {
            primaryIP = "127.0.0.1"
            // Also attempt the UDP socket trick as a last resort
            detectPrimaryIPviaSocket()
        }
    }

    private func interfaceSortOrder(_ name: String) -> Int {
        switch name {
        case "en0": return 0
        case "en1": return 1
        default:
            if name.hasPrefix("en") { return 2 }
            if name.hasPrefix("bridge") { return 3 }
            return 4
        }
    }

    private func detectPrimaryIPviaSocket() {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return }
        defer { close(sock) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(80).bigEndian
        inet_pton(AF_INET, "8.8.8.8", &addr.sin_addr)

        let connected = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connected == 0 else { return }

        var localAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let gotName = withUnsafeMutablePointer(to: &localAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                getsockname(sock, sockPtr, &addrLen)
            }
        }
        guard gotName == 0 else { return }

        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        if let cStr = inet_ntop(AF_INET, &localAddr.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN)) {
            let ip = String(cString: cStr)
            if ip != "0.0.0.0" && ip != "127.0.0.1" {
                primaryIP = ip
            }
        }
    }

    private func startUptimeTimer() {
        uptimeTimer?.invalidate()
        uptimeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            let elapsed = Int(Date().timeIntervalSince(startTime))
            let hours = elapsed / 3600
            let minutes = (elapsed % 3600) / 60
            if hours > 0 {
                uptime = "\(hours)h \(minutes)m"
            } else {
                uptime = "\(minutes)m"
            }
        }
    }
}

// MARK: - LAN Client Model

struct LANClient: Identifiable {
    let id: String
    let deviceName: String
    let ipAddress: String
    let activity: Activity

    enum Activity {
        case watching(String)
        case browsing
        case idle

        var displayText: String {
            switch self {
            case .watching(let title): return "Watching: \(title)"
            case .browsing: return "Browsing"
            case .idle: return "Idle"
            }
        }
    }
}
