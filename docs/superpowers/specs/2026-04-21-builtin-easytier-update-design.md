# EasyTier 内置二进制与自动更新设计

## 概述

将 easytier-core 和 easytier-cli 内置到应用中，并支持从 GitHub 自动检测和更新核心版本。

## 需求

- 内置默认版本的 easytier 二进制文件
- 启动时自动检查 GitHub 最新版本
- 有新版本时提示用户确认后下载更新
- 更新不影响 app 签名（更新文件存储在用户目录）

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│                      EasyTierService                         │
│  (现有服务，修改为通过 BinaryManager 获取二进制路径)           │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      BinaryManager                           │
│  - 解析二进制路径（优先用户目录 > 内置资源）                    │
│  - 检测当前版本                                              │
│  - 协调更新流程                                              │
└─────────────────────────┬───────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
┌─────────────────┐ ┌──────────┐ ┌─────────────────────┐
│ GitHubRelease   │ │ Version  │ │ UpdateNotification  │
│ Service         │ │ Service  │ │ Manager             │
│ - API 调用      │ │ - 版本比 │ │ - 横幅显示          │
│ - 文件下载      │ │   较逻辑 │ │ - 下载进度          │
└─────────────────┘ └──────────┘ └─────────────────────┘
```

## 目录结构

### App Bundle 内置

```
EasyTierGUI.app/
├── Contents/
│   ├── MacOS/
│   │   └── EasyTierGUI
│   └── Resources/
│       └── easytier/              # 内置二进制
│           ├── easytier-core
│           └── easytier-cli
```

### 用户数据目录

```
~/Library/Application Support/EasyTierGUI/
├── bin/                           # 更新的二进制（优先使用）
│   ├── easytier-core
│   └── easytier-cli
└── config/                        # 现有配置目录
```

## 新增文件

| 文件 | 说明 |
|------|------|
| `Services/BinaryManager.swift` | 二进制路径管理、版本检测、更新协调 |
| `Services/GitHubReleaseService.swift` | GitHub API 调用、文件下载 |
| `Models/BinaryVersion.swift` | 版本信息模型 |
| `Views/Components/UpdateBanner.swift` | 更新提示横幅组件 |

## 修改文件

| 文件 | 修改内容 |
|------|----------|
| `EasyTierService.swift` | 使用 `BinaryManager` 获取二进制路径，移除手动路径配置依赖 |
| `SettingsView.swift` | 显示版本信息、检查更新按钮、更新状态、下载进度 |
| `ProcessViewModel.swift` | 初始化时触发后台更新检查 |
| `build.sh` | 构建时下载并嵌入默认版本二进制 |

## 数据模型

### BinaryVersion

```swift
struct BinaryVersion {
    let version: String        // e.g., "1.2.3"
    let tagName: String        // e.g., "v1.2.3"
    let releaseNotes: String?  // GitHub release body
    let downloadURL: URL       // 下载链接
    let publishedAt: Date      // 发布时间
}
```

### 用户设置 (UserDefaults)

```swift
// 存储键
"easytierBundledVersion"    // 内置版本号
"easytierInstalledVersion"  // 已安装版本（用户目录）
"easytierLastUpdateCheck"   // 上次检查时间
"easytierSkipVersion"       // 用户跳过的版本
```

## 核心逻辑

### 二进制路径解析

优先级顺序：
1. 用户目录已安装版本（`~/Library/Application Support/EasyTierGUI/bin/`）
2. App Bundle 内置版本（`Contents/Resources/easytier/`）

```swift
func resolveBinaryPath(name: String) -> URL {
    let userBin = userBinDir.appendingPathComponent(name)
    if fileManager.isExecutableFile(atPath: userBin.path) {
        return userBin
    }

    let bundledBin = bundledBinDir.appendingPathComponent(name)
    if fileManager.isExecutableFile(atPath: bundledBin.path) {
        return bundledBin
    }

    return userBin  // 返回预期路径，错误处理由调用方负责
}
```

### 版本比较

使用语义化版本比较：
- 解析版本字符串为 `(major, minor, patch)`
- 比较规则：major > minor > patch
- GitHub release tag 格式：`v1.2.3`

### 更新检查流程

```
应用启动
    ↓
