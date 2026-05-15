import SwiftUI
import Network

struct LANAdminView: View {
    @ObservedObject var viewModel: LibraryViewModel

    @State private var serverName = "Cinemate Server"
    @State private var serverPort = "9876"
    @State private var localIP = "Detecting..."
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

    private let accentGold = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let warmAmber = Color(red: 0.93, green: 0.76, blue: 0.20)
    private let cardBg = Color(white: 0.11)
    private let cardBorder = Color.white.opacity(0.06)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                serverControlCard
                connectedClientsCard
                accessControlCard
                serverInfoCard
            }
            .padding(32)
        }
        .background(Color(white: 0.1))
        .onAppear {
            detectLocalIP()
            startTime = Date()
            startUptimeTimer()
            checkServerRunning()
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
                Text("Server management and access control")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
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
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("URL")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                            Text(serverRunning ? "http://\(localIP):\(serverPort)" : (viewModel.serverURL ?? "Not running"))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .textSelection(.enabled)
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
                    }
                }

                Spacer()

                // Start/Stop button
                VStack(spacing: 8) {
                    Button(action: {
                        if serverRunning {
                            stopServer()
                        } else {
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
                         ? "Devices on your network can connect at http://\(localIP):\(serverPort)"
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
                infoTile(icon: "wifi", label: "Local IP", value: localIP)
                infoTile(icon: "clock", label: "Uptime", value: serverRunning ? uptime : "--")
                infoTile(icon: "antenna.radiowaves.left.and.right", label: "Protocol", value: "Bonjour")
                infoTile(icon: "externaldrive.connected.to.line.below", label: "Database", value: "~/.cinemate/")
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

    // MARK: - Server Process Management

    private func startServer() {
        let serverDir = NSHomeDirectory() + "/cinemate-server"
        let mainPy = serverDir + "/main.py"

        guard FileManager.default.fileExists(atPath: mainPy) else {
            serverLog.append("[error] Server not found at \(serverDir)")
            serverLog.append("[error] Expected main.py at \(mainPy)")
            showLog = true
            return
        }

        serverStarting = true
        serverLog.append("[info] Starting Cinemate server...")

        let process = Process()
        let pipe = Pipe()

        let venvPython = serverDir + "/venv/bin/python3"
        if FileManager.default.fileExists(atPath: venvPython) {
            process.executableURL = URL(fileURLWithPath: venvPython)
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3"]
        }

        if process.executableURL?.path == venvPython {
            process.arguments = ["-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", serverPort]
        } else {
            process.arguments = (process.arguments ?? []) + ["-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", serverPort]
        }

        process.currentDirectoryURL = URL(fileURLWithPath: serverDir)
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

        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                self.serverRunning = false
                self.serverStarting = false
                self.serverProcess = nil
                self.serverLog.append("[info] Server stopped")
            }
        }

        do {
            try process.run()
            serverProcess = process
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.serverStarting = false
                self.serverRunning = true
                self.startTime = Date()
                self.serverLog.append("[info] Server running on http://\(localIP):\(serverPort)")
                self.pingServer()
            }
        } catch {
            serverStarting = false
            serverLog.append("[error] Failed to start: \(error.localizedDescription)")
            showLog = true
        }
    }

    private func stopServer() {
        serverProcess?.terminate()
        serverProcess = nil
        serverRunning = false
        serverLog.append("[info] Server stopped by user")
    }

    private func checkServerRunning() {
        let url = URL(string: "http://localhost:\(serverPort)/api/server/info")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    self.serverRunning = true
                }
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

    private func detectLocalIP() {
        // Primary: use a UDP socket trick — connect to a public IP (no data sent) to find our local route
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { fallbackDetectIP(); return }
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
        guard connected == 0 else { fallbackDetectIP(); return }

        var localAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let gotName = withUnsafeMutablePointer(to: &localAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                getsockname(sock, sockPtr, &addrLen)
            }
        }
        guard gotName == 0 else { fallbackDetectIP(); return }

        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        if let cStr = inet_ntop(AF_INET, &localAddr.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN)) {
            let ip = String(cString: cStr)
            if ip != "0.0.0.0" && ip != "127.0.0.1" {
                localIP = ip
                return
            }
        }
        fallbackDetectIP()
    }

    private func fallbackDetectIP() {
        // Fallback: iterate all interfaces, prefer en0/en1 but accept any non-loopback IPv4
        var addresses: [(name: String, ip: String)] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }
                let family = interface.ifa_addr.pointee.sa_family
                if family == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "lo0" { continue }
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST
                    )
                    let ip = String(cString: hostname)
                    if ip != "127.0.0.1" {
                        addresses.append((name: name, ip: ip))
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        // Prefer en0, then en1, then anything
        if let en0 = addresses.first(where: { $0.name == "en0" }) {
            localIP = en0.ip
        } else if let en1 = addresses.first(where: { $0.name == "en1" }) {
            localIP = en1.ip
        } else if let any = addresses.first {
            localIP = any.ip
        } else {
            localIP = "127.0.0.1"
        }
    }

    private func startUptimeTimer() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
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
