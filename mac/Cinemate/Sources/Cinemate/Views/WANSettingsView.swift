import SwiftUI

// MARK: - Data Models

enum TunnelType: String, CaseIterable, Identifiable {
    case ngrok = "ngrok"
    case cloudflared = "cloudflared"
    case customDomain = "Custom Domain"

    var id: String { rawValue }
}

enum TunnelStatus: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"

    var color: Color {
        switch self {
        case .disconnected: return Color(white: 0.4)
        case .connecting: return .orange
        case .connected: return .green
        }
    }

    var icon: String {
        switch self {
        case .disconnected: return "circle.fill"
        case .connecting: return "circle.fill"
        case .connected: return "circle.fill"
        }
    }
}

enum WANRegion: String, CaseIterable, Identifiable {
    case us = "us"
    case eu = "eu"
    case ap = "ap"
    case au = "au"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .us: return "US"
        case .eu: return "Europe"
        case .ap: return "Asia Pacific"
        case .au: return "Australia"
        }
    }
}

struct WANSession: Identifiable {
    let id: String
    let deviceOrIP: String
    let createdAt: Date
}

struct WANLoginAttempt: Identifiable {
    let id: String
    let ip: String
    let timestamp: Date
    let success: Bool
}

// MARK: - Main View

struct WANSettingsView: View {
    @ObservedObject var viewModel: LibraryViewModel

    // -- Tunnel Management --
    @State private var wanEnabled = false
    @State private var tunnelType: TunnelType = .ngrok
    @State private var tunnelStatus: TunnelStatus = .disconnected
    @State private var publicURL = ""
    @State private var tunnelUptime = "--"
    @State private var dataTransferred = "--"
    @State private var tunnelStartTime: Date? = nil

    // ngrok fields
    @State private var ngrokAuthToken = ""
    @State private var ngrokRegion: WANRegion = .us
    @State private var ngrokReservedDomain = ""

    // cloudflared fields
    @State private var cloudflaredUseFreeTunnel = true
    @State private var cloudflaredTunnelName = ""
    @State private var cloudflaredCredentialsPath = ""
    @State private var tunnelProcess: Process?

    // Custom Domain fields
    @State private var customDomainURL = ""
    @State private var sslCertPath = ""
    @State private var sslKeyPath = ""

    // -- Admin Authentication --
    @State private var adminPasswordSet = false
    @State private var adminPassword = ""
    @State private var adminPasswordConfirm = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var newPasswordConfirm = ""
    @State private var passwordSaved = false
    @State private var passwordError = ""
    @State private var activeSessions: [WANSession] = []
    @State private var loginAttempts: [WANLoginAttempt] = []

    // -- Security Settings --
    @State private var requireAuthForWAN = true
    @State private var enableRateLimiting = false
    @State private var rateLimitPerMinute = "60"
    @State private var enableRequestLogging = true
    @State private var blockedIPs: [String] = []
    @State private var newBlockedIP = ""
    @State private var autoStopOnQuit = true

    // -- Domain Configuration --
    @State private var testConnectionResult: String? = nil
    @State private var testingConnection = false

    // -- Timer --
    @State private var uptimeTimer: Timer? = nil

    // -- Theme --
    private let accentGold = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let warmAmber = Color(red: 0.93, green: 0.76, blue: 0.20)
    private let cardBg = Color(white: 0.11)
    private let cardBorder = Color.white.opacity(0.06)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                // Security warning when WAN is enabled without a password
                if wanEnabled && !adminPasswordSet {
                    wanSecurityWarning
                }

