---
layout: post
title: "Flatpak 安装的 Joplin 无法打开的解决方案"
tags: [flatpak, joplin ]
author:
- wold9168
math: false
render_with_liquid: false
---

`net.cozic.joplin_desktop` 是 Flatpak 上一个常用的 Joplin 打包，在其 `stable` 分支的 `3.3.12` 版本中，许多用户遇到了 Joplin 无法启动的问题，我个人也不例外。

我还发现，如果清空 Joplin 的配置文件（`~/.config/joplin-desktop/`），那么 Joplin 是可以打开的，但是这样操作以后的 Joplin 很快就不再能打开。

[Derkades](https://github.com/Derkades) 在 [flathub/net.cozic.joplin_desktop #286](https://github.com/flathub/net.cozic.joplin_desktop/issues/286) 中给了一个很棒的解决方案：

```bash
pkill -9 joplin; sed -i 's/"isMaximized":true/"isMaximized":false/' ~/.config/joplin-desktop/window-state-prod.json; rm -f ~/.config/joplin-desktop/lock
```

这个指令的用处是，kill 当前所有的 `joplin` 进程，然后将 `~/.config/joplin-desktop/window-state-prod.json` 中的 `isMaximized` 参数置为 `false`，最后删除 `~/.config/joplin-desktop/lock` 这一锁文件。

望文生义，`~/.config/joplin-desktop/window-state-prod.json` 应该是记录 Joplin 窗口状态的文件。根据前述 issue 的消息，这一 bug 的成因尚且不明朗。 

恐怕在这个 bug 修复以前，我们都必须这样操作一番才能使用 Joplin 了。

顺带一提，不要把上面这个脚本保存成 `joplin-refresh` 这样命名的文件，否则最开始的 `pkill` 会直接把你的脚本杀掉。因为 `pkill foo` 匹配的是所有符合 `*foo*` 这个正则表达式的进程。
