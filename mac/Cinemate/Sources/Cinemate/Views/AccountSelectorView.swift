import SwiftUI

struct AccountSelectorView: View {
    let onAccountSelected: (Account) -> Void
    var onChangeServer: (() -> Void)? = nil

    @State private var accounts: [Account] = []
    @State private var showCreateSheet = false
    @State private var showManageMode = false
    @State private var editingAccount: Account? = nil
    @State private var pinEntryAccount: Account? = nil
    @State private var pinInput = ""
    @State private var pinError = false
    @State private var hoveredAccountId: Int64? = nil
    @State private var hoveredAddProfile = false
    @FocusState private var pinFieldFocused: Bool

    private let accentGold = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let warmAmber = Color(red: 0.93, green: 0.76, blue: 0.20)
    private let richBlack = Color(red: 0.04, green: 0.04, blue: 0.06)

    var body: some View {
        ZStack {
            // Background
            richBlack.ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.10, green: 0.08, blue: 0.04).opacity(0.6),
                    richBlack
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 600
            )
            .ignoresSafeArea()

            // Film grain
            FilmGrainOverlay()
                .opacity(0.02)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Title
                VStack(spacing: 12) {
                    HStack(spacing: 3) {
                        ForEach(Array("CINEMATE".enumerated()), id: \.offset) { _, char in
                            Text(String(char))
                                .font(.system(size: 32, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [warmAmber, accentGold],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                    .shadow(color: accentGold.opacity(0.4), radius: 12)

                    Text("Who's Watching?")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(1)
                }
                .padding(.bottom, 48)

                // Account grid
                let columns = gridColumns(for: accounts.count + 1)
                LazyVGrid(columns: columns, spacing: 32) {
                    ForEach(accounts) { account in
                        accountCard(account: account)
                    }

                    // Add Profile card
                    addProfileCard
                }
                .padding(.horizontal, 80)
                .frame(maxWidth: 900)

                Spacer()

                // Bottom buttons
                HStack(spacing: 16) {
                    if !accounts.isEmpty {
                        Button(action: { showManageMode.toggle() }) {
                            Text(showManageMode ? "Done" : "Manage Profiles")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(accentGold.opacity(0.8))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(accentGold.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    if let onChangeServer {
                        Button(action: onChangeServer) {
                            HStack(spacing: 6) {
                                Image(systemName: "server.rack")
                                    .font(.system(size: 11))
                                Text("Change Server")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 40)
            }

            // PIN overlay
            if let account = pinEntryAccount {
                pinEntryOverlay(for: account)
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateAccountSheet(onCreated: { account in
                accounts = Database.shared.allAccounts()
                showCreateSheet = false
            })
        }
        .sheet(item: $editingAccount) { account in
            EditAccountSheet(account: account, onSaved: {
                accounts = Database.shared.allAccounts()
                editingAccount = nil
            }, onDeleted: {
                accounts = Database.shared.allAccounts()
                editingAccount = nil
            })
        }
        .onAppear {
            accounts = Database.shared.allAccounts()
            // If no accounts exist, auto-create a default one
            if accounts.isEmpty {
                if let defaultAccount = Database.shared.createAccount(
                    name: "Default",
                    avatarColor: "#D4A017"
                ) {
                    accounts = [defaultAccount]
                }
            }
        }
    }

    // MARK: - Account Card

    private func accountCard(account: Account) -> some View {
        let isHovered = hoveredAccountId == account.id
        let color = colorFromHex(account.avatarColor)

        return Button(action: {
            if showManageMode {
                editingAccount = account
            } else if account.hasPin {
                pinEntryAccount = account
                pinInput = ""
                pinError = false
            } else {
                onAccountSelected(account)
            }
        }) {
            VStack(spacing: 14) {
                ZStack {
                    // Glow ring on hover
                    Circle()
                        .fill(color.opacity(isHovered ? 0.25 : 0))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)

                    // Avatar circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: color.opacity(isHovered ? 0.6 : 0.2), radius: isHovered ? 16 : 4)

                    Text(account.initial)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    // PIN lock indicator
                    if account.hasPin {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(5)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                        .frame(width: 96, height: 96)
                    }

                    // Edit overlay in manage mode
                    if showManageMode {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 96, height: 96)

                        Image(systemName: "pencil")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }

                Text(account.name)
                    .font(.system(size: 15, weight: isHovered ? .semibold : .medium))
                    .foregroundColor(isHovered ? .white : .white.opacity(0.7))
                    .lineLimit(1)
            }
            .scaleEffect(isHovered ? 1.08 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            hoveredAccountId = hovered ? account.id : nil
        }
    }

    // MARK: - Add Profile Card

    private var addProfileCard: some View {
        Button(action: { showCreateSheet = true }) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(hoveredAddProfile ? 0.15 : 0))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)

                    Circle()
                        .stroke(Color.white.opacity(hoveredAddProfile ? 0.5 : 0.2), lineWidth: 2)
                        .frame(width: 96, height: 96)

                    Image(systemName: "plus")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(Color.white.opacity(hoveredAddProfile ? 0.8 : 0.4))
                }

                Text("Add Profile")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.white.opacity(hoveredAddProfile ? 0.8 : 0.5))
            }
            .scaleEffect(hoveredAddProfile ? 1.08 : 1.0)
            .animation(.easeOut(duration: 0.2), value: hoveredAddProfile)
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            hoveredAddProfile = hovered
        }
    }

    // MARK: - PIN Entry Overlay

    private func pinEntryOverlay(for account: Account) -> some View {
        let color = colorFromHex(account.avatarColor)

        return ZStack {
            // Fully opaque background — no bleed-through
            richBlack.ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.03).opacity(0.8),
                    richBlack
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()

            FilmGrainOverlay()
                .opacity(0.02)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Avatar with glow
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 130, height: 130)
                        .blur(radius: 30)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: color.opacity(0.4), radius: 16)

                    Text(account.initial)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(5)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .frame(width: 96, height: 96)
                }
                .padding(.bottom, 20)

