---
layout: post
title: "fcitx5-rime 输入框内错误的拼音上屏"
tags: [fcitx5, input-method, rime, ]
author:
- wold9168
math: false
render_with_liquid: false
---

我有两台设备，两台设备都是 Fedora 42，安装 fcitx5-rime，并使用相同的配置文件。不过其中的一台，其输入法输入的时候会有奇怪的现象：输入码出现在候选项的右侧。

由于这两台设备使用的是相同的 rime 配置文件，所以我只能怀疑是 fcitx5 的问题，然而仔细搜索都没能找到蛛丝马迹。这样的问题实在难以轻易通过搜索引擎获得结果。尤其是这一症状难以轻易通过语言进行准确描述。

问题的情况如下图所示：

![对fcitx5的截图](/assets/imgs/2026-01-03-152451.png)

这一问题困扰我许久，群友 [samduanx](https://github.com/samduanx) 告诉我，这个问题可能和 rime 的 lua 有关。果真如此。

由于与没有发生问题的设备参照了不同的安装文档，问题机器上面没有安装`fcitx5-lua`和`librime-lua`。安装这两个包以后，问题消失。
