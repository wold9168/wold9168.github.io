---
layout: post
title: "DeepSeek Harness 的 retryPolicy"
tags: [llm, dsh,]
author:
  - wold9168
math: false
render_with_liquid: false
---

因为 DeepSeek 官方 API 涨价的缘故，我入手了 SCNet 的 Token Plan。

将 SCNet 的 Token Plan 接入 DeepSeek Harness，遭遇了大量的 429 报错，SCNet 的文档里没有提及报错信息为 ` {"message":"Model Request Error","type":"invalid_request_error","param":null,"code":"429"}` 的报错，倒是有说明其他报错信息的 429 报错。询问客服得知，SCNet 的 Token Plan 提供的 DeepSeek V4 Flash 0731 有一个 50 RPM 的限流，同时同一模型短时间内访问的人数过多也会触发限流。

注意到 DeepSeek Harness 允许为 provider 提供参数 `retryPolicy` 来定义该 provider 的重试策略。该参数的具体说明如下:

`retryPolicy` 是 provider 的一个配置项。对于 `llm-pi-ai`（DeepSeek Harness 为第三方模型提供接入的插件）而言，这一配置项应写在 provider 的配置里。它由 `llm-retry` 插件执行，后者监听 agent 循环中的 `agent/request-error` 事件，按 provider 注册时携带的策略决定重试的行为。

`retryPolicy` 有两种模式，通过 `mode` 字段选择：

`mode: normal`：缺省的情况。只对指定的错误码进行有限次重试。这是最常用的模式，包含以下字段：

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `maxRetries` | 数字 | `2` | 首次请求失败后的最大重试次数，不含首次请求本身 |
| `retryableCodes` | 字符串数组 | `["EMPTY_RESPONSE", "RATE_LIMIT", "SERVER", "TIMEOUT", "TRANSPORT"]` | 能够触发重试的错误码列表，不在列表中的错误不会触发重试 |
| `backoff` | 对象 | 见下文 | 退避策略 |

`mode: always`：对所有失败无限重试，直到请求成功、重试被取消或插件销毁。该模式下 `maxRetries` 和 `retryableCodes` 不可配置，而只能配置 `backoff`。

`backoff` 对象控制重试等待时长的计算方式，包含三个参数：

- `initialDelayMs`（默认 500，单位为 ms）：重试等待时长的初始值，即第 1 次重试的等待时间。第 N 次重试的等待时间为 `initialDelayMs × 2^(N-1)`。
- `maxDelayMs`（默认 10000，单位为 ms）：重试等待时长上界，计算出的重试等待时长超过此值时取此值。若 `initialDelayMs` 与 `maxDelayMs` 设为相同值，则重试等待时长的退避行为退化为固定间隔。
- `jitterRatio`（默认 0.1）：抖动幅度，取值范围 `[0,1]`。该值为重试等待时长叠加一个随机的偏移量，即：`基准延迟 × (1 - jitterRatio + 2 × jitterRatio × random())`。0 表示无抖动，0.1 表示 ±10% 波动。

顺带一提，`retryPolicy` 还有一个隐式行为：如果 provider 返回了 `retry-after` 响应头且其值不超过 `maxDelayMs`，llm-retry 会优先采用 provider 指定的延迟，而非本地计算的延迟值。

默认情况下，HTTP 429 状态码在 DeepSeek Harness 的适配层中被映射为错误码 `RATE_LIMIT`，`RATE_LIMIT` 在默认的 `retryableCodes` 列表中，因此即使不显式配置 `retryPolicy`，DeepSeek Harness 也会对错误码为 429 的报错进行缺省的重试策略。不过这种重试策略在面对 SCNet 在繁忙时段的频频 429 时并不好使。

对于我而言，解决方案就是在配置文件里加上这段：

```yaml
    scnet:
      apiKeyEnv: SCNET_API_KEY
      api: openai-completions
      baseURL: https://api.scnet.cn/api/llm/v1
      # 用 retryPolicy 指定该 provider 的重试策略
      retryPolicy:
        mode: normal
        maxRetries: 100 # 指定重试次数为 100 次
        retryableCodes: [ RATE_LIMIT ] # 该重试策略仅对 429 这种报错生效
        backoff:
          initialDelayMs: 500
          maxDelayMs: 5000
          jitterRatio: 0.1
      models:
        - id: DeepSeek-V4-Flash-0731
        # ...
```

