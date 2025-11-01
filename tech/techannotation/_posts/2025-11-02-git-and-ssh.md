---
layout: post
title: "Git 和 SSH：通过 SSH 进行 Git 部署"
tags: [git, ssh]
author:
- wold9168
math: true
render_with_liquid: false
---

这篇 blog 的灵感来源是[这个视频](https://www.bilibili.com/video/BV1gUy4B6EWP)。

我来概述一下视频的内容：我们其实不需要任何 Git 托管服务，我们其实可以直接通过 SSH 去连接一台服务器，然后直接在这台服务器上面做事情。我们的 Git 支持我们用 SSH 链接作 remote 仓库。

这个视频本质上是对[《Pro Git》](https://git-scm.com/book/en/v2)第四章的延伸。我重温了一下[《Pro Git》](https://git-scm.com/book/en/v2)第四章，又动了一下手，干脆写了这篇 blog。

## 环境部署

我拉了一个容器去做这个事情，顺带一提，`❯`是我宿主机的终端提示符。有时间我来介绍一下我现在的环境和设备。`root@736b3583d62c`这个当然就已经是容器内部终端显示的用户名和容器名了。

```bash
❯ cd `mktemp -d`
❯ docker run -itd --rm -v $(pwd):/data debian:13
736b3583d62c45a3d16a000b049f44d8c0a2825f727edc1e645f2a69c3bbc8a0
❯ docker exec -it 736b bash
root@736b3583d62c:/# apt update
root@736b3583d62c:/# apt install -y openssh-client openssh-server git
root@736b3583d62c:/# useradd -m git
root@736b3583d62c:/# echo git:pw123123 | passwd
root@736b3583d62c:/# # 我在这里输入了 Ctrl-D，这是一个实用的快捷键，用来结束终端运行
exit
❯ docker inspect -f '{{.Name}} - {{range .Containers}}{{.Name}} ({{.IPv4Address}}){{end}}' $(docker network ls -q) # 我很常用的一个指令，可以列出本机所有 Docker 容器以及其所处的网络，以及其 IP 和掩码
bridge - unruffled_newton (172.17.0.4/16) # 我们刚刚创建的这个容器被 Docker 随机给了一个名字，我们准备用这个 IP 去访问它
❯ ssh-copy-id git@172.17.0.4 # 将我们的密钥拷贝进去，进而免密码登录
❯ docker exec -it 736b service ssh start # 启动容器内的 ssh 服务，由于容器没有 init 进程，所以不能通过 systemctl 的形式启动
❯ docker exec -it 736b bash
root@736b3583d62c:/# ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0   4340  3724 pts/0    Ss+  21:19   0:00 bash
root        4128  0.0  0.0  11780  2880 ?        Ss   21:27   0:00 sshd: /usr/sbin/sshd [listener] 0 of 10-100 startups # 这个就是我们的 sshd 进程了
root        4136  0.5  0.0   4340  3736 pts/1    Ss   21:27   0:00 bash
root        4144  0.0  0.0   6404  3864 pts/1    R+   21:27   0:00 ps aux
```

## 部署裸仓库

裸仓库是什么？Git 的裸仓库（Bare Repository）是一种没有工作目录（working directory）的 Git 仓库。换言之，一个正常的 Git，把它的 `.git/` 拿出来，那这个 `.git/` 就是它的裸仓库了。

裸仓库是专为接收推送设计的。

裸仓库相关的参数是`--bare`，我们在容器里可以用`git init --bare foo`创建一个裸仓库

```bash
❯ ssh git@172.17.0.4 git init --bare foo
hint: Using 'master' as the name for the initial branch. This default branch name
hint: is subject to change. To configure the initial branch name to use in all
hint: of your new repositories, which will suppress this warning, call:
hint:
hint:   git config --global init.defaultBranch <name>
hint:
hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
hint: 'development'. The just-created branch can be renamed via this command:
hint:
hint:   git branch -m <name>
Initialized empty Git repository in /home/git/foo/
```

这个仓库也是可以正常拷贝下来的，并且还会出现让我们更改分支名的提示：

```bash
❯ git clone git@172.17.0.4:foo
Cloning into 'foo'...
warning: You appear to have cloned an empty repository.
hint: Using 'master' as the name for the initial branch. This default branch name
hint: is subject to change. To configure the initial branch name to use in all
hint: of your new repositories, which will suppress this warning, call:
hint:
hint:   git config --global init.defaultBranch <name>
hint:
hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
hint: 'development'. The just-created branch can be renamed via this command:
hint:
hint:   git branch -m <name>
hint:
hint: Disable this message with "git config set advice.defaultBranchName false"
```

`git push/pull/fetch`也都可以正常工作。

```bash
❯ ls
foo
❯ cd foo
❯ echo "123" > bar
❯ git add -A
❯ git commit --signoff -m "initial commit"
[master (root-commit) ec9da89] initial commit
 1 file changed, 1 insertion(+)
 create mode 100644 bar
❯ git push
Enumerating objects: 3, done.
Counting objects: 100% (3/3), done.
Writing objects: 100% (3/3), 746 bytes | 746.00 KiB/s, done.
Total 3 (delta 0), reused 0 (delta 0), pack-reused 0 (from 0)
To 172.17.0.4:foo
 * [new branch]      master -> master
```
