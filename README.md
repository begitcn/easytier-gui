# EasyTier GUI

一个用于 EasyTier 的 macOS 图形界面应用程序。

![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

## ⚠️ 重要说明

**EasyTier 需要 root 权限才能创建 TUN 网络设备。**

请使用以下方式之一运行应用：

### 快速开始

#### 方式 1: 使用启动脚本（推荐）

```bash
cd /path/to/easytier-gui
./launch-easytier-gui.sh
```

#### 方式 2: 直接运行

```bash
sudo /Applications/EasyTierGUI.app/Contents/MacOS/EasyTierGUI
```

#### 方式 3: 从 Xcode 运行

```bash
# 在 Xcode 中，Product > Scheme > Edit Scheme
# 在 "Run" 选项卡中，勾选 "Debug executable"
# 然后在终端中运行：
sudo /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project EasyTierGUI.xcodeproj -scheme EasyTierGUI
```

## 功能特性

✅ **完整的 EasyTier 配置支持**
- 基础设置：网络名称、密码、服务器地址
- 高级设置：主机名、延迟优先、私有模式、DNS配置、多线程、KCP代理
- TUN 设备：DHCP 或静态 IP 配置
- 节点管理：添加/删除多个对等节点

✅ **用户友好的界面**
- 状态指示器：实时显示连接状态
- 日志查看：完整的日志输出
- 节点列表：查看已连接的节点

✅ **配置管理**
- 多配置支持：保存和管理多个网络配置
- 配置导入/导出：方便配置分享

## 系统要求

- macOS 14.0+
- Xcode 15.0+ (用于编译)
- EasyTier Core 可执行文件

## 安装

### 1. 获取 EasyTier Core

从 [EasyTier Releases](https://github.com/EasyTier/EasyTier/releases) 下载适合您 Mac 的版本：

- Apple Silicon (M1/M2/M3): `easytier-macos-aarch64.zip`
- Intel Mac: `easytier-macos-x86_64.zip`

解压后将 `easytier-core` 可执行文件放到任意位置。

### 2. 编译应用

```bash
git clone https://github.com/your-repo/easytier-gui.git
cd easytier-gui
xcodebuild -project EasyTierGUI.xcodeproj -scheme EasyTierGUI -configuration Release
```

### 3. 运行应用

```bash
./launch-easytier-gui.sh
```

首次运行时，在设置中选择 `easytier-core` 可执行文件路径。

## 使用说明

详细的使用说明请参考 [RUN-WITH-SUDO.md](./RUN-WITH-SUDO.md)。

### 快速配置

1. **基础设置**
   - 网络名称：填写组网名称
   - 网络密码：填写组网密码
   - 服务器地址：填写对端节点地址（可选）

2. **IP 配置**
   - 使用 DHCP：自动获取虚拟 IP（推荐）
   - 静态 IP：手动指定 IP 和掩码（如：192.168.55.13/24）

3. **高级设置**（可选）
   - 主机名：自定义主机名
   - 延迟优先：优先选择低延迟路径
   - 私有模式：启用私有网络
   - DNS 配置：接受对端 DNS
   - 多线程：启用多线程处理
   - KCP 代理：启用 KCP 协议

4. **启动连接**
   - 点击"连接"按钮
   - 查看"节点"标签页了解连接状态
   - 查看"日志"标签页了解详细日志

## 配置文件

配置文件保存在：
```
~/Library/Application Support/EasyTierGUI/configs.json
```

## 故障排除

### 问题：TUN device error: Operation not permitted

**解决方案**：确保使用 `sudo` 运行应用。

### 问题：找不到 easytier-core

**解决方案**：
1. 从 [EasyTier Releases](https://github.com/EasyTier/EasyTier/releases) 下载
2. 在设置中选择正确的可执行文件路径

### 问题：连接失败

**检查项**：
1. 网络名称和密码是否正确
2. 服务器地址是否可达
3. 防火墙是否允许连接
4. 查看日志了解详细错误

## 技术栈

- **语言**: Swift 5.9
- **框架**: SwiftUI, AppKit
- **架构**: MVVM
- **最低版本**: macOS 14.0

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

## 致谢

- [EasyTier](https://github.com/EasyTier/EasyTier) - 强大的 P2P 组网工具

## 联系方式

如有问题或建议，请提交 Issue。
