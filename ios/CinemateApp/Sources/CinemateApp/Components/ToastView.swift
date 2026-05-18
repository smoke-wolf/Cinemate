import SwiftUI

struct ToastView: View {
    let icon: String
    let message: String
    var tint: Color = Theme.primaryGold

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .colorScheme(.dark)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let icon: String
    let message: String
    var tint: Color = Theme.primaryGold
    var duration: Double = 2.0
    var edge: Edge = .bottom

    func body(content: Content) -> some View {
        content.overlay(alignment: edge == .top ? .top : .bottom) {
            if isPresented {
                ToastView(icon: icon, message: message, tint: tint)
                    .transition(.move(edge: edge).combined(with: .opacity))
                    .padding(edge == .top ? .top : .bottom, edge == .top ? 8 : 100)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation(.easeOut(duration: 0.25)) {
                                isPresented = false
                            }
                        }
                    }
                    .zIndex(999)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPresented)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, icon: String, message: String, tint: Color = Theme.primaryGold, edge: Edge = .bottom) -> some View {
        modifier(ToastModifier(isPresented: isPresented, icon: icon, message: message, tint: tint, edge: edge))
    }
}