后台异步检查 GitHub API
    ↓
比较最新版本与当前版本
    ↓
有新版本？
    ├─ Yes → 显示更新横幅（版本号、更新日志摘要）
    │         ↓
    │       用户点击"更新"
    │         ↓
    │       下载 → 解压 → 验证 → 安装
    │         ↓
    │       显示更新完成，提示重启生效
    │
    └─ No → 静默，无需操作
```

### 下载流程

1. 根据当前架构选择下载 URL：
   - arm64: `easytier-apple-darwin-arm64.zip`
   - x86_64: `easytier-apple-darwin-x86_64.zip`

2. 下载到临时目录：
   ```
   ~/Library/Caches/EasyTierGUI/Downloads/
   ```

3. 解压并验证：
   - 检查文件存在
   - 检查可执行权限

4. 替换用户目录文件：
   ```swift
   try fileManager.moveItemAt(tempFile, to: userBinPath)
   try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: userBinPath.path)
   ```

### 构建时嵌入

修改 `build.sh`：

```bash
# 下载最新版本
LATEST_URL=$(curl -s https://api.github.com/repos/EasyTier/EasyTier/releases/latest | ...)
ARCH=$(uname -m)
curl -L -o /tmp/easytier.zip "$LATEST_URL"

# 解压到 Resources 目录
unzip /tmp/easytier.zip -d EasyTierGUI/Resources/easytier/
```

## UI 设计

### 设置页面更新区域

```
┌─────────────────────────────────────────────────────────────┐
│ EasyTier                                                     │
├─────────────────────────────────────────────────────────────┤
│ 当前版本      v1.2.3 (已安装)                                 │
│ 最新版本      v1.2.5                                          │
│                                                              │
│ [检查更新]                                    [立即更新]      │
│                                                              │
│ ┌──────────────────────────────────────────────────────────┐│
│ │ 📢 发现新版本 v1.2.5                                       ││
│ │ 更新内容：修复连接稳定性问题，新增 KCP 支持...              ││
│ │ [更新] [稍后提醒] [跳过此版本]                              ││
│ └──────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### 更新横幅

显示在设置页面顶部：

```
┌─────────────────────────────────────────────────────────────┐
│ 📢 发现新版本 v1.2.5                       [更新] [忽略]    │
└─────────────────────────────────────────────────────────────┘
```

### 下载进度

```
┌─────────────────────────────────────────────────────────────┐
│ 正在更新...                                                  │
│ ████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  45%      │
│ 正在下载 easytier-core...                                   │
└─────────────────────────────────────────────────────────────┘
```

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| 网络不可用 | 静默失败，使用内置/已安装版本，下次检查再试 |
| GitHub API 限流 | 缓存上次检查结果，24小时内不重复检查 |
| 下载失败 | 显示错误提示，保留原版本，允许重试 |
| 解压失败 | 清理临时文件，回退内置版本 |
| 权限问题 | 使用沙盒安全的位置存储 |

## 安全考虑

1. **代码签名**：更新文件存储在用户目录，不影响 app bundle 签名
2. **HTTPS 下载**：所有下载使用 HTTPS
3. **校验**：可选添加 SHA256 校验（需 GitHub release 提供）
4. **权限**：更新后的二进制需要可执行权限

## 测试要点

1. 首次启动：内置版本可用
2. 更新检查：正确获取最新版本信息
3. 下载更新：正确下载、解压、安装
4. 版本回退：删除用户目录文件后使用内置版本
5. 离线场景：无网络时正常使用现有版本
6. 多架构：arm64 和 x86_64 正确选择下载链接
