---
layout: post
title: "Golang Context 包速览"
tags: [golang, golang-pkg, development,]
author:
- wold9168
math: false
render_with_liquid: false
---

Golang Context库是Golang的官方库之一。

浏览这一[视频](https://www.bilibili.com/video/BV17K411H7iw)快速获取对该库的大概认识。

Golang Context的概念，比较接近Hadoop的Context，都是一个可以传递数据的、起管道作用的数据对象。但更本质而言，Context更应该是对Channel的封装。因而，该库在并发编程和网络编程中扮演核心角色。

该包是标准库中用于在 API 边界或 Goroutine 之间传递请求范围数据、取消信号、截止时间的核心机制。

## `context`的四种方法

`context.Context`是一个接口，定义了四种方法：

- `Done()`：返回一个只读的 `channel`，当 Context 被取消或超时时，该 channel 会被关闭。
- `Err()`：返回 Context 结束的原因（`context.Canceled` 或 `context.DeadlineExceeded`）。
- `Deadline()`：返回 Context 的截止时间及是否设置了截止时间。
- `Value(key interface{}) interface{}`：根据键获取关联的值，用于传递请求作用域的数据

## 创建`context`

| 函数 | 作用 | 典型场景 |
|---|---|---|
| `context.Background()` | 返回一个空的根 Context，无取消信号、无值、无截止时间。通常作为顶层请求的起点。 | `main` 函数、测试、初始化代码。 |
| `context.TODO()` | 与 `Background` 类似，但表示“此处暂不确定用哪个 Context”，是占位符。 | 代码重构过渡期，或函数签名要求传 Context 但暂未使用时。 |
| `context.WithCancel(parent)` | 创建一个可手动取消的子 Context，返回 `cancel` 函数。 | 手动控制一组 Goroutine 的生命周期（如用户主动取消操作）。 |
| `context.WithTimeout(parent, timeout)` | 创建一个在指定超时后自动取消的 Context。 | 网络请求、数据库查询等需要限时的操作。 |
| `context.WithDeadline(parent, deadline)` | 创建一个在指定绝对时间点自动取消的 Context。 | 需要精确截止时间的场景（如“北京时间 18:00 前必须完成”）。 |
| `context.WithValue(parent, key, val)` | 创建一个携带键值对数据的子 Context。 | 传递请求 ID、用户身份、认证令牌等元数据。 |

### Example: 超时控制

```golang
ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
defer cancel() // 确保释放资源

select {
case <-time.After(3 * time.Second):
    fmt.Println("操作完成")
case <-ctx.Done():
    fmt.Printf("操作取消：%v\n", ctx.Err()) // 输出：context deadline exceeded
}
```
