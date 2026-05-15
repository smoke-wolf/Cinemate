import SwiftUI
import LocalAuthentication

struct AccountSelectorView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var accounts: [Account] = Account.previewAccounts
    @State private var selectedAccount: Account?
    @State private var showPINEntry = false
    @State private var showAddProfile = false
    @State private var pinTarget: Account?
    @State private var animateIn = false

    let onAccountSelected: (Account) -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Header
                VStack(spacing: 8) {
                    Text("Who's Watching?")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : -20)
                }

                // Profile Grid
                let columns = [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20),
                ]

                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                        ProfileCard(account: account) {
                            selectAccount(account)
                        }
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 30)
                        .animation(
                            Theme.springAnimation.delay(Double(index) * 0.08),
                            value: animateIn
                        )
                    }

                    // Add Profile Card
                    AddProfileCard {
                        showAddProfile = true
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 30)
                    .animation(
                        Theme.springAnimation.delay(Double(accounts.count) * 0.08),
                        value: animateIn
                    )
                }
                .padding(.horizontal, 40)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation {
                animateIn = true
            }
        }
        .sheet(isPresented: $showPINEntry) {
            if let account = pinTarget {
                PINEntryView(account: account) { success in
                    if success {
                        showPINEntry = false
                        onAccountSelected(account)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddProfile) {
            AddProfileSheet { newAccount in
                accounts.append(newAccount)
                showAddProfile = false
            }
        }
    }

    private func selectAccount(_ account: Account) {
        hapticImpact(.medium)

        if account.hasPIN {
            if account.useBiometrics {
                authenticateWithBiometrics(account: account)
            } else {
                pinTarget = account
                showPINEntry = true
            }
        } else {
            onAccountSelected(account)
        }
    }

    private func authenticateWithBiometrics(account: Account) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock \(account.name)'s profile"
            ) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        onAccountSelected(account)
                    } else {
                        pinTarget = account
                        showPINEntry = true
                    }
                }
            }
        } else {
            pinTarget = account
            showPINEntry = true
        }
    }
}

struct ProfileCard: View {
    let account: Account
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(account.color.gradient)
                        .frame(width: 80, height: 80)
                        .shadow(color: account.color.opacity(0.4), radius: 12, x: 0, y: 4)

                    Text(account.initials)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    if account.hasPIN {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(4)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                            .offset(x: 28, y: 28)
                    }
                }

                Text(account.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .buttonStyle(ProfileButtonStyle())
    }
}

struct ProfileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct AddProfileCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(Theme.textTertiary.opacity(0.4), lineWidth: 2, antialiased: true)
                        .frame(width: 80, height: 80)

                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }

                Text("Add Profile")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct PINEntryView: View {
    let account: Account
    let onResult: (Bool) -> Void

    @State private var enteredPIN: String = ""
    @State private var shake = false
    @State private var wrongAttempt = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Circle()
                        .fill(account.color.gradient)
                        .frame(width: 60, height: 60)
                        .overlay {
                            Text(account.initials)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        }

                    Text("Enter PIN for \(account.name)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.top, 40)

                // PIN dots
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index < enteredPIN.count ? Theme.primaryGold : Theme.elevatedSurface)
                            .frame(width: 16, height: 16)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        index < enteredPIN.count ? Theme.primaryGold : Theme.textTertiary.opacity(0.3),
                                        lineWidth: 2
                                    )
                            }
                            .scaleEffect(index < enteredPIN.count ? 1.1 : 1.0)
                            .animation(Theme.quickSpring, value: enteredPIN.count)
                    }
                }
                .offset(x: shake ? -10 : 0)

                if wrongAttempt {
                    Text("Incorrect PIN")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.error)
                }

                Spacer()

                // Number pad
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    ForEach(1...9, id: \.self) { number in
                        NumberPadButton(text: "\(number)") {
                            appendDigit("\(number)")
                        }
                    }
                    // Bottom row
                    Color.clear.frame(height: 60)
                    NumberPadButton(text: "0") {
                        appendDigit("0")
                    }
                    NumberPadButton(text: "delete.backward", isSystem: true) {
                        deleteDigit()
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)

                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 20)
            }
        }
    }

    private func appendDigit(_ digit: String) {
        guard enteredPIN.count < 4 else { return }
        enteredPIN += digit
        wrongAttempt = false

        if enteredPIN.count == 4 {
            validatePIN()
        }
    }

    private func deleteDigit() {
        guard !enteredPIN.isEmpty else { return }
        enteredPIN.removeLast()
        wrongAttempt = false
    }

    private func validatePIN() {
        // Simple comparison (in production, compare hashes)
        if enteredPIN == (account.pinHash ?? "1234") {
            onResult(true)
        } else {
            wrongAttempt = true
            hapticNotification(.error)

            withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
                shake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                shake = false
                enteredPIN = ""
            }
        }
    }
}