                Text(account.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.bottom, 32)

                // PIN card
                VStack(spacing: 20) {
                    Text("Enter PIN")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.5))

                    // PIN dots — larger, in rounded rect containers
                    HStack(spacing: 16) {
                        ForEach(0..<4, id: \.self) { i in
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(width: 48, height: 56)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                i < pinInput.count
                                                    ? accentGold.opacity(0.6)
                                                    : Color.white.opacity(0.1),
                                                lineWidth: 1.5
                                            )
                                    )

                                if i < pinInput.count {
                                    Circle()
                                        .fill(accentGold)
                                        .frame(width: 12, height: 12)
                                        .shadow(color: accentGold.opacity(0.5), radius: 4)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pinInput.count)
                        }
                    }

                    if pinError {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                            Text("Incorrect PIN")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(Color(red: 1, green: 0.35, blue: 0.35))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.vertical, 28)
                .padding(.horizontal, 36)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.08, green: 0.08, blue: 0.10))
                        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )

                // Offscreen text field for PIN capture — gets forced focus
                TextField("", text: $pinInput)
                    .textFieldStyle(.plain)
                    .focused($pinFieldFocused)
                    .frame(width: 0, height: 0)
                    .offset(y: -9999)
                    .allowsHitTesting(false)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            pinFieldFocused = true
                        }
                    }
                    .onChange(of: pinInput) { _, newValue in
                        let filtered = String(newValue.filter(\.isNumber).prefix(4))
                        if filtered != newValue {
                            pinInput = filtered
                        }
                        if filtered.count == 4 {
                            if Database.shared.verifyPin(accountId: account.id, pin: filtered) {
                                pinEntryAccount = nil
                                onAccountSelected(account)
                            } else {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    pinError = true
                                }
                                pinInput = ""
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    pinFieldFocused = true
                                }
                            }
                        } else {
                            pinError = false
                        }
                    }

                Spacer()

                // Cancel button
                Button(action: { withAnimation(.easeOut(duration: 0.2)) { pinEntryAccount = nil } }) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(accentGold.opacity(0.7))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(accentGold.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 60)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Helpers

    private func gridColumns(for count: Int) -> [GridItem] {
        let itemCount = min(count, 4)
        return Array(repeating: GridItem(.fixed(140), spacing: 24), count: max(itemCount, 2))
    }
}

// MARK: - Create Account Sheet

struct CreateAccountSheet: View {
    let onCreated: (Account) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedColor = "#D4A017"
    @State private var usePIN = false
    @State private var pin = ""

