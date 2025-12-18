---
layout: post
title: "kvm2 中无法启动 Rocky Linux 10，Grub2 选择引导选项后重启并重新进入 Grub2"
tags: [rockylinux, virtualization, vm, grub2]
author:
- wold9168
math: false
render_with_liquid: false
---

症状如题。

原因为：我使用的设备，其 CPU 为 Intel(R) Xeon(R) E5-2696 v2。Rocky Linux 10 已经停止对架构（`x86_64-v2`）的支持。

参阅：[Rocky Linux 10 Release Note](https://docs.rockylinux.org/10/release_notes/)

如你同样遇到即便是安装盘也无法正常进行安装流程，卡在 Grub2 并且看不到任何报错，只有选择选项以后重新上电。那么不妨考虑一下 CPU 原因。AI 因为其知识库，只会向显示设置、显卡方面进行猜测。
