---
wave: 3
depends_on:
  - 02-PLAN.md
files_modified:
  - EasyTierGUI/Views/ToastView.swift (NEW)
  - EasyTierGUI/Services/ProcessViewModel.swift
  - EasyTierGUI/Views/ContentView.swift
autonomous: true
requirements:
  - INT-04
  - INT-06
  - D-05
  - D-06
---

# Plan 1.3: Toast Notification Component

**Goal:** Implement transient Toast notifications for operation failures that appear at window top-right, auto-dismiss after 3 seconds.

## Problem Statement

Currently error feedback uses blocking `NSAlert.runModal()` for authorization errors, and regular errors show in an alert dialog. Per D-05, errors should use non-blocking Toast notifications that auto-dismiss. Per D-06, success operations don't show notifications (status change is sufficient).

## Solution

1. Create `ToastView.swift` - a SwiftUI view for toast notifications
2. Add `ToastMessage` model to `Models.swift`
3. Add `toastMessage` state to `ProcessViewModel`
4. Show toast overlay in `ContentView`
5. Auto-dismiss after 3 seconds

## Tasks

### Task 1: Create ToastMessage model

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Models/Models.swift
</read_first>

<action>
Add a new `ToastMessage` struct to `Models.swift`:

```swift
// MARK: - Toast Message

/// Toast notification message
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: ToastType
    var action: ToastAction?
    
    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

enum ToastType {
    case error
    case warning
    case info
}

struct ToastAction {
    let title: String
    let handler: () -> Void
}
```

Add this after the `LogEntry` struct, around line 80-90.
</action>

<acceptance_criteria>
- `Models.swift` contains `struct ToastMessage: Identifiable, Equatable`
- `Models.swift` contains `enum ToastType` with `.error`, `.warning`, `.info` cases
- `Models.swift` contains `struct ToastAction` with `title` and `handler`
</acceptance_criteria>

---

### Task 2: Create ToastView component

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Views/ContentView.swift (for style reference)
</read_first>

<action>
Create a new file `EasyTierGUI/Views/ToastView.swift` with the following content:

```swift
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
```

Place this file in `EasyTierGUI/Views/` directory.
</action>

<acceptance_criteria>
- File `ToastView.swift` exists in `EasyTierGUI/Views/`
- `ToastView` displays icon, message text, optional action button, and dismiss button
- `ToastModifier` positions toast at top-right with spring animation
- `View.toast(message:)` extension modifier exists
</acceptance_criteria>

---

### Task 3: Add toast state to ProcessViewModel

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Services/ProcessViewModel.swift
</read_first>

<action>
Add `toastMessage` property and `showToast` method to `ProcessViewModel` class:

Add to `// MARK: - Published Properties` section (around line 136):
```swift
@Published var toastMessage: ToastMessage?
```

Add new section `// MARK: - Toast Management` after `// MARK: - Initialization Control`:
```swift
// MARK: - Toast Management

func showToast(_ text: String, type: ToastType = .error, action: ToastAction? = nil) {
    toastMessage = ToastMessage(text: text, type: type, action: action)
    
    // Auto-dismiss after 3 seconds
    Task {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        if toastMessage?.text == text {
            toastMessage = nil
        }
    }
}

func dismissToast() {
    toastMessage = nil
}
```
</action>

<acceptance_criteria>
- `ProcessViewModel` contains `@Published var toastMessage: ToastMessage?`
- `ProcessViewModel` contains `func showToast(_ text: String, type: ToastType, action: ToastAction?)`
- Toast auto-dismisses after 3 seconds
- `ProcessViewModel` contains `func dismissToast()`
</acceptance_criteria>

---

### Task 4: Add toast overlay to ContentView

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Views/ContentView.swift
</read_first>

<action>
Modify `ContentView` to include the toast modifier:

```swift
struct ContentView: View {
    @EnvironmentObject var vm: ProcessViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var selectedTab: AppTab = .connection

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            DetailView(selectedTab: selectedTab)
        }
        .navigationTitle("EasyTier")
        .toast(message: $vm.toastMessage)  // Add this line
    }
}
```
</action>

<acceptance_criteria>
- `ContentView` body includes `.toast(message: $vm.toastMessage)` modifier
- Toast appears at top-right of window when `vm.toastMessage` is set
</acceptance_criteria>

---

### Task 5: Update ConnectionView to use toast for errors

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Views/ConnectionView.swift
</read_first>

<action>
Replace the `showConnectErrorAlert` state and alert with toast usage. Modify the `connect` method in `ConfigListSection` (around line 553):

Replace:
```swift
private func connect(_ config: EasyTierConfig) async {
    await vm.connect(configID: config.id)
    guard let error = vm.errorMessage(for: config), !error.isEmpty else {
        return
    }
    connectErrorMessage = "「\(config.name)」连接失败：\n\(error)"
    showConnectErrorAlert = true
}
```

With:
```swift
private func connect(_ config: EasyTierConfig) async {
    await vm.connect(configID: config.id)
    guard let error = vm.errorMessage(for: config), !error.isEmpty else {
        return
    }
    vm.showToast("「\(config.name)」连接失败：\(error)", type: .error)
}
```

Remove the `@State private var showConnectErrorAlert = false` and `@State private var connectErrorMessage = ""` state variables, and remove the `.alert("连接失败", isPresented: $showConnectErrorAlert)` modifier.
</action>

<acceptance_criteria>
- `ConfigListSection` no longer has `showConnectErrorAlert` state
- `ConfigListSection` no longer has `.alert("连接失败", ...)` modifier
- Connection errors are shown via `vm.showToast()`
</acceptance_criteria>

---

## Verification

1. Build and run the application
2. Trigger a connection error (e.g., missing network name)
3. Verify toast appears at top-right corner
4. Verify toast shows error icon and message
5. Verify toast auto-dismisses after 3 seconds
6. Click dismiss button (X) - verify toast disappears immediately
7. Verify no blocking NSAlert for connection errors

## must_haves

- [ ] `ToastMessage` model exists in `Models.swift`
- [ ] `ToastView.swift` file exists with proper styling
- [ ] `ToastModifier` positions toast at top-right
- [ ] `ProcessViewModel.toastMessage` published property exists
- [ ] `ProcessViewModel.showToast()` method exists with 3-second auto-dismiss
- [ ] `ContentView` includes `.toast(message:)` modifier
- [ ] Connection errors use toast instead of blocking alert
