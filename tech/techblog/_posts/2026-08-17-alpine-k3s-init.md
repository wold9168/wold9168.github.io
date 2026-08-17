---
layout: post
title: "在alpine上安装k3s的踩坑"
tags: [alpine, k3s,]
author:
  - wold9168
math: false
render_with_liquid: false
---

我有一台 Dell Wyse 3040，此前一直没捡起来用。因为这台 Wyse 3040 是 2G+8G 的配置，系统盘实在太小了，也不知道拿来干什么好。想来随便装点什么就满了。

这两天有感于树莓派的新风扇又出了点问题，很吵。想调整 GPIO 电平来降低风扇电压，于是为其编译驱动。等待编译驱动的过程挺安闲，便想将这台 Wyse 3040 装起来作备用方案。

言归正传，由于这台3040的系统盘实在太小，于是我为其选择 Alpine v3.24 作为发行版。然后在其上安装 k3s。在这个过程中发现问题。具体的表征为，通过 `kubectl get nodes` 查看该 k3s 实例时，往往在隔了一段时间以后，能查看到两三次，除此以外便有各种报错：

```bash
$ kubectl --context thi get nodes
The connection to the server thi.tough:6443 was refused - did you specify the right host or port?
$ kubectl --context thi get nodes
The connection to the server thi.tough:6443 was refused - did you specify the right host or port?
$ kubectl --context thi get nodes
The connection to the server thi.tough:6443 was refused - did you specify the right host or port?
$ kubectl --context thi get nodes
The connection to the server thi.tough:6443 was refused - did you specify the right host or port?
$ kubectl --context thi get nodes
Error from server (ServiceUnavailable): the server is currently unable to handle the request (get nodes)
$ kubectl --context thi get nodes
Error from server (ServiceUnavailable): the server is currently unable to handle the request (get nodes)
$ kubectl --context thi get nodes
NAME              STATUS   ROLES    AGE     VERSION
toughnet-thin-1   Ready    <none>   9m43s   v1.36.3+k3s1
$ kubectl --context thi get nodes
The connection to the server thi.tough:6443 was refused - did you specify the right host or port?
```

首先是 k3s 的默认安装强依赖于 `ip_tables`、`iptable_nat`、`iptable_filter` 等内核模块。而 Alpine v3.24 缺省的 `linux-lts` 内核在编译时没有将这些模块编译进去，因为 Alpine 主要采用 nft 作为其路由表。这一问题使得该 k3s 实例反复重启。

将 kube-proxy 的 `proxy-mode` 置为 `nftables` 后，k3s 实例依旧死去活来，阅读日志知：k3s 的内置网络策略控制器对 `iptables` 同样有依赖，日志显示 `network_policy_controller.go:454` 抛出了一个 Panic：

```
F0817 14:24:08.403153   19759 network_policy_controller.go:454] failed to run iptables command to create KUBE-ROUTER-INPUT chain due to running [/var/lib/rancher/k3s/data/e1784de142752c8bc4497493cd3619f1edd74e766794812f339d7eb194d89ef4/bin/aux/iptables -t filter -S KUBE-ROUTER-INPUT 1 --wait]: exit status 3: modprobe: FATAL: Module ip_tables not found in directory /lib/modules/6.18.44-0-lts
iptables v1.8.11 (legacy): can't initialize iptables table `filter': Table does not exist (do you need to insmod?)
Perhaps iptables or your kernel needs to be upgraded.
panic: F0817 14:24:08.403153   19759 network_policy_controller.go:454] failed to run iptables command to create KUBE-ROUTER-INPUT chain due to running [/var/lib/rancher/k3s/data/e1784de142752c8bc4497493cd3619f1edd74e766794812f339d7eb194d89ef4/bin/aux/iptables -t filter -S KUBE-ROUTER-INPUT 1 --wait]: exit status 3: modprobe: FATAL: Module ip_tables not found in directory /lib/modules/6.18.44-0-lts
	iptables v1.8.11 (legacy): can't initialize iptables table `filter': Table does not exist (do you need to insmod?)
	Perhaps iptables or your kernel needs to be upgraded.
	

goroutine 18323 [running]:
k8s.io/klog/v2.(*loggingT).output(0xd6f2180, 0x3, 0x26ed7fd1a420, 0x26ed8e09ee00, 0x1, {0x3dca616?, 0x2?}, 0x5e6960?, 0x0)
	/go/pkg/mod/github.com/k3s-io/klog/v2@v2.140.0-k3s1/klog.go:980 +0x874
k8s.io/klog/v2.(*loggingT).printfDepth(0xd6f2180, 0x3, 0x26ed7fd1a420, {0x0, 0x0}, 0x1, {0x1a9432f, 0x3b}, {0x26ed8aa4bb80, 0x2, ...})
	/go/pkg/mod/github.com/k3s-io/klog/v2@v2.140.0-k3s1/klog.go:784 +0x1ed
k8s.io/klog/v2.(*loggingT).printf(...)
	/go/pkg/mod/github.com/k3s-io/klog/v2@v2.140.0-k3s1/klog.go:761
k8s.io/klog/v2.Fatalf(...)
	/go/pkg/mod/github.com/k3s-io/klog/v2@v2.140.0-k3s1/klog.go:1688
github.com/cloudnativelabs/kube-router/v2/pkg/controllers/netpol.(*NetworkPolicyController).ensureTopLevelChains(0x26ed8cd958c0)
	/go/pkg/mod/github.com/k3s-io/kube-router/v2@v2.6.3-k3s1/pkg/controllers/netpol/network_policy_controller.go:454 +0x38d
github.com/cloudnativelabs/kube-router/v2/pkg/controllers/netpol.(*NetworkPolicyController).Run(0x26ed8cd958c0, 0x26ed8ebf7d50, 0x26ed7ff1aaf0, 0x26ed8969e810)
	/go/pkg/mod/github.com/k3s-io/kube-router/v2@v2.6.3-k3s1/pkg/controllers/netpol/network_policy_controller.go:168 +0x151
created by github.com/k3s-io/k3s/pkg/agent/netpol.Run in goroutine 1390
	/go/src/github.com/k3s-io/k3s/pkg/agent/netpol/netpol.go:191 +0xef4
```

于是只得暂时将 network-policy 也一并禁用。

最后相比起 k3s 刚安装的状态，`/etc/rancher/k3s/` 目录下新添加了一个 `config.yaml` 文件，其内容如下：

```
$ cat /etc/rancher/k3s/config.yaml
kube-proxy-arg:
  - proxy-mode=nftables
disable-network-policy: true
```