                tunnelManagementCard
                adminAuthenticationCard
                securitySettingsCard
                domainConfigurationCard
            }
            .padding(32)
        }
        .background(Color(white: 0.1))
        .onAppear { startUptimeTimer() }
        .onDisappear { uptimeTimer?.invalidate() }
    }

    // MARK: - Security Warning Banner

    private var wanSecurityWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 3) {
                Text("Admin password not set")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.orange)
                Text("WAN access is enabled but no admin password has been configured. Anyone with the tunnel URL can access your server. Set a password below to secure remote access.")
                    .font(.system(size: 12))
                    .foregroundColor(.orange.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                )
        )
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
                Image(systemName: "globe")
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
                Text("WAN Settings")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Text("Internet access, tunnels, and remote security")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            Spacer()

            // Quick status indicators
            if wanEnabled {
                HStack(spacing: 12) {
                    if adminPasswordSet {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text("Secured")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }

                    if enableRateLimiting {
                        HStack(spacing: 4) {
                            Image(systemName: "gauge.with.dots.needle.33percent")
                                .font(.system(size: 10))
                                .foregroundColor(accentGold)
                            Text("Rate Limited")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(accentGold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accentGold.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Tunnel Management Card

    private var tunnelManagementCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tunnel Management")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                tunnelStatusBadge
            }

            // Master switch
            toggleRow(
                title: "Enable WAN Access",
                subtitle: "Expose your Cinemate server to the internet via a secure tunnel",
                isOn: $wanEnabled
            )

            if wanEnabled {
                Divider().background(Color.white.opacity(0.06))

                // Tunnel type picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tunnel Provider")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)

                    Picker("", selection: $tunnelType) {
                        ForEach(TunnelType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(.horizontal, 14)

                // Provider-specific fields
                Group {
                    switch tunnelType {
                    case .ngrok:
                        ngrokFields
                    case .cloudflared:
                        cloudflaredFields
                    case .customDomain:
                        customDomainFields
                    }
                }
                .padding(.horizontal, 14)

                Divider().background(Color.white.opacity(0.06))

                // Start / Stop tunnel
                HStack(spacing: 16) {
                    Button(action: {
                        if tunnelStatus == .connected {
                            stopTunnel()
                        } else {
                            startTunnel()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: tunnelStatus == .connected ? "stop.fill" : "bolt.fill")
                                .font(.system(size: 13))
                            Text(tunnelButtonLabel)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(tunnelStatus == .connected ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(tunnelStatus == .connected ? Color.red.opacity(0.8) : accentGold)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(tunnelStatus == .connecting)
                }
                .padding(.horizontal, 14)

                // Status display (when connected)
                if tunnelStatus == .connected && !publicURL.isEmpty {
                    Divider().background(Color.white.opacity(0.06))
                    tunnelStatusDisplay
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    // MARK: - ngrok Fields

    private var ngrokFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldRow(label: "Auth Token", placeholder: "Enter ngrok auth token", text: $ngrokAuthToken, isSecure: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Region")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Picker("", selection: $ngrokRegion) {
                    ForEach(WANRegion.allCases) { region in
                        Text(region.displayName).tag(region)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            fieldRow(label: "Reserved Domain (optional)", placeholder: "myapp.ngrok.io", text: $ngrokReservedDomain)
        }
    }

    // MARK: - cloudflared Fields

    private var cloudflaredFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            toggleRow(
                title: "Free Quick Tunnel",
                subtitle: "No account or credentials needed — Cloudflare assigns a random .trycloudflare.com URL",
                isOn: $cloudflaredUseFreeTunnel
            )

            if !cloudflaredUseFreeTunnel {
                fieldRow(label: "Tunnel Name", placeholder: "cinemate-tunnel", text: $cloudflaredTunnelName)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Credentials File")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    HStack(spacing: 8) {
                        TextField("~/.cloudflared/credentials.json", text: $cloudflaredCredentialsPath)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)

                        Button(action: { pickFile(for: .cloudflaredCredentials) }) {
                            Image(systemName: "folder")
                                .font(.system(size: 13))
                                .foregroundColor(accentGold)
                                .padding(8)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Custom Domain Fields

    private var customDomainFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldRow(label: "Domain URL", placeholder: "https://cinema.example.com", text: $customDomainURL)

            VStack(alignment: .leading, spacing: 4) {
                Text("SSL Certificate")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    TextField("/path/to/cert.pem", text: $sslCertPath)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)

                    Button(action: { pickFile(for: .sslCert) }) {
                        Image(systemName: "folder")
                            .font(.system(size: 13))
                            .foregroundColor(accentGold)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("SSL Private Key")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    TextField("/path/to/key.pem", text: $sslKeyPath)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)

                    Button(action: { pickFile(for: .sslKey) }) {
                        Image(systemName: "folder")
                            .font(.system(size: 13))
                            .foregroundColor(accentGold)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Tunnel Status Display

    private var tunnelStatusDisplay: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Public URL row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Public URL")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    Text(publicURL)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(accentGold)
                        .textSelection(.enabled)
                }
                Spacer()
                Button(action: { copyToClipboard(publicURL) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            // Stats row
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Uptime")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    Text(tunnelUptime)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Data Transferred")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    Text(dataTransferred)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Provider")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    Text(tunnelType.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
            }

            // QR code
            VStack(alignment: .center, spacing: 8) {
                Text("Scan to connect from your phone")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                QRCodeView(url: publicURL, size: 140)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
        .padding(.horizontal, 14)
    }

    // MARK: - Admin Authentication Card

    private var adminAuthenticationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Admin Authentication")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 0) {
                if !adminPasswordSet {
                    // First-time setup
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Set Admin Password")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Required to manage your server over WAN connections")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)

                        fieldRow(label: "Password", placeholder: "Enter password", text: $adminPassword, isSecure: true)
                        fieldRow(label: "Confirm Password", placeholder: "Confirm password", text: $adminPasswordConfirm, isSecure: true)

                        if !passwordError.isEmpty {
                            Text(passwordError)
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }

                        HStack {
                            Spacer()
                            Button(action: { saveNewPassword() }) {
                                HStack(spacing: 5) {
                                    Image(systemName: passwordSaved ? "checkmark" : "lock.shield")
                                        .font(.system(size: 11))
                                    Text(passwordSaved ? "Saved" : "Set Password")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(passwordSaved ? .green : .black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(passwordSaved ? Color.green.opacity(0.15) : accentGold)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(adminPassword.isEmpty || adminPasswordConfirm.isEmpty)
                        }
                    }
                    .padding(14)
                } else {
                    // Change password
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.green)
                            Text("Admin password is set")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }

                        fieldRow(label: "Current Password", placeholder: "Enter current password", text: $currentPassword, isSecure: true)
                        fieldRow(label: "New Password", placeholder: "Enter new password", text: $newPassword, isSecure: true)
                        fieldRow(label: "Confirm New Password", placeholder: "Confirm new password", text: $newPasswordConfirm, isSecure: true)

                        if !passwordError.isEmpty {
                            Text(passwordError)
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }

                        HStack {
                            Spacer()
                            Button(action: { changePassword() }) {
                                HStack(spacing: 5) {
                                    Image(systemName: passwordSaved ? "checkmark" : "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11))
                                    Text(passwordSaved ? "Updated" : "Change Password")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(passwordSaved ? .green : .black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(passwordSaved ? Color.green.opacity(0.15) : accentGold)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(currentPassword.isEmpty || newPassword.isEmpty || newPasswordConfirm.isEmpty)
                        }
                    }
                    .padding(14)
                }

                Divider().background(Color.white.opacity(0.06))

                // Active sessions
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Active Sessions")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(activeSessions.count) active")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }

                    if activeSessions.isEmpty {
                        Text("No active sessions")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.25))
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 1) {
                            ForEach(activeSessions) { session in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(session.deviceOrIP)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                        Text(formatDate(session.createdAt))
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Button(action: { revokeSession(session) }) {
                                        Text("Revoke")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.red.opacity(0.1))
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.02))
                            }
                        }
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                        )
                    }
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.06))

                // Login attempt history
                VStack(alignment: .leading, spacing: 10) {
                    Text("Login History (last 10)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)

                    if loginAttempts.isEmpty {
                        Text("No login attempts recorded")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.25))
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 1) {
                            ForEach(loginAttempts.prefix(10)) { attempt in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(attempt.success ? Color.green : Color.red)
                                        .frame(width: 6, height: 6)
                                    Text(attempt.ip)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(attempt.success ? "Success" : "Failed")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(attempt.success ? .green : .red)
                                    Text(formatDate(attempt.timestamp))
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.02))
                            }
                        }
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                        )
                    }
                }
                .padding(14)
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .padding(20)
        .background(cardBackground)
    }

    // MARK: - Security Settings Card

    private var securitySettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Security")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 0) {
                toggleRow(
                    title: "Require Authentication for All WAN Requests",
                    subtitle: "Every request from the internet must include valid credentials",
                    isOn: $requireAuthForWAN
                )

                Divider().background(Color.white.opacity(0.06))

                // Rate limiting row
                VStack(spacing: 0) {
                    toggleRow(
                        title: "Enable Rate Limiting",
                        subtitle: "Throttle incoming requests to prevent abuse",
                        isOn: $enableRateLimiting
                    )

                    if enableRateLimiting {
                        HStack(spacing: 8) {
                            Text("Max requests per minute:")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            TextField("60", text: $rateLimitPerMinute)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)
                                .frame(width: 80)
                                .onChange(of: rateLimitPerMinute) { _, newValue in
                                    rateLimitPerMinute = String(newValue.filter(\.isNumber).prefix(5))
                                }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                    }
                }

                Divider().background(Color.white.opacity(0.06))

                toggleRow(
                    title: "Enable Request Logging",
                    subtitle: "Log all incoming WAN requests for auditing",
                    isOn: $enableRequestLogging
                )

                Divider().background(Color.white.opacity(0.06))

                toggleRow(
                    title: "Auto-Stop Tunnel on App Quit",
                    subtitle: "Automatically close the tunnel when Cinemate exits",
                    isOn: $autoStopOnQuit
                )

                Divider().background(Color.white.opacity(0.06))

                // IP Blocklist
                VStack(alignment: .leading, spacing: 10) {
                    Text("IP Blocklist")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Text("Blocked IPs will be denied access to your server")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)

                    if !blockedIPs.isEmpty {
                        VStack(spacing: 2) {
                            ForEach(blockedIPs, id: \.self) { ip in
                                HStack {
                                    Image(systemName: "xmark.shield")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red.opacity(0.7))
                                    Text(ip)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button(action: { blockedIPs.removeAll { $0 == ip } }) {
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
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("IP address to block", text: $newBlockedIP)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                            .frame(width: 200)
                            .onSubmit { addBlockedIP() }

                        Button(action: { addBlockedIP() }) {
                            Text("Block")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.7))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(newBlockedIP.isEmpty)
                    }
                }
                .padding(14)
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .padding(20)
        .background(cardBackground)
    }

    // MARK: - Domain Configuration Card

    private var domainConfigurationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Domain Configuration")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(sslStatusColor)
                        .frame(width: 7, height: 7)
                    Text(sslStatusText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(sslStatusColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(sslStatusColor.opacity(0.1))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(sslStatusColor.opacity(0.2), lineWidth: 1)
                )
            }

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    fieldRow(label: "Custom Domain", placeholder: "cinema.example.com", text: $customDomainURL)

                    // DNS hint when using tunnel providers
                    if tunnelStatus == .connected && !publicURL.isEmpty && !customDomainURL.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DNS Configuration")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray)
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(accentGold.opacity(0.6))
                                Text("Point a CNAME record for")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(customDomainURL)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                                Text("to your tunnel URL")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                    }

                    // Test Connection button + result
                    HStack(spacing: 12) {
                        if let result = testConnectionResult {
                            HStack(spacing: 6) {
                                Image(systemName: result.contains("Success") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(result.contains("Success") ? .green : .red)
                                Text(result)
                                    .font(.system(size: 11))
                                    .foregroundColor(result.contains("Success") ? .green : .red)
                            }
                        }

                        Spacer()

                        Button(action: { testConnection() }) {
                            HStack(spacing: 6) {
                                if testingConnection {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(accentGold)
                                } else {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.system(size: 12))
                                }
                                Text(testingConnection ? "Testing..." : "Test Connection")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(accentGold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(accentGold.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(testingConnection || publicURL.isEmpty)
                    }
                }
                .padding(14)
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .padding(20)
        .background(cardBackground)
    }

    // MARK: - Reusable Components

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(cardBg)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(cardBorder, lineWidth: 1)
            )
    }

    private var tunnelStatusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tunnelStatus.color)
                .frame(width: 7, height: 7)
            Text(tunnelStatus.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(tunnelStatus.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tunnelStatus.color.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tunnelStatus.color.opacity(0.2), lineWidth: 1)
        )
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .tint(accentGold)
                .labelsHidden()
        }
        .padding(14)
    }

    private func fieldRow(label: String, placeholder: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundColor(.white)
            .padding(8)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
        }
    }

    private var tunnelButtonLabel: String {
        switch tunnelStatus {
        case .disconnected: return "Start Tunnel"
        case .connecting: return "Connecting..."
        case .connected: return "Stop Tunnel"
        }
    }

    private var sslStatusColor: Color {
        if !sslCertPath.isEmpty && !sslKeyPath.isEmpty { return .green }
        if tunnelType == .ngrok || tunnelType == .cloudflared { return .green }
        return Color(white: 0.4)
    }

    private var sslStatusText: String {
        if tunnelType == .ngrok || tunnelType == .cloudflared { return "Provided by \(tunnelType.rawValue)" }
        if !sslCertPath.isEmpty && !sslKeyPath.isEmpty { return "Certificate configured" }
        return "Not configured"
    }

    // MARK: - Actions

    private func startTunnel() {
        tunnelStatus = .connecting

        if tunnelType == .cloudflared {
            startCloudflaredTunnel()
            return
        }

        // Other tunnel types (simulated for now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            tunnelStatus = .connected
            tunnelStartTime = Date()
            switch tunnelType {
            case .ngrok:
                publicURL = ngrokReservedDomain.isEmpty
                    ? "https://abc123.ngrok-free.app"
                    : "https://\(ngrokReservedDomain)"
            case .customDomain:
                publicURL = customDomainURL.hasPrefix("http") ? customDomainURL : "https://\(customDomainURL)"
            default:
                break
            }
            dataTransferred = "0 B"
        }
    }

    private func startCloudflaredTunnel() {
        let port: String = {
            if let urlStr = viewModel.serverURL, let url = URL(string: urlStr), let p = url.port {
                return "\(p)"
            }
            return "9876"
        }()
        let process = Process()
        let pipe = Pipe()

        // Find cloudflared binary
        let possiblePaths = [
            "/opt/homebrew/bin/cloudflared",
            "/usr/local/bin/cloudflared",
            "/usr/bin/cloudflared",
        ]
        guard let cfPath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            tunnelStatus = .disconnected
            publicURL = ""
            return
        }

        process.executableURL = URL(fileURLWithPath: cfPath)

        if cloudflaredUseFreeTunnel {
            process.arguments = ["tunnel", "--url", "http://localhost:\(port)"]
        } else {
            var args = ["tunnel"]
            if !cloudflaredCredentialsPath.isEmpty {
                args += ["--credentials-file", cloudflaredCredentialsPath]
            }
            args += ["run"]
            if !cloudflaredTunnelName.isEmpty {
                args.append(cloudflaredTunnelName)
            }
            process.arguments = args
        }

        process.standardOutput = pipe
        process.standardError = pipe

        tunnelProcess = process

        // Read output to find the assigned URL
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
            } catch {
                DispatchQueue.main.async {
                    self.tunnelStatus = .disconnected
                }
                return
            }

            let handle = pipe.fileHandleForReading
            var accumulated = ""

            handle.readabilityHandler = { fh in
                let data = fh.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }
                if let str = String(data: data, encoding: .utf8) {
                    accumulated += str
                    // cloudflared prints the URL like: https://xxx-yyy-zzz.trycloudflare.com
                    for line in str.components(separatedBy: .newlines) {
                        if let range = line.range(of: "https://[a-zA-Z0-9-]+\\.trycloudflare\\.com", options: .regularExpression) {
                            let url = String(line[range])
                            DispatchQueue.main.async {
                                self.publicURL = url
                                self.tunnelStatus = .connected
                                self.tunnelStartTime = Date()
                                self.dataTransferred = "0 B"
                            }
                            return
                        }
                    }
                }
            }
        }

        // Timeout — if we don't get a URL within 30s, mark as failed
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if self.tunnelStatus == .connecting {
                self.stopTunnel()
            }
        }
    }

    private func stopTunnel() {
        if let proc = tunnelProcess, proc.isRunning {
            proc.terminate()
        }
        tunnelProcess = nil
        tunnelStatus = .disconnected
        publicURL = ""
        tunnelStartTime = nil
        tunnelUptime = "--"
        dataTransferred = "--"
    }

    private func saveNewPassword() {
        passwordError = ""
        guard adminPassword == adminPasswordConfirm else {
            passwordError = "Passwords do not match"
            return
        }
        guard adminPassword.count >= 8 else {
            passwordError = "Password must be at least 8 characters"
            return
        }
        adminPasswordSet = true
        passwordSaved = true
        adminPassword = ""
        adminPasswordConfirm = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { passwordSaved = false }
    }

    private func changePassword() {
        passwordError = ""
        guard newPassword == newPasswordConfirm else {
            passwordError = "New passwords do not match"
            return
        }
        guard newPassword.count >= 8 else {
            passwordError = "Password must be at least 8 characters"
            return
        }
        // In production, verify currentPassword against stored hash
        passwordSaved = true
        currentPassword = ""
        newPassword = ""
        newPasswordConfirm = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { passwordSaved = false }
    }

    private func revokeSession(_ session: WANSession) {
        activeSessions.removeAll { $0.id == session.id }
    }

    private func addBlockedIP() {
        let trimmed = newBlockedIP.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !blockedIPs.contains(trimmed) else { return }
        blockedIPs.append(trimmed)
        newBlockedIP = ""
    }

    private func testConnection() {
        guard !publicURL.isEmpty else { return }
        testingConnection = true
        testConnectionResult = nil

        guard let url = URL(string: publicURL) else {
            testConnectionResult = "Invalid URL"
            testingConnection = false
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                testingConnection = false
                if let http = response as? HTTPURLResponse {
                    testConnectionResult = "Success (\(http.statusCode))"
                } else if let error = error {
                    testConnectionResult = "Failed: \(error.localizedDescription)"
                } else {
                    testConnectionResult = "Failed: No response"
                }
            }
        }.resume()
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private enum FilePickTarget {
        case cloudflaredCredentials
        case sslCert
        case sslKey
    }

    private func pickFile(for target: FilePickTarget) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        switch target {
        case .cloudflaredCredentials:
            panel.title = "Select Cloudflared Credentials"
            panel.allowedContentTypes = [.json]
        case .sslCert:
            panel.title = "Select SSL Certificate"
        case .sslKey:
            panel.title = "Select SSL Private Key"
        }

        if panel.runModal() == .OK, let url = panel.url {
            switch target {
            case .cloudflaredCredentials:
                cloudflaredCredentialsPath = url.path
            case .sslCert:
                sslCertPath = url.path
            case .sslKey:
                sslKeyPath = url.path
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func startUptimeTimer() {
        uptimeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            guard let start = tunnelStartTime else {
                tunnelUptime = "--"
                return
            }
            let elapsed = Int(Date().timeIntervalSince(start))
            let hours = elapsed / 3600
            let minutes = (elapsed % 3600) / 60
            if hours > 0 {
                tunnelUptime = "\(hours)h \(minutes)m"
            } else {
                tunnelUptime = "\(minutes)m"
            }
        }
    }
}
