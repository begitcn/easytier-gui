# Phase 3: UI 优化 - Research

**Researched:** 2026-04-24
**Status:** Research complete

<domain_analysis>
## Domain Understanding

Phase 3 专注于 macOS 原生 UI 优化，使应用符合 Human Interface Guidelines (HIG)。主要涉及：

1. **macOS 设计规范 (HIG)**
   - 系统语义色使用（Semantic Colors）
   - SF Symbols 图标系统
   - 毛玻璃材质与半透明效果
   - 标准间距系统 (8pt grid)
   - 键盘快捷键支持

2. **视觉层次 (Visual Hierarchy)**
   - 标题/正文/辅助文字层级
   - 颜色强调与注意力引导
   - 信息密度与可读性平衡

3. **现有实现分析**
   - 连接状态：已使用状态徽章 + 语义色
   - 节点列表：已实现延迟颜色编码
   - 日志视图：已实现级别颜色区分
   - 整体风格：毛玻璃卡片 + 阴影 + 圆角

需要优化的地方：
- 缺少键盘快捷键支持
- 间距值不够统一
- 日志颜色可以更精确
- 状态图标可以更丰富
</domain_analysis>

<existing_patterns>
## Existing Patterns Found

### 1. 毛玻璃卡片样式 (ContentView, ConnectionView, PeersView, LogView, SettingsView)
```swift
.background(.ultraThinMaterial)
.cornerRadius(20)
.overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 1))
.shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
```
**使用位置**: 所有主要视图卡片

### 2. 状态徽章 (ConnectionView.swift:591-633)
```swift
HStack(spacing: 3) {
    Circle().fill(Color.green).frame(width: 5, height: 5)
    Text("运行中")
}
// connected/connecting/error/disconnected 状态区分
```
**使用位置**: 连接页面配置列表项

### 3. 延迟颜色编码 (PeersView.swift:242-246)
```swift
private func latencyColor(_ ms: Double) -> Color {
    if ms < 50 { return .green }
    if ms < 150 { return .orange }
    return .red
}
```
**使用位置**: 节点页面延迟显示

### 4. 日志颜色区分 (LogView.swift:284-293)
```swift
private var logBackgroundColor: Color {
    switch entry.level.lowercased() {
    case "error", "err": return Color.red.opacity(0.08)
    case "warn", "warning": return Color.orange.opacity(0.08)
    default: return showIndex % 2 == 0 ? ... : Color.clear
    }
}
```
**使用位置**: 日志页面条目行

### 5. 搜索栏样式 (PeersView, LogView)
```swift
HStack {
    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
    TextField("...", text: $searchText).textFieldStyle(.plain)
}
.padding(.horizontal, 12).padding(.vertical, 8)
.background(Color(NSColor.controlBackgroundColor).opacity(0.5))
.cornerRadius(8)
```

### 6. Tab 导航 (ContentView.swift:44-47)
```swift
List(AppTab.allCases, selection: $selectedTab) { tab in
    Label(tab.label, systemImage: tab.icon)
        .tag(tab)
}
.listStyle(.sidebar)
```

### 7. AppTab 枚举 (ProcessViewModel.swift:562-584)
```swift
enum AppTab: String, CaseIterable, Identifiable {
    case connection, peers, logs, settings
    var label: String { ... }
    var icon: String { ... }
}
```
</existing_patterns>

<dependencies>
## Dependencies & Requirements

### Phase 3 Requirements (from REQUIREMENTS.md)

| Requirement | Description | Current State |
|-------------|-------------|---------------|
| UI-01 | 界面简洁美观，遵循苹果原生设计规范 | 部分完成，需优化间距和细节 |
| UI-02 | 信息层次分明，重点突出 | 已有层级，可增强 |
| UI-03 | 连接状态视觉清晰（图标 + 颜色 + 文字） | 已实现状态徽章 |
| UI-04 | 节点列表信息完整易读 | 已完成 |
| UI-05 | 日志视图颜色区分，易读性好 | 已实现，可优化 |

### 技术依赖

1. **SwiftUI Keyboard Events**: 需要使用 `KeyPress` 事件或 `onKeyPress`
2. **System Colors**: 使用 `Color.green/.orange/.red` 语义色
3. **SF Symbols**: 已广泛使用，保持一致
4. **无新依赖**: 纯 SwiftUI 实现，无需引入第三方库

### 需要协调的模块

- `ContentView.swift`: 添加键盘快捷键处理
- `AppTab` 枚举: 无需修改，label/icon 已完备
- `ProcessViewModel`: 添加刷新节点的方法 (如需要)
</dependencies>

<implementation_approach>
## Implementation Approach

