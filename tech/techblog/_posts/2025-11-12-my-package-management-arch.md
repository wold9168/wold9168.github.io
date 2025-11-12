---
layout: post
title: "我的包管理方案"
tags: [package-management]
author:
  - wold9168
math: false
render_with_liquid: false
---

## 理念

作为一个使用「传统 Linux」（相对于 Nix 和 Fedora Silverblue 这样使用新兴方案管理发行版软件的发行版而言）的用户，我对包管理有一套自己的想法。

我的软件管理理念可概括为以下几点：

- 编程语言包管理器设施：优先使用语言原生的隔离机制
  在开发过程中，应优先使用对应编程语言提供的隔离环境，例如 Python 的 `venv`。同时，应允许语言工具将依赖缓存到用户级目录中，如 `~/go`（Go）、`~/.cargo`（Rust）、`~/.m2`（Maven）等。这类机制本质上是一种**用户级包管理器**，应作为首选方案。
  - **对于缺乏原生包管理器的语言（如 C++）**，若编译过程依赖系统提供的第三方库，建议使用容器进行环境隔离[^1]。
  - **应尽量避免直接依赖系统级第三方库**，除非你正在为该发行版贡献代码，或需要严格与发行版版本保持一致。在大多数情况下，应自行维护一个本地目录存放这类无包管理支持的第三方库，并手动更新。这可作为对包管理能力较弱的构建系统（如 CMake）的一种兜底策略。
  - 应该分离管理编程语言工具链和编程语言软件包的这两种包管理器设施。这两个设施应该独立运作。同时避免编程语言工具链的设施挤兑操作系统提供的编程语言工具链。
- 用户级包管理器：管理低系统集成度的软件
  使用如 Flatpak 等容器化用户级包管理器来安装**仅为当前用户服务**的软件。这类软件通常与系统集成度低，或无需与系统服务深度交互（例如大多数 GUI 应用）。
- 系统级包管理器：专用于高集成度系统组件
  系统级包管理器（如 `dnf`、`apt`）应仅用于管理**高系统集成度**的软件包——即那些需要调用其他系统服务、常驻运行、或对系统整体功能至关重要的组件。
  - 所有用户级包管理器（如 Flatpak）及其运行时，以及编程语言的包管理工具（如 `pipx`、`pnpm`），**应由系统级包管理器安装**，以确保其基础依赖和安全性受控，并且获得可靠、及时的更新。
    - 对于系统包管理器未覆盖的实用工具（一般是开发过程中需要使用的一些 CLI 工具，比如 `usql`），可通过编程语言包管理器安装（如用 `pipx` 安装 PyPI 工具，用 `pnpm` 管理全局 NPM 包）。
    - 应该特别指出，**浏览器属于系统级软件**。例如，Firefox 或 Chromium 在打开下载文件时会调用系统文件管理器，因此不应使用 Snap 或 Flatpak 等沙箱版本，而应通过系统包管理器安装。
- 用户自维护容器：用于开发与测试的常驻服务
  在开发或学习场景中，若需依赖常驻服务（如数据库），建议由用户自行维护容器实例，实现环境隔离。
  - 例如，我本地运行两个 PostgreSQL 实例：
    - 一个由操作系统提供，**完全不修改**，仅作为系统组件存在；
    - 另一个通过 Docker 容器在 `8432` 端口运行，专用于开发、测试和学习。
- 对于上述所有设施都无法覆盖而软件包，考虑将其安装到 `~/.local/bin/` 中。同时用户应该为自己的系统维护一份系统日志，记录这部分软件包的安装情况，尤其是需要记录这部分软件包在系统中维护的数据库文件、配置文件以及其卸载脚本的路径和使用方法。

这其中的原则就是，尽量在尽可能小的粒度上满足用户对软件包和依赖的需要，同时满足软件包对依赖（尤其是那些需要拉起来服务的依赖）的需要，尽量避免使用系统级包管理器对系统进行不必要的操作。

Fallback 的路径是：

1. 仅在项目中使用，**（项目用）编程语言设施**[^2]
2. 如若有在项目外使用的需求，或者需要 GUI 支持，**用户级包管理器**
3. 如若不能满足软件包依赖或者需要与系统环境交互，**编程语言设施**
4. 如若需要常驻在系统内并与系统级软件包提供的软件设施紧密集成，**系统级包管理器**
5. 如若系统级包管理器仓库没有提供对应的软件，**编程语言设施**
6. 如若编程语言设施仓库没有提供对应的软件，**手动管理**

---

[^1]: 出于类似原因，不建议在 Linux 系统中安装可能劫持编译链的第三方包管理器（如 Homebrew）。其自带的 `pkg-config` 可能在编译时优先链接非系统库，导致构建行为不可预测。

[^2]: 例如 `pdm`。

## 工程实践

我系统中的包管理设施情况如下：

