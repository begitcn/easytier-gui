# EasyTier GUI

[![Platform](https://img.shields.io/badge/platform-macOS%20(Intel%20%7C%20Apple%20Silicon)-lightgrey)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

一个用于 [EasyTier](https://github.com/EasyTier/EasyTier) 的 macOS 原生图形界面应用程序。

## 功能特性

- 🖥️ **原生 macOS 体验** - 使用 SwiftUI 构建，支持 Intel 和 Apple Silicon
- 🔧 **完整配置支持** - 网络名称、密码、服务器地址、主机名等
- ⚡ **高级选项** - 延迟优先模式、私有模式、DNS 配置、多线程、KCP 代理
- 📋 **多配置管理** - 保存、导入、导出多个网络配置
- 👥 **节点监控** - 实时查看已连接节点和延迟信息
- 📝 **日志查看** - 带过滤和搜索的实时日志

## 系统要求

- macOS 14.0+
- [EasyTier](https://github.com/EasyTier/EasyTier/releases) 可执行文件

## 安装

### 从 DMG 安装

1. 下载 `EasyTierGUI.dmg`
2. 打开 DMG，将应用拖入 Applications 文件夹
3. 从终端运行（首次需要 root 权限）：
   ```bash
   sudo /Applications/EasyTierGUI.app/Contents/MacOS/EasyTierGUI
   ```

### 从源码编译

```bash
# 克隆仓库
git clone https://github.com/your-username/easytier-gui.git
cd easytier-gui

# 构建
./build.sh

# 运行
./launch-easytier-gui.sh
```

## 使用说明

### 快速开始

1. **下载 EasyTier** - 从 [Releases](https://github.com/EasyTier/EasyTier/releases) 下载 `easytier-core` 和 `easytier-cli`
2. **配置路径** - 在设置中指定 EasyTier 可执行文件目录
3. **创建网络** - 填写网络名称和密码
4. **连接** - 点击连接按钮

### 配置说明

| 字段 | 说明 | 必填 |
|------|------|------|
| 网络名称 | 组网标识符 | ✅ |
| 网络密码 | 组网密钥 | ✅ |
| 服务器地址 | 对端节点地址 (如 `tcp://1.2.3.4:11010`) | ✅ |
| 主机名 | 本机显示名称 | ❌ |
| DHCP | 自动分配虚拟 IP (推荐) | ❌ |
| 静态 IP | 手动指定虚拟 IP | ❌ |

## 故障排除

### TUN device error: Operation not permitted

EasyTier 需要 root 权限创建 TUN 网络设备。解决方法：

```bash
# 方法 1: 使用启动脚本
./launch-easytier-gui.sh

# 方法 2: 直接以 root 运行
sudo /Applications/EasyTierGUI.app/Contents/MacOS/EasyTierGUI
```

### 找不到 easytier-core

1. 从 [EasyTier Releases](https://github.com/EasyTier/EasyTier/releases) 下载
2. 放置在 `/usr/local/bin` 或 `/opt/homebrew/bin`
3. 或在设置中指定自定义路径

### 连接失败

1. 检查网络名称和密码是否正确
2. 确认服务器地址格式正确 (如 `tcp://ip:port`)
3. 检查防火墙设置
4. 查看日志获取详细错误信息

## 构建与打包

```bash
# 构建 Universal Binary (Intel + Apple Silicon)
./build.sh

# 打包 DMG
./create-dmg.sh
```

## 技术栈

- **语言**: Swift 5.9
- **框架**: SwiftUI, AppKit
- **架构**: MVVM
- **最低版本**: macOS 14.0

## 许可证

[MIT License](LICENSE)

## 致谢

- [EasyTier](https://github.com/EasyTier/EasyTier) - 强大的 P2P 组网工具
- [Claude (Anthropic)](https://www.anthropic.com/claude) - AI 辅助开发

---

> 本项目由 Claude AI 辅助开发完成
