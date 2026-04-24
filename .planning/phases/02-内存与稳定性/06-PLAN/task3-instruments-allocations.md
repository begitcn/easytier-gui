# Task 3: Instruments Allocations 测试流程

## 测试目标
检测长时间运行后是否存在内存线性增长

## 手动测试步骤

### 1. 启动 Instruments
- 在 Xcode 中: Product → Profile (Cmd+I)
- 选择 "Allocations" 模板
- 点击 "Choose" 开始记录

### 2. 执行测试循环
```
共执行 20 次循环:
循环:
  1. 连接网络 (点击连接按钮)
  2. 等待 5 秒
  3. 断开网络 (点击断开按钮)
  4. 等待 2 秒
```

### 3. 观察 Allocations 面板

#### 关键指标
| 指标 | 期望值 |
|------|--------|
| Total Allocations | 稳定，无线性增长 |
| Heap (growth) | 每次循环后返回基线 |
| # Persistent | 稳定 |

#### 查看方式
1. 在 "Allocations" 面板
2. 展开 "Heap Cache" 和 "Malloc"
3. 查看 "Growth" 列
4. 理想情况: 每次断开后增长 ≤ 0

### 4. 常见泄漏模式检查

在 "Allocations" 搜索以下类型:

#### 检查 AnyCancellable 泄漏
- 搜索: `AnyCancellable`
- 期望: 0 个实例 (或极少)

#### 检查 Timer 泄漏
- 搜索: `NSCalendarTimer` 或 `Timer`
- 期望: 0 个实例

#### 检查网络相关对象
- 搜索: `EasyTierService`
- 期望: 断开后无实例

### 5. 记录数据

在测试过程中记录:
```
基线内存: __ MB
循环 5 次后: __ MB  
循环 10 次后: __ MB
循环 15 次后: __ MB
循环 20 次后: __ MB
```

## 验收标准

- [ ] 20 次循环后总内存增长 < 10MB
- [ ] 无线性增长趋势
- [ ] 断开后内存返回基线
- [ ] 无 AnyCancellable 累积
- [ ] 无 Timer 累积

## 预期结果

应用应该展示:
```
内存使用模式:
  连接时: +X MB
  断开后: 返回基线 (±Y MB)
  
线性增长: 无
```

如果存在线性增长，需要检查:
1. 是否有对象未释放
2. 是否有缓存未清理
3. 是否有日志累积
