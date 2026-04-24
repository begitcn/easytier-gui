import SwiftUI

// MARK: - Toast View

struct ToastView: View {
    let message: ToastMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon based on type
            Image(systemName: iconForType(message.type))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colorForType(message.type))

            // Message text
            Text(message.text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // Optional action button
            if let action = message.action {
                Button(action.title) {
                    action.handler()
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.15))
                .foregroundColor(.accentColor)
                .cornerRadius(6)
            }

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColorForType(message.type).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
    }

    // MARK: - Helpers

    private func iconForType(_ type: ToastType) -> String {
        switch type {
        case .error: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private func colorForType(_ type: ToastType) -> Color {
        switch type {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    private func borderColorForType(_ type: ToastType) -> Color {
        switch type {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {
    @Binding var message: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if let message = message {
                    ToastView(message: message, onDismiss: { self.message = nil })
                        .padding(.top, 60)
                        .padding(.trailing, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: message != nil)
                        .zIndex(100)
                }
            }
    }
}

extension View {
    func toast(message: Binding<ToastMessage?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("Content")
    }
    .frame(width: 600, height: 400)
    .toast(message: .constant(ToastMessage(text: "连接失败：网络不可达", type: .error)))
}
