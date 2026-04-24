# Task 4: 快速日志输出稳定性测试

## 测试目标
验证应用在大量日志输出时的稳定性

## 背景
- 日志缓冲区已限制为 100 条 (EasyTierService.swift:65)
- 日志更新有 100ms 节流 (EasyTierService.swift:71)

## 手动测试步骤

### 1. 启用详细日志
- 打开设置
- 启用 "日志监控" (enableLogMonitoring)

### 2. 连接网络
- 点击连接，连接到有大量日志输出的网络
- 可以使用 `--verbose` 或类似参数增加日志量

### 3. 生成大量日志
让 EasyTier Core 运行一段时间，积累日志

**注意**: 这是一个自然测试 - EasyTier 会根据网络活动产生日志

### 4. 验证指标

| 验证项 | 检查方法 |
|--------|----------|
| UI 响应 | 点击各按钮，操作是否流畅 |
| 日志缓冲区大小 | 打开日志视图，查看条目数 |
| 内存使用 | 打开 Activity Monitor 查看内存 |
| 无崩溃 | 应用是否仍在运行 |

### 5. 手动生成更多日志 (可选)

```bash
# 强制产生日志的方法
# 1. 频繁连接/断开 peers
# 2. 触发网络流量
# 3. 等待 EasyTier 内部日志
```

### 6. 检查日志缓冲区行为

在日志视图观察:
```
- 日志条目数是否 ≤ 100
- 最新的日志是否在最前面
- 旧日志是否被正确移除
```

## 预期结果

```
UI 响应: 正常 (无 spinning ball)
内存: < 100 MB
日志数: ≤ 100 条
无崩溃: 是
```

## 验收标准

- [ ] 应用在 500+ 条日志时保持响应
- [ ] 日志缓冲区自动限制在 100 条
- [ ] 内存不随日志量线性增长
- [ ] 无崩溃或冻结
- [ ] 旧日志正确被移除

## 已知保护机制

1. **缓冲区限制** (EasyTierService.swift:491-493)
   ```swift
   if logEntries.count > maxLogEntries {
       logEntries.removeFirst(logEntries.count - maxLogEntries)
   }
   ```

2. **日志节流** (EasyTierService.swift:469-478)
   ```swift
   private let logUpdateThrottleInterval: TimeInterval = 0.1 // 100ms
   ```

3. **消息截断** (EasyTierService.swift:662-666)
   ```swift
   private func clippedLogMessage(_ message: String) -> String {
       guard message.count > maxLogMessageLength else { return message }
       // 截断过长消息
   }
   ```
