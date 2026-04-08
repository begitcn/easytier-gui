# EasyTier GUI 运行说明

## ⚠️ 权限要求

EasyTier 需要 root 权限来创建 TUN 网络设备。因此，EasyTier GUI 应用需要以特权方式运行。

## 运行方式

### 方式一：使用启动脚本（推荐）

1. **首次运行**：
   ```bash
   cd /Applications/EasyTierGUI.app/Contents/MacOS
   sudo ./EasyTierGUI
   ```
   输入密码后应用将以 root 权限运行。

2. **创建启动脚本**（可选）：
   创建一个启动脚本 `run-easytier-gui.sh`：
   ```bash
   #!/bin/bash
   sudo /Applications/EasyTierGUI.app/Contents/MacOS/EasyTierGUI
   ```

   给予执行权限：
   ```bash
   chmod +x run-easytier-gui.sh
   ```

### 方式二：通过终端运行

1. 打开终端
2. 运行以下命令：
   ```bash
   sudo /Applications/EasyTierGUI.app/Contents/MacOS/EasyTierGUI
   ```
3. 输入您的管理员密码

### 方式三：配置 sudo 免密码（高级用户）

1. 编辑 sudoers 文件：
   ```bash
   sudo visudo
   ```

2. 在文件末尾添加：
   ```
   %admin ALL=(ALL) NOPASSWD: /Applications/EasyTierGUI.app/Contents/MacOS/EasyTierGUI
   ```

3. 保存并退出（按 `Ctrl+X`, 然后 `Y`, 最后 `Enter`）

4. 现在可以免密码运行：
   ```bash
   sudo /Applications/EasyTierGUI.app/Contents/MacOS/EasyTierGUI
   ```

## 🔍 故障排除

### 问题：TUN device error: Operation not permitted

**原因**：应用没有足够的权限创建 TUN 设备

**解决方案**：
1. 确保使用 `sudo` 运行应用
2. 检查您的账户是否有管理员权限
3. 尝试从终端运行以查看详细错误信息

### 问题：应用无法启动

**解决方案**：
1. 检查应用是否在"系统偏好设置" -> "安全性与隐私"中被阻止
2. 右键点击应用，选择"打开"
3. 在终端中运行以查看错误日志

## 📝 日志位置

应用日志输出到标准输出，如果从终端运行可以看到完整日志。

## ⚙️ 配置文件位置

配置文件保存在：
```
~/Library/Application Support/EasyTierGUI/configs.json
```

## 🚀 快速启动命令

创建一个别名，在 `~/.zshrc` 或 `~/.bash_profile` 中添加：
```bash
alias easytier-gui='sudo /Applications/EasyTierGUI.app/Contents/MacOS/EasyTierGUI'
```

然后就可以简单地运行：
```bash
easytier-gui
```
