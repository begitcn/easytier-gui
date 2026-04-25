# Phase 4: Config Import/Export Foundation - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

实现网络配置的导入导出功能，支持单个配置和全部配置的导出、JSON 文件导入、验证和冲突处理。

**In scope:**
- 导出单个配置到 JSON 文件
- 导出全部配置到单一 JSON 文件
- 从 JSON 文件导入配置（自动检测单配置/多配置格式）
- 配置验证（JSON 解码验证）
- 重复配置冲突处理（直接覆盖）
- 敏感数据处理（默认包含密码，可选清除）
- 导入导出 UI 入口和反馈

**Out of scope:**
- 网络统计功能（Phase 5）
- 自动连接功能（Phase 6）
- 快捷连接功能（Phase 7）
- 云同步功能
- 配置加密/密码保护

</domain>

<decisions>
## Implementation Decisions

### 敏感数据处理
- **D-01:** 默认包含密码 — 导出时默认保留 networkPassword 字段，不做特殊处理
- **D-02:** 可选清除选项 — 导出 UI 提供复选框"排除密码"，用户可选择清除敏感数据

### 冲突处理
- **D-03:** 直接覆盖 — 导入时如发现相同 UUID 或网络名称，直接覆盖现有配置，不弹窗确认
- **D-04:** 无重复检测 — 简化实现，依赖 UUID 匹配，不做名称重复检测

### 验证策略
- **D-05:** JSON 解码验证 — 利用现有 Codable 实现，解码成功即视为有效配置
- **D-06:** 向后兼容 — EasyTierConfig 的 init(from:) 已有默认值处理，支持缺失字段

### 文件格式
- **D-07:** 单一 JSON 文件 — 导出全部配置时使用数组格式，一个文件包含所有配置
- **D-08:** 文件命名 — 使用 `{配置名称}.json` 格式，如 `my-network.json`
- **D-09:** 默认目录 — 文件保存对话框默认打开 ~/Downloads，预填文件名

### UI 入口
- **D-10:** 导出入口 — 配置卡片右上角"..."操作菜单中添加"导出配置"选项
- **D-11:** 导出入口 — 配置列表顶部工具栏添加"导入配置"按钮，与"新建配置"并列
- **D-12:** 导出全部 — 列表工具栏添加"导出全部"按钮，或在设置页面添加

### 反馈方式
- **D-13:** Toast 通知 — 使用现有 Toast 组件（Phase 1），成功/失败都显示提示
- **D-14:** 提示文案 — 导出成功："已导出配置 my-network"；导入成功："已导入配置"

### Claude's Discretion
- 导入失败的具体错误文案（格式无效、文件不存在等）
- Toast 显示时长
- 是否添加"导出全部"到菜单栏

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Research Findings
- `.planning/research/SUMMARY.md` — 研究摘要，关键发现
- `.planning/research/ARCHITECTURE.md` — 架构模式

### Codebase
- `.planning/codebase/ARCHITECTURE.md` — 现有架构分析
- `.planning/codebase/CONVENTIONS.md` — 编码约定

### Prior Phases
- `.planning/milestones/v1.0-phases/01-响应性与交互反馈/01-CONTEXT.md` — Phase 1 决策，Toast 机制
- `.planning/milestones/v1.0-phases/02-内存与稳定性/02-CONTEXT.md` — Phase 2 决策
- `.planning/milestones/v1.0-phases/03-ui/03-CONTEXT.md` — Phase 3 决策，UI 风格

</canonical_refs>

<code_context>
## Existing Code Insights

### ConfigManager.swift (已有导入导出基础)
- `exportConfig(_ config:to url:)` — 导出单个配置到指定 URL
- `importConfig(from url:)` — 从 URL 导入单个配置
- `exportAllConfigs(to url:)` — 导出所有配置到单一文件
- `importConfigsFromAnyFormat(from url:)` — 自动检测单配置/多配置格式
- JSON 编码器已配置 `.prettyPrinted` 和 `.sortedKeys`

### EasyTierConfig (Models.swift)
- 17 个字段，全部 Codable
- 敏感字段：`networkPassword: String`
- `init(from decoder:)` 已实现向后兼容，缺失字段使用默认值
- UUID 作为唯一标识符

### Toast 机制 (Phase 1 已实现)
- `ToastMessage` 结构体已定义
- `ToastType`: `.error`, `.warning`, `.info`
- `ProcessViewModel` 有 `toastMessage: ToastMessage?`

### UI 组件
- `ConnectionView.swift` — 配置卡片列表，`configCard()` 方法
- `ContentView.swift` — 标签页切换
- SF Symbols 风格图标

### Reusable Assets
- Toast 通知机制
- JSON 编码/解码器配置
- 文件选择器（其他功能中已有使用模式）

### Integration Points
- `ConfigManager.swift` — 扩展现有导入导出方法
- `ConnectionView.swift` — 添加导出菜单项到卡片
- `ProcessViewModel.swift` — 协调导入操作，显示 Toast

</code_context>

<specifics>
## Specific Ideas

- 导出菜单项图标：`square.and.arrow.up` (SF Symbol)
- 导入按钮图标：`square.and.arrow.down` (SF Symbol)
- 导出全部按钮文字："导出全部配置"
- 导入按钮文字："导入配置"
- 文件保存对话框默认文件名：`{config.name}.json`
- 全部导出文件名：`all-configs.json`

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-config-import-export-foundation*
*Context gathered: 2026-04-25*