struct NumberPadButton: View {
    let text: String
    var isSystem: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            hapticImpact(.light)
            action()
        }) {
            ZStack {
                Circle()
                    .fill(Theme.cardSurface)
                    .frame(width: 60, height: 60)

                if isSystem {
                    Image(systemName: text)
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    Text(text)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct AddProfileSheet: View {
    @State private var name = ""
    @State private var selectedColor = "#D4A017"
    @State private var requirePIN = false
    @State private var pin = ""
    @Environment(\.dismiss) var dismiss

    let onAdd: (Account) -> Void

    private let colorOptions = [
        "#D4A017", "#EF4444", "#3B82F6", "#22C55E",
        "#A855F7", "#EC4899", "#F97316", "#14B8A6",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Preview
                        Circle()
                            .fill(Color(hex: selectedColor).gradient)
                            .frame(width: 80, height: 80)
                            .overlay {
                                Text(name.isEmpty ? "?" : String(name.prefix(2)).uppercased())
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .shadow(color: Color(hex: selectedColor).opacity(0.4), radius: 12, x: 0, y: 4)
                            .padding(.top, 20)

                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                            TextField("Profile name", text: $name)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.textPrimary)
                                .padding()
                                .background(Theme.cardSurface)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))
                        }
                        .padding(.horizontal)

                        // Color Picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)

                            HStack(spacing: 12) {
                                ForEach(colorOptions, id: \.self) { colorHex in
                                    Circle()
                                        .fill(Color(hex: colorHex))
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            if colorHex == selectedColor {
                                                Circle()
                                                    .strokeBorder(.white, lineWidth: 3)
                                            }
                                        }
                                        .onTapGesture {
                                            selectedColor = colorHex
                                        }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // PIN Toggle
                        Toggle(isOn: $requirePIN) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(Theme.primaryGold)
                                Text("Require PIN")
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                        .tint(Theme.primaryGold)
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("New Profile")
            .cinemateNavigationBarInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let account = Account(
                            name: name,
                            colorHex: selectedColor,
                            hasPIN: requirePIN,
                            pinHash: requirePIN ? "1234" : nil
                        )
                        onAdd(account)
                    }
                    .disabled(name.isEmpty)
                    .foregroundStyle(name.isEmpty ? Theme.textTertiary : Theme.primaryGold)
                }
            }
            .cinemateToolbarBackground(Theme.background)
        }
        .presentationDetents([.medium, .large])
    }
}

extension Account {
    static let previewAccounts: [Account] = [
        Account(name: "Maliq", colorHex: "#D4A017"),
        Account(name: "Guest", colorHex: "#3B82F6"),
        Account(name: "Kids", colorHex: "#22C55E", hasPIN: true, pinHash: "1234"),
    ]
}

#Preview {
    AccountSelectorView(onAccountSelected: { _ in })
        .environmentObject(APIClient())
}
