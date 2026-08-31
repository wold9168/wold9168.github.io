---
layout: post
title: "镜像站运维日志"
tags: [operating, linux, docker,]
author:
  - wold9168
math: false
render_with_liquid: false
---

# Summary

我社团镜像 tunasync 同步任务大面积失败，初步排查发现镜像服务器日志盘爆满，ZFS 空闲空间小。起初我怀疑是 rsync 或 tunasync-worker 服务自身问题导致 tunasync 日志异常占用日志盘空间，但排查后排除此可能。我通过 `tail`、`wc` 与 `grep` 观察日志信息，确认 `/var/log/syslog.1` 中几乎全是 `dockerd` 的日志输出。进一步检查发现 `/var/lib` 同样被写满。使用 `ncdu` 分析 `/var/lib` 时，定位到 ClickHouse 容器占用空间异常。我通过 `docker inspect` 确认该容器由 Compose 管理，并由此找到其项目目录——重建了镜像，并且添加了日志大小限制。问题的根源在于镜像站上线的时候没有为 docker 加入全局的日志大小限制。


# 问题背景

我是 [HIT Mirror](https://mirrors.hit.edu.cn) 的 Rooter 之一。我在八月中注意到镜像站出现了部分镜像的 failed，我只当作是正常的连接数问题：我们的镜像站中的一部分镜像以友站的镜像为上游，如果同时与友站建立太多连接，那么相应的镜像同步过程可能会因为连接数过多而被中断。我因而也没有多想。

29 号起，大量的镜像进入 failed 状态。因没有有效的反馈与有效的 watchdog 机制，我社运维团队没能在第一时间注意到这一运维事件。事件直到 8 月 31 号时候我偶然访问镜像站以检测我宿舍网络对校园网的可达性时才被发现。具体的问题表征为：几乎所有的镜像都进入到了 failed 状态，少数几个镜像为 success。

# 排障过程

我迅速登入镜像站后台进行问题排查。然而 `/var/log/tunasync` 目录下所有的日志文件都是空文件。我姑且还是靠文件名判断以上问题在 29 号的时候集中爆发，因为大部分问题镜像最后一次镜像成功同步都是发生在 29 号，对应的日志文件后缀为`.log`而非`.fail`。我基于经验判断，认定镜像站大量镜像的 failed 与存储空间有关，于是使用`df -h`查看镜像站各磁盘空间占用。超乎我意料的是，ZFS 却仍有些微的空间。如若我没记错的话，应该是有数个 G 的空余大小。这正可以使得一部分上游更新不频繁的日志可以同步。然而这无法解释为什么日志文件为空。

我随即注意到镜像服务器的日志盘已经满容量，通过`ncdu`工具查询得知，`59G`的磁盘中，`syslog.1`便占据了`32G`。所幸，镜像服务器的`/tmp`分区足够大。我将该问题日志移入`/tmp`分区中，并使用`sudo tunasynctl restart -w worker`触发了一部分镜像的重新同步。

由于太久没有维护镜像站，我记错了 tunasync 的日志格式。tunasync 调用 `rsync` 的时候会自动加上 `-v` 参数，这使得日志中记录了大量镜像拉取期间所拉取文件的日志。由于镜像站主要由 [Cherrling](https://github.com/cherrling/) 进行管理。我因而以为这是 Cherrling 之前为了做某种调试或者实验而留下的临时性配置，并基于这一错误的假设浪费了些许时间。

我让 LLM 阅读了 tunasync 的代码，并确定镜像站正常工作状态下就是会让 tunasync 调用的 `rsync` 打印所同步文件的路径。然后我将目光转向我刚刚移出到 `/tmp` 的 `syslog.1`。这个文件太大了，使用`view`和`less`查看这个文件都不现实。我用`tail`指令查看了该文件的最后几行，注意到最后的一百行日志里几乎都是`dockerd`的日志。我因此使用`wc -l`和`grep -c "dockerd" /tmp/syslog.1`来判断文件的行数和`dockerd`字样出现的次数。果不其然，该文件规模来到了 82442836 行，其中出现 `dockerd` 的行数来到了 82105709。这让我确定了问题出现在 docker 上。

```sh
wold9168@mirrors-plus /tmp> sudo tail syslog.1
2026-08-30T00:05:18.250638+08:00 mirrors-plus dockerd[475020]: time="2026-08-30T00:05:18.250585091+08:00" level=error msg="Error writing log message" driver=json-file error="error writing log entry: write /var/lib/docker/containers/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb-json.log: no space left on device" message=
2026-08-30T00:05:18.253631+08:00 mirrors-plus dockerd[475020]: time="2026-08-30T00:05:18.253576935+08:00" level=error msg="Error writing log message" driver=json-file error="error writing log entry: write /var/lib/docker/containers/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb-json.log: no space left on device" message=
2026-08-30T00:05:18.256633+08:00 mirrors-plus dockerd[475020]: time="2026-08-30T00:05:18.256579368+08:00" level=error msg="Error writing log message" driver=json-file error="error writing log entry: write /var/lib/docker/containers/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb-json.log: no space left on device" message=
2026-08-30T00:05:18.259647+08:00 mirrors-plus dockerd[475020]: time="2026-08-30T00:05:18.259588008+08:00" level=error msg="Error writing log message" driver=json-file error="error writing log entry: write /var/lib/docker/containers/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb-json.log: no space left on device" message=
2026-08-30T00:05:18.262638+08:00 mirrors-plus dockerd[475020]: time="2026-08-30T00:05:18.262582555+08:00" level=error msg="Error writing log message" driver=json-file error="error writing log entry: write /var/lib/docker/containers/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb-json.log: no space left on device" message=
2026-08-30T00:05:18.265657+08:00 mirrors-plus dockerd[475020]: time="2026-08-30T00:05:18.265600303+08:00" level=error msg="Error writing log message" driver=json-file error="error writing log entry: write /var/lib/docker/containers/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb-json.log: no space left on device" message=
2026-08-30T00:05:18.268646+08:00 mirrors-plus dockerd[475020]: time="2026-08-30T00:05:18.268589591+08:00" level=error msg="Error writing log message" driver=json-file error="error writing log entry: write /var/lib/docker/containers/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb-json.log: no space left on device" message=
2026-08-30T00:05:18.271693+08:00 mirrors-plus dockerd[475020]: time="2026-08-30T00:05:18.271593748+08:00" level=error msg="Error writing log message" driver=json-file error="error writing log entry: write /var/lib/docker/containers/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb-json.log: no space left on device" message=
2026-08-30T00:05:18.274656+08:00 mirrors-plus dockerd[475020]: time="2026-08-30T00:05:18.274602805+08:00" level=error msg="Error writing log message" driver=json-file error="error writing log entry: write /var/lib/docker/containers/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb-json.log: no space left on device" message=
2026-08-30T00:05:18.277654+08:00 mirrors-plus dockerd[475020]: time="2026-08-30T00:05:18.277597549+08:00" level=error msg="Error writing log message" driver=json-file error="error writing log entry: write /var/lib/docker/containers/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb/1aedcff4c36c08d4e48760dd989d492270261a58ef42c87a5cb86f982a2ba4cb-json.log: no space left on device" message=
```

问题设备的 docker 只挂载了一个 ClickHouse。我通过 `ncdu` 工具统计该 ClickHouse 容器之 overlayfs 所在的 `/var/lib` 路径。结果发现该容器的日志文件竟然高达 47G 大小！俨然将 `/var/lib` 占满。此时我才后知后觉意识到 `/var/lib` 也已经爆满——`/var/lib`和`/var/log`在问题设备上是两个容量一样的独立挂载点。我因此下意识以为这两个挂载点乃是某种一盘多挂的情况，现在看来是我想多了。

我注意到 ClickHouse 的日志中最后出现了大量的无法写入报错：

```
Cannot log message in OwnAsyncSplitChannel channel: Cannot log message in OwnAsyncSplitChannel channel: Poco::Exception. Code: 1000, e.code() = 0, File access error: /var/log/clickhouse-server/clickhouse-server.err.log, Stack trace (when copying this message, always include the lines below):

0. Poco::RotateBySizeStrategy::mustRotate(Poco::LogFile*) @ 0x00000000245a1043
1. Poco::CombinedRotateStrategy::mustRotate(Poco::LogFile*) @ 0x000000002457d5fd
2. Poco::FileChannel::log(Poco::Message const&) @ 0x0000000024578d89
3. DB::OwnFormattingChannel::logExtended(DB::ExtendedLogMessage const&) @ 0x000000001f84ff59
4. DB::OwnRunnableForChannel::run() @ 0x000000001f85a061
5. Poco::ThreadImpl::runnableEntry(void*) @ 0x00000000245a7f0f
6. ? @ 0x0000000000094a83
7. __clone @ 0x0000000000125a44
 (version 26.3.17.110 (official build))Poco::Exception. Code: 1000, e.code() = 0, File access error: /var/log/clickhouse-server/clickhouse-server.log, Stack trace (when copying this message, always include the lines below):
```

由于不确定该 ClickHouse 数据库此先的部署情况，我使用 `docker inspect` 指令查看该 ClickHouse 容器的详细数据。对于一个由 docker compose 部署的容器而言，`docker inspect` 将会显示其 `com.docker.compose.project.working_dir` 属性——这是该容器 compose 对应项目文件夹的路径。我因此找到了该 ClickHouse 的 compose 文件夹。

我在 compose 文件中加入了限制日志大小和日志数量的配置项：

```yaml
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

并在确认相应的数据在 ZFS 池上有持久化的挂载点以后重建了容器：

```sh
$ sudo docker compose down && sudo docker compose up -d --pull never
```

至此问题仅剩 ZFS 爆满的问题。存储方面，由于镜像站的服务器 ZFS 池子之前似乎有点问题，Cherrling 许久以前说过他在整顿，于是我便将剩下的维护工作交由 Cherrling 进行。——应该也只是移除掉一些用得少的镜像。

~~Cherrling 的恩情还不完 ✋😭✋。~~

# 问题分析

根据我的排障过程，我分析问题的发生可能是这样的过程：

- 镜像站的存储后端（ZFS）爆满了
- ClickHouse 无法将数据写入 ZFS 池，因此以毫秒为单位快速生成报错日志，容器内日志存在于容器 overlayfs，迅速填满 `/var/lib`。
- `/var/lib` 写满以后，`dockerd` 开始大量报错，`syslog` 中出现巨量 `dockerd` 的报错信息，因此 `/var/log` 爆满
- `/var/log` 的爆满导致了 tunasync 在同步过程中无法正常将日志写入磁盘，进而导致了镜像的大面积 failed。只有少数几个镜像因为磁盘资源的波动而短暂地被观测到 success。


# 教训

业务环境中的 docker 服务应提前设置日志大小上界。