# Phase 4: Config Import/Export Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 04-config-import-export-foundation
**Areas discussed:** 敏感数据处理、冲突处理、验证策略、文件格式、UI入口、反馈方式

---

## 敏感数据处理

| Option | Description | Selected |
|--------|-------------|----------|
| 默认清除密码 | 导出时默认清除 networkPassword，用户勾选才能包含 | |
| 默认包含密码 | 导出时保留密码，用户勾选才清除 | ✓ |
| 每次询问 | 每次导出都询问用户 | |

**User's choice:** 默认包含密码
**Notes:** 用户选择方便优先，可选清除功能作为备选

---

## 冲突处理

| Option | Description | Selected |
|--------|-------------|----------|
| 自动重命名导入 | 生成新的 UUID 和名称后缀，两个配置都保留 | |
| 提示用户选择 | 弹出对话框让用户选择：跳过、替换、或重命名 | |
| 直接覆盖 | 同名配置直接覆盖，无需确认 | ✓ |

**User's choice:** 直接覆盖
**Notes:** 简化实现，不做复杂的冲突检测

---

## 验证策略

| Option | Description | Selected |
|--------|-------------|----------|
| JSON 解码验证 | 解码成功即有效，简单直接 | ✓ |
| 业务规则验证 | 额外检查必填字段、端口范围、IP 格式等 | |
| 两者结合 | 先解码验证，再对关键字段做业务检查 | |

**User's choice:** JSON 解码验证
**Notes:** 利用现有 Codable 实现，EasyTierConfig 已有向后兼容处理

---

## UI 入口位置

| Option | Description | Selected |
|--------|-------------|----------|
| 配置卡片 + 列表工具栏 | 卡片菜单导出，列表工具栏导入 | ✓ |
| 设置页面 | 在设置页面添加导入导出区块 | |
| 菜单栏 | 菜单栏下拉菜单中添加选项 | |

**User's choice:** 配置卡片 + 列表工具栏
**Notes:** 导出在卡片操作菜单，导入在列表工具栏

---

## 全部导出格式

| Option | Description | Selected |
|--------|-------------|----------|
| 单一 JSON 文件 | 导出所有配置到一个 JSON 数组文件 | ✓ |
| 多个单独文件 | 每个配置单独文件 | |
| ZIP 压缩包 | 打包成 zip 文件 | |

**User's choice:** 单一 JSON 文件
**Notes:** 适合迁移备份，一次导入全部

---

## 文件对话框

| Option | Description | Selected |
|--------|-------------|----------|
| 默认目录 + 默认文件名 | 默认 ~/Downloads，预填文件名 | ✓ |
| 记住上次位置 | 记住上次导出的目录和文件名 | |

**User's choice:** 默认目录 + 默认文件名
**Notes:** 简单直接，符合大多数应用习惯

---

## 反馈方式

| Option | Description | Selected |
|--------|-------------|----------|
| Toast 通知 | 使用现有 Toast 组件，成功/失败都有提示 | ✓ |
| Alert 对话框 | 弹出确认对话框 | |
| 仅失败提示 | 仅失败时提示，成功时静默 | |

**User's choice:** Toast 通知
**Notes:** 复用 Phase 1 已实现的 Toast 机制

---

## 文件命名格式

| Option | Description | Selected |
|--------|-------------|----------|
| 配置名称.json | 如 my-network.json | ✓ |
| easytier-{name}-{date}.json | 包含时间信息 | |
| {name}.easytier.json | 双后缀标识 | |

**User's choice:** 配置名称.json
**Notes:** 简洁清晰

---

## 导出入口具体位置

| Option | Description | Selected |
|--------|-------------|----------|
| 卡片操作菜单 | 在"..."菜单中添加导出选项 | ✓ |
| 卡片上的按钮 | 直接显示导出按钮 | |

**User's choice:** 卡片操作菜单
**Notes:** 不占用额外空间，与其他操作统一

---

## 导入入口具体位置

| Option | Description | Selected |
|--------|-------------|----------|
| 配置列表工具栏 | 在顶部添加"导入配置"按钮 | ✓ |
| 菜单栏菜单 | 在菜单栏下拉菜单中添加 | |

**User's choice:** 配置列表工具栏
**Notes:** 与"新建配置"并列，便于发现

---

## Claude's Discretion

- 导入失败的具体错误文案
- Toast 显示时长
- 是否添加"导出全部"到菜单栏

## Deferred Ideas

None — discussion stayed within phase scope
