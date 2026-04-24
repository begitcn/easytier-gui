# Task 2: Memory Graph Debugger 测试流程

## 测试目标
验证 NetworkRuntime、EasyTierService 在连接/断开循环后正确释放资源

## 代码已有清理逻辑

### NetworkRuntime (ProcessViewModel.swift:60-67)
```swift
deinit {
#if DEBUG
    print("[DEBUG] NetworkRuntime deinit - id: \(id)")
#endif
    peerTimer?.invalidate()
    peerTimer = nil
    cancellables.removeAll()
}
```

### EasyTierService (EasyTierService.swift:700-704)
```swift
deinit {
    // Clean up timer if still running
    privilegedLogTimer?.invalidate()
    privilegedLogTimer = nil
}
```

## 手动测试步骤

### 1. 准备
- 用 Debug 模式运行应用 (Cmd+R)
- 打开 Debug 导航器 (Cmd+Shift+D)

### 2. 执行连接/断开循环 (重复 10 次)
```
循环:
  1. 点击"连接"按钮
  2. 等待 5 秒
  3. 点击"断开"按钮
  4. 等待 2 秒
```

### 3. 暂停并检查内存图
- 按 Cmd+. 暂停应用
- 在 Debug 导航器点击 "Memory Graph"
- 搜索以下对象类型:

#### 检查项
| 对象类型 | 预期状态 | 关注原因 |
|----------|----------|----------|
| NetworkRuntime | 无实例或少数实例 | 断开后应释放 |
| EasyTierService | 无实例或少数实例 | 断开后应释放 |
| Timer | 0 个活跃 | peerTimer 应已停止 |
| AnyCancellable | 少量 | 订阅应已清理 |

#### 在内存图中搜索
1. 在顶部搜索框输入: `NetworkRuntime`
2. 查看 Instance Count 列
3. 如果 > 活跃配置数，有泄漏风险

### 4. 检查控制台输出
在控制台过滤: `[DEBUG] NetworkRuntime deinit`

**预期**: 每次断开后应看到 "NetworkRuntime deinit" 消息

### 5. 检查 Timer 泄漏
在内存图搜索: `Timer` 或 `NSCalendarTimer`
- 期望: 0 或极少实例
- 如果有多个活跃 Timer，说明未正确清理

## 验收标准

- [ ] 10 次连接/断开后，NetworkRuntime 实例数 ≤ 活跃配置数
- [ ] 控制台显示 "NetworkRuntime deinit" 消息
- [ ] Timer 实例数为 0
- [ ] AnyCancellable 无明显泄漏

## 常见问题

### 如果发现泄漏
1. 检查是否有强引用循环
2. 检查 timer 是否在 deinit 前被 invalidate
3. 使用 "Retain Cycle" 查找工具

### 如果 Timer 泄漏
- 检查 stopPeerPolling() 是否被调用
- 检查 stopPrivilegedLogPolling() 是否清理