    private let presetColors: [(String, String)] = [
        ("#E53935", "Red"),
        ("#FF6B35", "Orange"),
        ("#D4A017", "Gold"),
        ("#43A047", "Green"),
        ("#1E88E5", "Blue"),
        ("#7B1FA2", "Purple"),
        ("#E91E90", "Pink"),
        ("#00897B", "Teal"),
        ("#6D4C41", "Brown"),
        ("#546E7A", "Slate"),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text("Create Profile")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            // Preview avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [colorFromHex(selectedColor), colorFromHex(selectedColor).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: colorFromHex(selectedColor).opacity(0.4), radius: 12)

                Text(name.isEmpty ? "?" : String(name.prefix(1)).uppercased())
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            // Name field
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                TextField("Enter name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
            }

            // Color picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Avatar Color")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 10), count: 5), spacing: 10) {
                    ForEach(presetColors, id: \.0) { hex, _ in
                        Button(action: { selectedColor = hex }) {
                            ZStack {
                                Circle()
                                    .fill(colorFromHex(hex))
                                    .frame(width: 36, height: 36)
                                if selectedColor == hex {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // PIN toggle
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Require PIN", isOn: $usePIN)
                    .toggleStyle(.switch)
                    .tint(Color(red: 0.85, green: 0.65, blue: 0.13))
                    .font(.system(size: 14))
                    .foregroundColor(.white)

                if usePIN {
                    HStack(spacing: 4) {
                        Text("4-digit PIN:")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        SecureField("", text: $pin)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .frame(width: 80)
                            .padding(6)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                            .onChange(of: pin) { _, newValue in
                                pin = String(newValue.filter(\.isNumber).prefix(4))
                            }
                    }
                }
            }

            Spacer()

            // Buttons
            HStack(spacing: 16) {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .buttonStyle(.plain)

                Button("Create") {
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let pinValue = usePIN && pin.count == 4 ? pin : nil
                    guard let account = Database.shared.createAccount(
                        name: name.trimmingCharacters(in: .whitespaces),
                        avatarColor: selectedColor,
                        pin: pinValue
                    ) else { return }
                    onCreated(account)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(
                    name.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.gray
                        : Color(red: 0.85, green: 0.65, blue: 0.13)
                )
                .cornerRadius(8)
                .buttonStyle(.plain)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(32)
        .frame(width: 380, height: 520)
        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
        .preferredColorScheme(.dark)
    }
}

// MARK: - Edit Account Sheet

struct EditAccountSheet: View {
    let account: Account
    let onSaved: () -> Void
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedColor: String = ""
    @State private var showDeleteConfirm = false

    private let presetColors: [(String, String)] = [
        ("#E53935", "Red"),
        ("#FF6B35", "Orange"),
        ("#D4A017", "Gold"),
        ("#43A047", "Green"),
        ("#1E88E5", "Blue"),
        ("#7B1FA2", "Purple"),
        ("#E91E90", "Pink"),
        ("#00897B", "Teal"),
        ("#6D4C41", "Brown"),
        ("#546E7A", "Slate"),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text("Edit Profile")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            // Preview avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [colorFromHex(selectedColor), colorFromHex(selectedColor).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Text(name.isEmpty ? "?" : String(name.prefix(1)).uppercased())
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            // Name
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                TextField("Enter name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
            }

            // Color
            VStack(alignment: .leading, spacing: 8) {
                Text("Avatar Color")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 10), count: 5), spacing: 10) {
                    ForEach(presetColors, id: \.0) { hex, _ in
                        Button(action: { selectedColor = hex }) {
                            ZStack {
                                Circle()
                                    .fill(colorFromHex(hex))
                                    .frame(width: 36, height: 36)
                                if selectedColor == hex {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            HStack(spacing: 16) {
                Button(action: { showDeleteConfirm = true }) {
                    Text("Delete Profile")
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Cancel") { dismiss() }
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .buttonStyle(.plain)

                Button("Save") {
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    Database.shared.updateAccount(
                        id: account.id,
                        name: name.trimmingCharacters(in: .whitespaces),
                        avatarColor: selectedColor
                    )
                    onSaved()
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color(red: 0.85, green: 0.65, blue: 0.13))
                .cornerRadius(8)
                .buttonStyle(.plain)
            }
        }
        .padding(32)
        .frame(width: 380, height: 460)
        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
        .preferredColorScheme(.dark)
        .onAppear {
            name = account.name
            selectedColor = account.avatarColor
        }
        .alert("Delete Profile?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Database.shared.deleteAccount(id: account.id)
                onDeleted()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete \"\(account.name)\" and all their watch history.")
        }
    }
}

// MARK: - Film Grain Overlay

private struct FilmGrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            for _ in 0..<200 {
                let x = Double.random(in: 0..<size.width)
                let y = Double.random(in: 0..<size.height)
                let brightness = Double.random(in: 0.3...1.0)
                let rect = CGRect(x: x, y: y, width: 1, height: 1)
                context.opacity = brightness
                context.fill(Rectangle().path(in: rect), with: .color(.white))
            }
        }
    }
}

// MARK: - Hex Color Helper

func colorFromHex(_ hex: String) -> Color {
    let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard cleaned.count == 6 else { return .gray }
    var rgb: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&rgb)
    let r = Double((rgb >> 16) & 0xFF) / 255
    let g = Double((rgb >> 8) & 0xFF) / 255
    let b = Double(rgb & 0xFF) / 255
    return Color(red: r, green: g, blue: b)
}
