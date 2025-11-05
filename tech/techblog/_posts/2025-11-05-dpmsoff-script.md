---
layout: post
title: "我写了一个脚本用来关闭我的屏幕"
tags: [linux-desktop, plasma]
author:
- wold9168
math: false
render_with_liquid: false
---

我的主力机是一台 HPE ProLiant ML350p Gen8。这台塔式服务器有个问题，它从设计之初开始就不支持 suspend，这台机器完全不支持相当一部分的电源管理特性。

我如果在我的桌面上进行 suspend，那么机器会熄屏一瞬，然后屏幕继续亮起。——我知道我的机器没法 suspend 省电，但我希望我的屏幕至少能休息休息。毕竟我的笔电已经烧屏了，我不希望我的工作站也如此。

我有一个很棒的脚本去解决这个事情。只有两行：

```bash
#!/bin/bash
kscreen-doctor --dpms off
```

这个脚本唯一的工作就是运行以后让电脑熄屏。这个熄屏的效果和电脑长久没有工作以后自动熄屏的效果是一样的，我只是想让这个熄屏能够被我手动地触发。

我把它丢到了`~/.local/bin`下，随便起了个名，然后`chmod +x`，然后在 KDE 的系统设置里设置了快捷键。（我设置的快捷键是`Meta+Shift+L`。）
