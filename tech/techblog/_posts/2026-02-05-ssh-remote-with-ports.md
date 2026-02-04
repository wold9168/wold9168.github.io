---
layout: post
title: "git-remote: 推送代码到带端口的 ssh 设备上"
tags: [git, ssh, development,]
author:
- wold9168
math: false
render_with_liquid: false
---

下述指令会为仓库设置一个 remote，该 remote 对应到 `foo.com` 这一设备的 `1122` 端口，以 `ssh` 协议进行通信。

```bash
git remote set-url origin ssh://git@foo.com:1122/user/reponame
```

正常通过 `git@foo.com:username/repo` 设置的 remote，默认应该只能与 `22` 端口进行通信。我没深究。

---

这几天在搓毕设，blog 荒废了。不过做毕设过程中积累了许多知识，感觉也值得一写。
