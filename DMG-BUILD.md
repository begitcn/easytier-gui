# DMG 打包脚本说明

EasyTierGUI 提供了三个 DMG 打包脚本，从简单到专业级别。

## 📦 打包脚本对比

### 1. `create-dmg.sh` - 简单版
**适用场景**: 快速测试、内部发布

**特点**:
- ✅ 最简单的实现
- ✅ 打包速度快
- ❌ 无自定义外观
- ❌ 无背景图片
- ❌ 无窗口布局

**使用方法**:
```bash
./create-dmg.sh [Debug|Release]
```

---

### 2. `create-dmg-pro.sh` - 专业版 ⭐ 推荐
**适用场景**: 正式发布、用户分发

**特点**:
- ✅ 自定义渐变背景
- ✅ 专业的窗口布局
- ✅ 图标精确定位
- ✅ 最大压缩率
- ✅ 美观的视觉效果
- ⚠️ 需要系统支持 Swift

**使用方法**:
```bash
./create-dmg-pro.sh [Debug|Release]
```

**效果预览**:
```
┌────────────────────────────────────────────┐
│                                    [×] [□] │
│                                            │
│      ┌──────────┐         ┌──────────┐    │
│      │          │         │          │    │
│      │   App    │   →→→   │  Apps    │    │
│      │   图标   │         │  文件夹  │    │
│      │          │         │          │    │
│      └──────────┘         └──────────┘    │
│                                            │
│           渐变背景 (深蓝色调)              │
│                                            │
└────────────────────────────────────────────┘
```

---

### 3. `create-dmg-enhanced.sh` - 增强版
**适用场景**: 需要完整文档和详细输出的场合

**特点**:
- ✅ 包含所有专业版功能
- ✅ 详细的执行日志
- ✅ 功能特性说明
- ✅ 输出文件大小信息

**使用方法**:
```bash
./create-dmg-enhanced.sh [Debug|Release]
```

---

## 🎨 自定义背景图片

专业版和增强版会自动创建渐变背景。如果需要自定义背景：

### 方法 1: 替换生成的背景
打包后修改 `.dmg-temp/.background/background.png`

### 方法 2: 使用自己的背景图片
在脚本中修改背景生成部分，或提供自定义图片：

```bash
# 在 create-dmg-pro.sh 中修改
cp /path/to/your/background.png "$TMP_DIR/.background/background.png"
```

**背景图片建议尺寸**:
- 宽度: 660px
- 高度: 400px
- 格式: PNG (支持透明)

---

## ⚙️ 自定义窗口布局

在 `create-dmg-pro.sh` 中可以调整这些参数：

```bash
# 窗口尺寸和位置
WINDOW_BOUNDS="100, 100, 760, 500"  # x, y, width, height

# 图标大小
ICON_SIZE=100

# 图标位置
APP_ICON_POS="160, 250"     # 应用图标位置
APPS_ICON_POS="500, 250"    # Applications 文件夹位置
```

---

## 🔧 高级选项

### 代码签名
如果需要对 DMG 进行代码签名：

```bash
# 签名 DMG
codesign --sign "Developer ID Application: Your Name" \
    --timestamp \
    --verbose \
    EasyTierGUI.dmg
```

### 公证
对于分发到其他 Mac 的应用，需要公证：

```bash
# 提交公证
xcrun notarytool submit EasyTierGUI.dmg \
    --apple-id "your@email.com" \
    --team-id "TEAMID" \
    --password "@keychain:AC_PASSWORD" \
    --wait

# 装订票据
xcrun stapler staple EasyTierGUI.dmg
```

---

## 🐛 常见问题

### Q: 背景图片创建失败
**A**: 确保 Swift 运行时可用。脚本会自动使用备用方案。

### Q: AppleScript 执行失败
**A**: 在"系统偏好设置 > 安全性与隐私 > 辅助功能"中添加终端。

### Q: DMG 打开后窗口布局不正确
**A**: 在 Finder 中重新打开 DMG，或手动调整窗口大小后关闭。

### Q: 打包速度较慢
**A**: 专业版需要创建背景图片和配置窗口，比简单版慢约 5-10 秒。

---

## 📝 推荐工作流

**开发阶段**:
```bash
./build.sh Debug
./create-dmg.sh Debug  # 快速打包测试
```

**发布阶段**:
```bash
./build.sh Release
./create-dmg-pro.sh Release  # 专业打包
# 可选：签名和公证
codesign --sign "Developer ID Application: ..." EasyTierGUI.dmg
```

---

## 🎯 快速开始

```bash
# 1. 构建应用
./build.sh

# 2. 打包 DMG (推荐专业版)
./create-dmg-pro.sh

# 3. 打开查看效果
open EasyTierGUI.dmg
```

打包完成后，DMMG 文件位于当前目录，可直接分发给用户安装。
