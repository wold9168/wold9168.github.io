---
layout: post
title: "从 Legacy 启动到 UEFI 的迁移"
tags: [UEFI,]
author:
  - wold9168
math: false
render_with_liquid: false
---

现时 2026 年 7 月 27 日，下午 15 点 13 分。就在刚刚，我完成了我的 Fedora 43 实例从 Legacy 启动到 UEFI 启动的迁移工作。该迁移工作值得提及的点在于，其完全没有依赖于我预留的双系统设施以及系统救援盘，亦即，我全程仅使用启动方式被修改的目标磁盘上的 Fedora 实例完成了这一作业的全部过程。我认为这样的一段经历是值得分享的。（——简直让人不由玩心大起地高呼「欧姆弥赛亚」。）

需要注意的点在于，我的操作是慎之又慎，并且提早就关键数据做好了备份，且准备好了救援盘。 **如您不经准备而贸然参考我的经历，可能会将您的生产环境置于不可用的状态之中。** 在进行任何操作前，您需要详细阅读 Arch Wiki 上对 ESP 分区的描述[^1]，并就您不甚理解的知识点与 LLM 进行对答和梳理。任何关于文件系统、磁盘分区的技术作业都值得您以最为谨慎的姿态应对。

[^1]: https://wiki.archlinux.org.cn/title/EFI_system_partition

# 动机和目标

我原先使用的 HPE Proliant ML350p Gen 8 近期被我更换为了一台 ASUS ROG CROSSHAIR VIII DARK HERO。我仅将原有的系统盘[^2]迁移到了新设备上，以使得新设备开箱即用。

[^2]: 一块INTEL_SSDSC2BX800G4，即 Intel S3610 800 GB。该磁盘使用 SATA 接口。

```bash
$ fastfetch --logo none
wold9168@toughc-fedora
----------------------
OS: Fedora Linux 43 (KDE Plasma Desktop Edition) x86_64
Kernel: Linux 7.0.14-101.fc43.x86_64
Uptime: 16 mins
Packages: 87 (flatpak), 103 (nix-user), 10637 (rpm), 2 (snap)
Shell: zsh 5.9
Display (SKG2418): 1920x1080 in 27", 120 Hz [External]
DE: KDE Plasma 6.7.1
WM: KWin (Wayland)
WM Theme: Breeze
Theme: Breeze (Light) [Qt], Breeze [GTK3]
Icons: breeze [Qt], breeze [GTK3/4]
Font: Noto Sans CJK SC (10pt) [Qt], Noto Sans CJK SC (10pt) [GTK3/4]
Cursor: breeze (24px)
Terminal: kitty 0.43.1
Terminal Font: BlexMonoNF (16pt)
CPU: AMD Ryzen 9 5950X (32) @ 5.09 GHz
GPU: NVIDIA GeForce RTX 3060 [Discrete]
Memory: 11.33 GiB / 62.68 GiB (18%)
Swap: 0 B / 8.00 GiB (0%)
Disk (/): 589.03 GiB / 741.21 GiB (79%) - btrfs
Disk (/mnt/nvme0n1p1): 424.95 GiB / 476.94 GiB (89%) - btrfs
Local IP (enp5s0): 192.168.12.11/24
Locale: en_US.UTF-8
```

旧有的 HPE Proliant ML350p Gen 8 并不支持我使用 UEFI 进行启动，因此我当时安装本 Fedora 实例（下称 `toughc-fedora`）的时候，使用了 Legacy 启动的方案。这使得该 Fedora 实例在迁移到新设备上以后，我还要在新设备的 BIOS 里打开 CSM 以对该 Fedora 实例进行兼容。同时，新设备提供更丰富、全面的电源管理功能。（与之相对的是我的旧 ML350p 甚至不支持 suspend。）因此我迫切希望将此 Fedora 实例修改为使用 UEFI 启动——这样能使得我使用类似于 S2Idle 这样的系统睡眠层次。

我手头正好有一台笔记本，该笔电使用 UEFI 启动，这为我修改这台 `toughc-fedora` 的分区表时提供了重要的参考。我建议同样希望进行从 Legacy 启动到 UEFI 的迁移的其他用户，在进行该迁移作业前，找一台 UEFI 设备在手边进行参考。这样比较容易注意到那些资料与 LLM 都不曾回答的技术细节。

我对该迁移作业预设的目标是：将 `toughc-fedora` 实例的 Legacy 启动转换成 UEFI。把 `/boot` 合并到根文件系统里，不再保留独立分区。ESP 分区将被挂载到 `/boot/efi` 下。

