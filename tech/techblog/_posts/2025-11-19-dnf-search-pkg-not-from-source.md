---
layout: post
title: "判断 RPM 包是否来自于用户自己下载的 RPM 文件"
tags: [fedora, dnf, operation, ]
author:
- wold9168
math: false
render_with_liquid: false
---

可以使用 `dnf list --installed | grep "@"`来判断 RPM 包的来源。对于 `dnf5`，其使用 `dnf list --installed` 指令的时候会在指令输出的第三列附上包的来源。

并不来自于镜像源的包，其来源会被标注为 `@commandline`。

以下是示例：

```bash
❯ dnf list --installed | grep "@"
CherryStudio.x86_64                                  1.5.7-1                                       @commandline
brother-udev-rule-type1.noarch                       1.0.2-0                                       @commandline
brscan-skey.x86_64                                   0.3.2-0                                       @commandline
brscan4.x86_64                                       0.4.11-1                                      @commandline
dcpl2550dwpdrv.i386                                  4.0.0-1                                       @commandline
kmod-nvidia-6.14.0-63.fc42.x86_64.x86_64             3:580.95.05-1.fc42                            @commandline
kmod-nvidia-6.16.4-200.fc42.x86_64.x86_64            3:580.95.05-1.fc42                            @commandline
kmod-nvidia-6.16.7-200.fc42.x86_64.x86_64            3:580.95.05-1.fc42                            @commandline
linuxqq.x86_64                                       3.2.15_31363-1                                @commandline
upscayl.x86_64                                       2.15.0-1                                      @commandline
zfs-release.noarch                                   2-6.fc41                                      @commandline
zulu-repo.noarch                                     1.0.0-1                                       @commandline
```

我们可以看到这个指令的输出并不仅限于用户自己安装的包，`kmod-nvidia-*` 这个包，我认为它来自于 `akmod-nvidia`，因为我从来没有手动装过 NVIDIA 驱动。NVIDIA 驱动我一直都是使用 RPM Fusion 维护的 `akmod-nvidia` 这个包。

我们注意到 `akmod-nvidia` 和 `kmod-nvidia-*` 的 `SOURCERPM` 字段都是 `nvidia-kmod-580.95.05-1.fc42.src.rpm`，我没有找到 `akmod-nvidia` 的打包代码，不过应该就是 `akmod-nvidia` 安装了 `kmod-nvidia-*`。（这是一个草率的推断）。

总之这个指令很有用，可以帮助我们在系统更新的时候筛查来自于我们手动安装的包，尤其对不习惯使用镜像源，大量手动安装软件包的用户来说重要。然而我看网上介绍的人不太多。
