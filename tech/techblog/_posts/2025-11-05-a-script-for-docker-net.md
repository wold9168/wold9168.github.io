---
layout: post
title: "我写了一个脚本用来运维我的 Docker 网络"
tags: [docker, contain, operation, network]
author:
- wold9168
math: false
render_with_liquid: false
---

我在我的设备上部署新服务的时候经常使用这个指令：

```bash
❯ docker inspect -f '{{.Name}} - {{range .Containers}}{{.Name}} ({{.IPv4Address}}){{end}}' $(docker network ls -q)
bridge - docker-model-runner (172.17.0.3/16)unruffled_newton (172.17.0.4/16)playground (172.17.0.2/16)
host -
none -
tough-development-domain -
tough-general-business-domain - samba (172.18.0.3/16)WinApps (172.18.0.2/16)ollama-docker-app-1 (172.18.0.4/16)global-postgres (172.18.0.9/16)ollama (172.18.0.8/16)ollama-webui (172.18.0.5/16)ilo-fans-controller-ilo-fans-controller-1 (172.18.0.6/16)pdf2zh-pdf2zh-1 (172.18.0.7/16)
toughb-smartdns-resolve - smartdns (10.0.255.53/24)
webdav_default - webdav-webdav-1 (172.19.0.2/16)
```
这个指令的用处是，显示我现在所有的 Docker 网络，并且显示其下的容器，以及它们的 IP 地址和对应的子网掩码（准确来说是 CIDR）。这个指令如此有用，以至于我现在终端里输入`docker i`以后第一个出来的补全就是这个指令。

我通常用这个指令来查看我还能在哪些网段里使用哪些 IP 去为我设备上的其他服务提供稳定的服务，我有的时候会硬编码一个东西到`docker-compose.yml`里。其实一种更优雅的做法是我自己维护一个 DNS 服务器，然后把它设置为我 SmartDNS 的上游之一，再然后在这个 DNS 服务器里维护一份服务映射表，然而我觉得这样做还是很野蛮——人工维护终究比不过自动维护，最好还是有一种方法能直接让我把 Docker 里的容器拿出来，用一个专门的域名去指代。Kubernetes 用 CoreDNS 实现的服务发现就是这种思路，他们用一个`<service-name>.<namespace>.svc.cluster.local`这样格式的域名来发现服务，然后集群里的机器可以通过 CoreDNS 来查询到这个服务对应的域名。美中不足的是这个服务发现仅仅局限于集群内部，无法跨集群使用。我的毕业设计正与此有关。

扯远了。

现在我遇到的问题是`docker inspect -f '{{.Name}} - {{range .Containers}}{{.Name}} ({{.IPv4Address}}){{end}}' $(docker network ls -q)`这个指令并不会显示容器使用的端口。我更多时候是要获知容器使用的端口是哪些，这样我才能在写`docker-compose.yml`的时候正确规划我本机上的端口使用。

我是这样划分的：若无需要，`8000~8999`的端口全部划分给我自己部署的各种服务。比如我自己部署的前端站点，又或者是什么支撑性服务。归软件包管理器管的服务一般不会把端口丢在`8000~8999`这个范围内。就算真的有服务那么喜欢`8`开头的四位数端口号，那么它们也一般会选择`8080`、`8000`、`8088`、`8888`这样的端口号。我作一下特殊处理就好了。

为什么不用`10000`以上的端口号呢？因为一些应用程序进行临时通信的时候可能要用到`10000`以上的端口号。我以前使用 Trilium 的时候有时候会遇到端口占用的问题，这就是因为五位数端口号经常被火狐之类的应用抢占掉。`10000`以内的四位数端口号好些。`1~1023`是特权端口，通常预分配给一些系统软件了，干脆不必考虑。

又扯远了。

现在的情况是这样，我需要一个脚本，这个脚本会显示我本机所有的 Docker 网络，并且显示它们下面的容器，然后显示对应容器的 IP、子网掩码以及占用的端口对。

最后最好还能输出一个 Summary，告诉我我的 Docker 容器都用了哪些端口。

感谢 AI，我最后得到了这样一段 Bash 代码：

```bash
❯ cat `which docker-inspect-all.sh`
#!/bin/bash

# 临时文件存储所有 host ports
tmp_ports=$(mktemp)

# 遍历每个网络
while read -r net_id; do
  net_name=$(docker network inspect -f '{{.Name}}' "$net_id")

  containers_info=""
  while read -r name ip; do
    if [ -n "$name" ] && [ -n "$ip" ]; then
      # 获取端口映射并提取 host:container
      port_pairs=$(docker inspect "$name" --format='{{json .NetworkSettings.Ports}}' | \
        jq -r '
          to_entries |
          map(select(.value != null)) |
          map(
            .key as $k |
            .value[] |
            select(.HostIp == "0.0.0.0" or .HostIp == "") |
            "\(.HostPort):\($k | split("/")[0])"
          ) |
          join(" ")
        ' 2>/dev/null)

      # 收集 HostPort 到临时文件（用于 summary）
      if [ -n "$port_pairs" ]; then
        echo "$port_pairs" | tr ' ' '\n' | cut -d: -f1 >> "$tmp_ports"
        containers_info+="$name ($ip $port_pairs); "
      else
        containers_info+="$name ($ip); "
      fi
    fi
  done < <(docker network inspect -f '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{"\n"}}{{end}}' "$net_id")

  containers_info=$(echo "$containers_info" | sed 's/; $//')
  echo "$net_name: $containers_info"
done < <(docker network ls -q)

# 输出空行
echo

# 生成 Summary：去重、排序、转为逗号分隔
if [ -s "$tmp_ports" ]; then
  used_ports=$(sort -n -u "$tmp_ports" | tr '\n' ',' | sed 's/,$//')
  echo "Summary: Used host ports: $used_ports"
else
  echo "Summary: Used host ports: (none)"
fi

# 清理临时文件
rm -f "$tmp_ports"
```

它运行的效果如下：

```bash
❯ docker-inspect-all.sh
bridge: docker-model-runner (172.17.0.3/16); unruffled_newton (172.17.0.4/16); playground (172.17.0.2/16)
host:
none:
tough-development-domain:
tough-general-business-domain: samba (172.18.0.3/16 445:445); WinApps (172.18.0.2/16 3389:3389 3389:3389 8006:8006); ollama-docker-app-1 (172.18.0.4/16 5678:5678 8000:8000); global-postgres (172.18.0.9/16 8432:5432); ollama (172.18.0.8/16 7869:11434); ollama-webui (172.18.0.5/16 8080:8080); ilo-fans-controller-ilo-fans-controller-1 (172.18.0.6/16 8044:80); pdf2zh-pdf2zh-1 (172.18.0.7/16 7860:7860)
toughb-smartdns-resolve: smartdns (10.0.255.53/24 53:53)
webdav_default: webdav-webdav-1 (172.19.0.2/16 8001:80)

Summary: Used host ports: 53,445,3389,5678,7860,7869,8000,8001,8006,8044,8080,8432
```

我觉得这是一个值得进一步维护的项目。许多用户都需要这样一个轻量级的对本地容器使用资源情况的感知脚本。

我或许可以把这个项目拉起来，然后配上完整的打包设施，就当是练习软件打包了。