# 分区方案思考

我为了为保留多个内核，为原先分区方案下的 `/boot` 划分了 4 GiB 的空间（initramfs 整得多是这样的）。新的 ESP 分区不需要那么多空间，所以我只给新的 ESP 准备了 512 MiB 空间，并让剩下 3.5 GiB 空间暂时不分配。我的主分区还没有拥挤到迫切需要这 3.5 GiB 空间的时候，并且我需要一段未分配的空间作为冗余，避免我和 LLM 计算错 ESP 分区的扇区号。

`toughc-fedora` 上初始的磁盘布局是：

```
sda1  1M          bios-grub
sda2  4G  /boot   ext4
# 中间空出来的 3.5G 丢掉不管
sda3  741G  /     (btrfs)
```

原分区中的 `sda1` 在新的分区中不保留。该 `sda1` 是 Legacy 启动所需的分区。

基于这样的设计，最终要达成的布局是：

```
sda1      512M  ESP (vfat, EF00)
unalloced 3.5G
# 中间空出来的 3.5G 丢掉不管
sda3      741G  / (btrfs)
```

# 扬了 `/boot` 分区……然后呢？

```bash
sudo sgdisk -d 1 -d 2 -n 1:0:+512M -t 1:ef00 /dev/sda
```

这条命令成功地把新分区表写到了磁盘上——`sda1` 变成了 512M 的 ESP，但紧接着我们遇到了：

```bash
sudo partprobe /dev/sda
Error: Partition(s) 1, 2 on /dev/sda have been written, but we have been
unable to inform the kernel of the change, probably because it/they are
in use.  You should reboot now before making further changes.
```

内核因为 `sda3` 仍在使用，拒绝重载整张分区表。这使得我们无法直接为 `/dev/sda1` 创建 FAT32 分区。

```bash
$ sudo mkfs.vfat -F 32 -n ESP /dev/sda1

mkfs.fat 4.2 (2021-01-31)
mkfs.vfat: unable to open /dev/sda1: No such file or directory
```

# 通过文件镜像操作块设备

我们有一种万能的方法来操作一个块设备，那就是`dd`指令。`dd`指令允许我们直接绕过内核无法更新分区表的限制，直接读写对应的块设备。

创建一个 512M 的文件，格式化成 vfat，在其中装好 GRUB，然后用 `dd` 把整个文件系统映像写到 `sda` 上正确的扇区偏移处。

```bash
dd if=/dev/zero of=/tmp/esp.img bs=1M count=512
```

格式化需要 loop 设备。然而这台机器上装了 `snapd``，loop0` 到 `loop3` 全部被 `snap` 的 squashfs 占据：

```bash
$ sudo losetup -a
/dev/loop1: /var/lib/snapd/snaps/snapd_26382.snap
/dev/loop2: /var/lib/snapd/snaps/snapd_27406.snap
/dev/loop0: /var/lib/snapd/snaps/core_17292.snap
/dev/loop3: /var/lib/snapd/snaps/core_17284.snap
```

新建一个 `loop4` 就好：

```bash
sudo mknod /dev/loop4 b 7 4
sudo losetup /dev/loop4 /tmp/esp.img
```

`mknod`是系统命令，用于创建块设备（block）或字符设备（character）的特殊文件。`/dev/loop4`则是要创建的设备文件的路径和名称。剩下的参数介绍如下：

- `b`：表示创建的是块设备（Block device）。块设备支持随机访问，以数据块为单位进行读写（如硬盘、U盘）。
- `7`：主设备号（Major Number）。7 在 Linux 内核中专门预留给 loop 设备驱动。
- `4`：次设备号（Minor Number）。4 表示这是该驱动管理下的第 4 个子设备（即 /dev/loop4）。

`losetup /dev/loop4 /tmp/esp.img` 则是将 `/tmp/esp.img` 的内容映射到 `/dev/loop4`。

## 创建文件系统

```bash
$ sudo mkfs.vfat -F 32 -n ESP /dev/loop4

mkfs.fat 4.2 (2021-01-31)
$ sudo blkid -s UUID -o value /dev/loop4

0A38-0F25
$ sudo mount /dev/loop4 /mnt

mount: (hint) your fstab has been modified, but systemd still uses
       the old version; use 'systemctl daemon-reload' to reload.
```

以上我们完成了对文件系统的创建。

## 安装 grub2

