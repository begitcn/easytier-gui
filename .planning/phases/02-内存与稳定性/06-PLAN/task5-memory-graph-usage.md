# Task 5: Memory Graph Debugger 使用指南 (Phase 3 准备)

## 用途
用于检测内存泄漏、循环引用、以及 Phase 3 内存警告处理的开发调试。

## 何时使用

1. **开发阶段**: 实现内存警告处理后，验证内存释放
2. **调试阶段**: 怀疑有内存泄漏时
3. **测试阶段**: 连接/断开循环测试后验证清理
4. **发布前**: 确认无内存问题

## 如何打开

### 方法 1: Debug 导航器
1. 运行应用 (Cmd+R)
2. 打开 Debug 导航器 (Cmd+Shift+D)
3. 点击 "Memory Graph" 按钮

### 方法 2: 菜单
1. Debug → Memory Graph Debugger

## 界面说明

### 主要区域

```
┌─────────────────────────────────────┐
│ 搜索框                              │
├─────────────────────────────────────┤
│ 过滤器: All Heap, Allocations, etc │
├─────────────────────────────────────┤
│ 对象列表                            │
│  - Class Name                       │
│  - Instance Count                   │
│  - Size                             │
├─────────────────────────────────────┤
│ 详细信息面板                        │
│  - 引用关系图                       │
│  - 堆栈跟踪                         │
└─────────────────────────────────────┘
```

## 关键对象类型检查

### 1. Timer 对象
**搜索**: `Timer` 或 `NSCalendarTimer`

**期望**:
- 活跃网络: 1-2 个 Timer (peerTimer, privilegedLogTimer)
- 断开后: 0 个 Timer

**警惕**: 如果 Timer 数量 > 2，说明有 Timer 未 invalidate

### 2. AnyCancellable
**搜索**: `AnyCancellable`

**期望**:
- 每个 NetworkRuntime: 少量 (1-5 个)
- 断开后应减少

**警惕**: 数量持续增长说明 Combine 订阅未释放

### 3. EasyTierService
**搜索**: `EasyTierService`

**期望**:
- 活跃网络: 每个配置 1 个
- 断开后: 0 个

**警惕**: 断开后仍有实例说明未正确释放

### 4. NetworkRuntime
**搜索**: `NetworkRuntime`

**期望**:
- 活跃配置数: N
- 断开后: ≤ N

**警惕**: 数量 > 配置数说明有未释放的 runtime

## 颜色标识

| 颜色 | 含义 |
|------|------|
| 紫色 (紫色线条) | 强引用关系 |
| 红色 | 检测到的内存泄漏 |
| 橙色 | 可能的循环引用 |
| 绿色 | 可释放对象 |

## 检测循环引用

1. 打开 Memory Graph
2. 查找红色或橙色标记的对象
3. 点击对象查看引用图
4. 检查是否有互相持有的引用

## 内存警告场景 (Phase 3)

当实现内存警告处理时:

1. **收到内存警告**: `didReceiveMemoryWarning`
2. **清理策略**:
   - 清除非必要的缓存
   - 释放不活跃的 NetworkRuntime
   - 减少日志缓冲区

3. **验证清理**:
   - 使用 Memory Graph 确认对象释放
   - 对比警告前后的内存使用

## 常见问题模式

### 模式 1: Timer 泄漏
```
问题: peerTimer 未在 disconnect 时 invalidate
症状: Timer 实例数持续增长
解决: 确保 stopPeerPolling() 被调用
```

### 模式 2: Combine 订阅泄漏
```
问题: AnyCancellable 未存储或未取消
症状: AnyCancellable 实例数增长
解决: 使用 .store(in: &cancellables)
```

### 模式 3: 循环引用
```
问题: 两个对象互相持有强引用
症状: 紫色循环线，红/橙色标记
解决: 使用 weak 或 unowned
```

## 操作技巧

1. **过滤搜索**: 使用搜索框精确查找
2. **展开所有**: 按住 Option 点击展开
3. **复制信息**: 选中对象 Cmd+C 复制类名
4. **查看堆栈**: 双击对象查看创建堆栈

## 验收标准 (可接受的对象数)

| 对象类型 | 允许最大实例 |
|----------|--------------|
| Timer | 2 (仅活跃连接时) |
| AnyCancellable | 活跃配置数 × 5 |
| EasyTierService | 活跃配置数 |
| NetworkRuntime | 活跃配置数 |

## 相关代码位置

- NetworkRuntime deinit: ProcessViewModel.swift:60-67
- EasyTierService deinit: EasyTierService.swift:700-704
- Timer 清理: ProcessViewModel.swift:118-124
- 日志清理: EasyTierService.swift:491-493