- 系统级包管理：`dnf`
- 用户级包管理：`flatpak`
- 编程语言设施[^3]
  - 项目内使用的编程语言包管理器[^6]：
    - `pdm`（通过 `pipx` 安装，管理 Python 项目）
    - `bun`（通过 `dnf` 安装，管理 JavaScript 项目）
    - `mvn`（通过 `dnf` 安装，管理 Java 项目）
    - `cmake`（通过 `dnf` 安装，管理 C/C++ 项目）[^4]
    - `cargo`（通过 `rustup` 安装，管理 Rust 项目）
    - `go`（通过 `dnf` 安装，管理 Go 项目）
    - `pip`（通过 `pdm` 先行拉起 `venv` 环境，如果一些包只能通过 `pip` 安装再考虑）
    - `gem`（通过 `dnf` 安装，管理 Ruby 项目）
  - 管理编程语言工具链的包管理器[^7]：`jenv`（手动安装在 `~/.local/bin/`，但是所有的 Java 语言运行时来自于 `dnf`）
    - `rbenv`（通过 `dnf` 安装[^5]）
    - `fnm`（通过`cargo`安装，因为`dnf`仓库里没有，管理 JavaScript 运行时）
    - `rustup`（通过 `dnf` 安装）
    - `uv`（通过`dnf`安装，管理本地 Python 运行时[^5]）
  - 管理编程语言软件包的包管理器：
    - `pipx`（管理所有跨项目使用的 Python 包，其实 `uv` 可能还更好用，但我 `pipx` 用习惯了）
    - `go`（管理所有跨项目使用的 Go 包）
    - `cargo`（管理所有跨项目使用的 Rust 包）
    - `pnpm`（管理所有跨项目使用的 JS/TS 包）
    - X-cmd（作为前述所有工具在 CLI 工具领域的兜底，使用其安装脚本（安装在 `~/.local/bin/`））
- 容器设施：Docker、K8s[^8]
- 在家目录下维护了一个 `~/docker/` 目录，其中存放所有运行在本机上的 Docker 容器的 Docker Compose 文件，例如`smartdns`（我的 DNS 服务）和`postgresql`（我的 SQL 服务，用来学习 PostgreSQL、自行开发的时候使用，以尽量避免使用发行版提供的那个），还有`ilo-fans-controller`（给我的灵车 ProLiant ML350p Gen8 提供风扇调速）

[^3]: 最麻烦的东西

[^4]: 姑且也算包管理器罢……

[^5]: 同时 `dnf` 也维护一个默认使用的编程语言运行时。不过就 Python 的情况而言，`dnf` 提供的那个 Python 运行时不安装 `pip`。这是因为 Fedora 仓库里没有往 `/lib/python3.xx/site-packages/` 这个路径下塞 `EXTERNAL-MANAGED` 文件，导致你其实可以通过`dnf` 提供的 `pip` 去狠狠破坏系统。这太野蛮了。

[^6]: 有时候与编程语言运行时强绑定，有时候则不然，看情况

[^7]: 需要保证这一级的包管理器依赖的编程语言运行时来自于系统级软件包

[^8]: K8s 我还在学，所以几乎没有使用 K8s 部署任何东西

如果一个软件包的部署行为比较奇怪（比较难安装，或者单纯是你选择了不符合直觉的包管理器去管理它），比如你为其创设了什么配置文件，而配置文件不好迁移或者不具有普遍性（只在这台设备上生效），那么你最好为它写一份系统日志。可参见下文「为系统维护的日志怎么写？」。

### 自己维护的软件包呢？

分情况。我不太会打包，所以大部分时候我自己维护系统使用的小脚本是不会打包的，只是简单传一个 GitHub 仓库，最多写一个 MakeFile 做个复制工作（复制到 `~/.local/bin/`）。绝大部分情况下都是指挥 AI 写一个 Shell 脚本或者 Golang 小项目解决一个很切实的工程问题，然后把对应的文件丢到 `~/.local/bin/`。

反正我不会让我正在进行工程验证的包进入到我现在实际在用的系统的包管理器里，一般都是把它丢到容器里。毕竟进到包管理器里的话，找起来还是很麻烦的。

### AppImage 呢？

手动丢到 `~/.local/bin/` 里然后为系统维护日志。

### 为系统维护的日志怎么写？

标注日期，以及用特定符号（我是用井号「#」）标注出关键词。

在这里以我某日为 Waydroid 调整 SeLinux 而写的日志为例：

```
20250821 #waydroid #selinux
waydroid和selinux打架: https://bugzilla.redhat.com/show_bug.cgi?id=2359206
在/etc/waydroid-extra下留了镜像，卸载waydroid以后可以移除
修改了/etc/selinux/config，使得SELINUX=permissive，原值为SELINUX=enforcing
```

日志只要要说清楚这样几件事：

- 对系统做了什么变更
- 这项变更是出于什么目的做的？这种操作的依据是什么（如果有的话）？
- 这项操作怎么进行逆操作（改了什么设置，怎么改回来）

同时对应的设置处也应该留相关的注释。

这里是我「为 Waydroid 调整 SeLinux」这项工作里对系统做了修改的地方：

```
❯ cat /etc/selinux/config

# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#     enforcing - SELinux security policy is enforced.
#     permissive - SELinux prints warnings instead of enforcing.
#     disabled - No SELinux policy is loaded.
# See also:
# https://docs.fedoraproject.org/en-US/quick-docs/getting-started-with-selinux/#getting-started-with-selinux-selinux-states-and-modes
#
# NOTE: In earlier Fedora kernel builds, SELINUX=disabled would also
# fully disable SELinux during boot. If you need a system with SELinux
# fully disabled instead of SELinux running with no policy loaded, you
# need to pass selinux=0 to the kernel command line. You can use grubby
# to persistently set the bootloader to boot with selinux=0:
#
#    grubby --update-kernel ALL --args selinux=0
#
# To revert back to SELinux enabled:
#
#    grubby --update-kernel ALL --remove-args selinux
#


# SELINUX=enforcing
SELINUX=permissive

# SELINUXTYPE= can take one of these three values:
#     targeted - Targeted processes are protected,
#     minimum - Modification of targeted policy. Only selected processes are protected.
#     mls - Multi Level Security protection.
SELINUXTYPE=targeted
```

哪怕系统因为 SeLinux 爆了，想不起来对 SeLinux 做了哪些修改，也可以在受限情况下（起码 tty 还能拉起来作系统救援）通过 `vim` 快速检索相应的标签。

日志应该用 `git` 维护一个仓库起来，并且**不应该设置为公开仓库**。以避免潜在的安全风险。