```
$ sudo grub2-install --target=x86_64-efi --efi-directory=/mnt --removable
sudo grub2-install --target=x86_64-efi --efi-directory=/mnt --bootloader-id=Fedora

grub2-install: error: /usr/lib/grub/x86_64-efi/modinfo.sh doesn't exist. Please specify --target or --directory.
grub2-install: error: /usr/lib/grub/x86_64-efi/modinfo.sh doesn't exist. Please specify --target or --directory.
```

这是因为我们当前处于 Legacy 启动的系统中，Grub 2 对此种自 Legacy 系统发起的 UEFI 安装有检查。我们可以使用 `--force` 强制执行 `grub2-install`

```bash
sudo grub2-install --target=x86_64-efi --efi-directory=/mnt --removable --force
# Installation finished. No error reported.
sudo grub2-install --target=x86_64-efi --efi-directory=/mnt --bootloader-id=Fedora --force
# EFI variables are not supported on this system.
# efibootmgr failed to register the boot entry: No such file or directory.
```

值得一提的是这里的 `--removable` 参数。该参数指示 `grub2-install` 把引导器写到了 ESP 上的 `/EFI/BOOT/BOOTX64.EFI`。正常情况下，UEFI 会读取 NVRAM 中的启动项，找到对应路径（如 `/EFI/fedora/grubx64.efi`）来启动。但如果 NVRAM 中没有启动项，或者启动失败，UEFI 会自动尝试 `/EFI/BOOT/BOOTX64.EFI` 这个固定路径。

## 使用 dd 将文件镜像写入块设备

我们已经完成了该文件镜像上的全部准备工作，接下来就是将其烧录到块设备中，并挂载到 `/boot/efi`。

我们首先卸载 `/dev/loop4` 设备，然后把整个文件系统映像写到 `sda` 上 ESP 对应的位置：

```bash
sudo dd if=/tmp/esp.img of=/dev/sda bs=512 seek=2048 count=1048576 conv=fsync
```

`sda1` 被设定为从 sector 2048 开始，长度 512M（1048576 个扇区）。进行这一烧录操作的时候，请务必确定 `dd` 指令的参数经过了您的再三核验，以免破坏其他分区的数据。

dd 将预制的 FAT32 文件系统直接写入这些扇区。完成后我们可以通过如下指令进行验证：

```bash
$ sudo dd if=/dev/sda bs=512 skip=2048 count=1 2>&1 | xxd | head -4
00000000: eb58 906d 6b66 732e 6661 7400 0208 2000  .X.mkfs.fat... .
00000010: 0200 0000 00f8 0000 3f00 2000 0000 0000  ........?. .....
00000020: fcff 0f00 0004 0000 0000 0000 0200 0000  ................
00000030: 0100 0600 0000 0000 0000 0000 0000 0000  ................
```

`mkfs.fat` 的签名表明至少我们新烧录的 ESP 分区其分区头没有问题。

# 通过 `/etc/fstab` 挂载 ESP 分区

注释 `/etc/fstab` 中挂载 `/boot` 的行，向 `/etc/fstab` 中加入这样的一行以挂载该 ESP 分区：

```
UUID=0A38-0F25  /boot/efi  vfat  umask=0077,shortname=winnt  0  2
```

此处的 UUID 来自于前面 `sudo blkid -s UUID -o value /dev/loop4` 指令的输出。剩下的几个参数都是固定的。

- `umask=0077`：设置挂载后文件和目录的默认权限掩码。`0077` 表示文件仅文件属主可读。
- `shortname=winnt`：有点技术债的意思。该参数指定了如何处理 `DOS 8.3` 短文件名。当 Linux 创建新文件时，如果文件名符合 8.3 规范（不超过 8 字符主名 + 3 字符扩展名），则同时生成对应的短文件名。
- `0`：该分区不会被 `dump` 命令自动备份
- `2`：系统启动时 `fsck`（文件系统检查工具）的扫描顺序。`0` 表示不检查；`1` 表示优先检查，一般用于根文件系统。其他所有的文件系统一般都分配为 `2`，个人的数据盘一般则是分配为 `0` 的。

使用 `sudo mount -a` 验证 `/etc/fstab` 的改动是否合法。如若提示 `/boot/efi` 这个路径不存在，可以用 `sudo mkdir -p /boot/efi` 手动创建一下。

# `/boot` 路径下的工作

```bash
sudo dnf reinstall -y "kernel-core-$(uname -r)"
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

重新安装内核，并且让 `grub2` 重新生成配置。

---

以上完成所有迁移工作。重启后，`toughc-fedora` 实例可以作为 UEFI 系统进行启动。