### Recommended Implementation Order

#### Plan 1: 统一间距规范 (Spacing)
- **目标**: 符合 macOS HIG 8pt grid 系统
- **参考值**:
  - 组件内间距: 8pt, 12pt, 16pt
  - 组件外间距: 16pt, 20pt, 24pt
  - 卡片内边距: 20pt (已实现)
  - 卡片间距: 24pt (已实现)
- **实现方式**: 审查所有视图，更新间距常量

#### Plan 2: 键盘快捷键支持
- **目标**: ⌘1-4 切换标签页、⌘R 刷新节点
- **实现方式**: 在 `ContentView` 添加 `onKeyPress` 修饰符
- **映射**:
  - ⌘1 → connection
  - ⌘2 → peers  
  - ⌘3 → logs
  - ⌘4 → settings
  - ⌘R → 刷新节点列表 (需 ProcessViewModel 支持)

#### Plan 3: 日志视图优化
- **目标**: 更清晰的颜色区分，提高可读性
- **当前状态**: ERROR 红色背景 8%，WARN 橙色背景 8%
- **优化方向**:
  - 优化文字颜色对比度
  - 添加级别图标 (exclamationmark.triangle.fill 等)
  - 统一字体大小

#### Plan 4: 连接状态增强
- **目标**: 更清晰的连接状态视觉
- **当前**: 已有状态徽章 (圆点 + 文字)
- **优化方向**:
  - 菜单栏图标同步状态变化
  - 优化 connecting 状态的动画
  - 考虑添加状态过渡动画

#### Plan 5: 整体视觉打磨
- **目标**: 提升整体视觉品质
- **内容**:
  - 按钮悬停效果
  - 转场动画一致性
  - 激活状态指示增强
  - 统一动画时长 (0.2s - 0.3s)

### Key Implementation Points

1. **快捷键实现**: 使用 `NavigationSplitView` + `@FocusState` 或 `onKeyPress` 修饰符
2. **间距常量**: 建议在代码中定义常量或使用 SwiftUI 默认间距
3. **颜色一致性**: 定义颜色扩展或使用 Design Tokens 模式
4. **动画**: 使用 `withAnimation(.easeInOut(duration: 0.25))` 统一动画
</implementation_approach>

<pitfalls>
## Pitfalls to Avoid

### 1. 过度自定义
- **风险**: 自定义过多破坏 macOS 原生感
- **避免**: 优先使用系统默认样式，只在必要时微调

### 2. 快捷键冲突
- **风险**: 与系统快捷键冲突 (如 ⌘Q, ⌘W)
- **避免**: 使用未占用的快捷键 (⌘1-4, ⌘R 已安全)

### 3. 间距不一致
- **风险**: 不同视图使用不同间距值，视觉不协调
- **避免**: 建立统一的间距标准并遵循

### 4. 颜色对比度不足
- **风险**: 日志文字与背景对比度不足，可读性差
- **避免**: 确保 WCAG 对比度要求 (至少 4.5:1)

### 5. 动画过度
- **风险**: 过多动画导致界面迟钝
- **避免**: 仅在必要时添加动画，保持响应性优先

### 6. 破坏现有功能
- **风险**: 优化时引入 bug
- **避免**: 每个改动独立测试，保持现有功能正常
</pitfalls>

<validation_architecture>
## Validation Architecture

### 验证方法

1. **构建验证**: `./build.sh` 成功编译
2. **功能验证**:
   - 所有 5 个视图可正常显示
   - 快捷键正确切换标签页
   - 连接/断开状态显示正确
   - 节点列表显示正确
   - 日志颜色区分正确
3. **视觉验证**:
   - 间距一致
   - 颜色对比度足够
   - 动画流畅
4. **兼容性验证**:
   - macOS 14.0 (Sonoma) 正常

### 测试场景

| 场景 | 验证点 |
|------|--------|
| 启动应用 | 窗口正常显示，无报错 |
| 点击侧边栏 | 正确切换到对应视图 |
| ⌘1-4 快捷键 | 正确切换标签页 |
| 连接网络 | 状态徽章正确更新 |
| 查看节点 | 延迟颜色正确显示 |
| 查看日志 | 级别颜色正确区分 |
| 断开网络 | 状态正确回退 |

### 成功标准

- UI-01: 界面遵循 macOS 设计规范，整体美观协调
- UI-02: 信息层次分明，重要信息突出
- UI-03: 连接状态图标+颜色+文字清晰可辨
- UI-04: 节点列表字段完整，延迟颜色区分明显
- UI-05: 日志 ERROR/WARN/INFO 颜色区分明确
</validation_architecture>

---

*Research complete: 2026-04-24*
