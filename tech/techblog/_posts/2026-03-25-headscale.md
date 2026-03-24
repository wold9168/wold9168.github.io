---
layout: post
title: "Headscale + 第三方 Derper 自建内网测试用 DERP 踩坑"
tags: [TLS, development, test, headscale, tailscale,]
author:
- wold9168
math: false
render_with_liquid: false
---

手里有个实验需要自建一个内网的 DERP 来测试一项目的网络栈性能。由于我没有使用 Tailscale 官方的服务器作为 Tailnet 后端，而是采用 Headscale，手里又没有可用的域名和证书，于是不得不关闭 TLS 校验。过程中发现文档驳杂，踩坑颇多，遂记录。

---

我首先参阅了这几篇文档和 Blog：

- [DERP - Headscale](https://headscale.net/stable/ref/derp/?h=)
- [Requirements and Assumptions - Headscale](https://headscale.net/stable/setup/requirements/)
- [tailcfg 包的 DERPNode 定义](https://pkg.go.dev/tailscale.com@v1.90.1/tailcfg#DERPNode)
- [headscale及derp server部署](https://ownding.com/2025/06/18/headscale%E5%8F%8Aderp-server%E9%83%A8%E7%BD%B2)
- [浅探 Tailscale DERP 中转服务](https://blog.kiprey.io/2023/11/tailscale-derp/)
- [重磅，Tailscale的Derp服务器原生支持自签发证书](https://blog.ysicing.net/tailscale-derper)
- [自建免备案防偷 Tailscale 国内中继（DERP）教程](https://blog.sleepstars.net/archives/ji-yu-docker-compose)

我的需求是，在我自定义的端口上运行 DERP 服务器（以免和我本机的 `80` 和 `443` 端口发生冲突），并且需要关闭客户端的 TLS 校验，因为我没有域名，也开不出有效的 TLS 证书。

这两个需求让我放弃了 Headscale Embedded DERP 这个好用的特性，因为 Headscale 的这个内嵌 DERP 服务器没有关闭 TLS 校验的能力，同时我也没摸索出来怎么指定这个 DERP 服务器的端口。

我先是将 `derp.urls` 置为 `[]` 禁用了 Tailscale 官方的 DERP 服务器。[^1] 该参数是一个订阅列表，用于从远程获取可用的 DERP 服务器列表。默认值是 `https://controlplane.tailscale.com/derpmap/default`。

[^1]: [DERP - Headscale](https://headscale.net/stable/ref/derp/?h=)

`derp.paths` 是用于控制 DERP 来源的另一个 JSON 对象，它存储文件路径的列表，直接指向一个 yaml 文件。这个 yaml 文件的格式需要参阅 [tailcfg 包的 DERPNode 定义](https://pkg.go.dev/tailscale.com@v1.90.1/tailcfg#DERPNode)。我采用的 `yaml` 文件如下。这个文件我们称之为`derpyml`

```yaml
regions:
  901:
    regionid: 901
    regioncode: int
    regionname: internal
    nodes:
      - name: 901a
        regionid: 901
        ipv4: 192.168.24.4
        hostname: 192.168.24.4:50443
        stunport: 53478
        stunonly: false
        derpport: 50443
        insecurefortests: true
```

阅读我前面提到的几篇 Blog。它们不约而同地提及修改 Tailscale ACL 的步骤。不过对于 Headscale 而言，在 `derp.paths` 指定的 yaml 文件中进行配置即足矣。Headscale 会将这份 yaml 定义的 DERP 配置作为 ACL 的一部分下发到 Tailscale 客户端。

`192.168.24.4`是我部署了 Derper 的内网 IP。该设备上我使用这样的一个 `docker-compose.yml` 文件创建对应的 Derper 容器。

```yaml
services:
  derper:
    image: ghcr.io/kaaanata/derper:latest
    container_name: derper
    restart: unless-stopped
    environment:
      - DERP_DOMAIN=192.168.24.4
      - DERP_CERT_MODE=manual
    ports:
      - '58080:80'
      - '50443:443'
      - '53478:3478/udp'
    volumes:
      - './cert:/app/certs'
```

我采用 [kaaanata/derper](https://github.com/kaaanata/derper-docker) 的这个镜像是有原因的。这个仓库是对`go install tailscale.com/cmd/derper`的直接封装。顺便一提，我其实还建议刚开始学习 Dockerfile 的用户阅读这个仓库的 Dockerfile，以学习 Docker 如何传递参数给容器。

第一个坑是 `derpyml` 中的 `hostname`。使用 IP 的作为 DERP 的接入点的时候，该 `hostname` 应该设置成 `IP:port` 的形式。 DERP 一般采用它的 `443` 端口进行通信。由于我们在 `docker-compose.yml` 里面将 `443` 端口映射到 `192.168.24.4` 的 `50443` 上，所以我们这里填写了 `192.168.24.4:50443`。

第二个坑是`DERP_CERT_MODE=manual`。[kaaanata/derper](https://github.com/kaaanata/derper-docker) 为这个参数采用的缺省值是 `letsencrypt`，即向 `Let's Encrypt` 申请证书。然而我们哪儿有什么域名可供证书申请！因而我们在这里的做法是将`DERP_CERT_MODE`设置为`manual`。阅读 [kaaanata/derper](https://github.com/kaaanata/derper-docker) 的 [Dockerfile](https://github.com/kaaanata/derper-docker/blob/main/Dockerfile)，我们知道这个变量被用于控制 Derper 的 `--certmode` 启动参数。将这个启动参数置为 `manual` 允许我们提供自签名证书。避免 Derper 向 `Let's Encrypt` 申请证书失败而阻塞。

[kaaanata/derper](https://github.com/kaaanata/derper-docker) 默认让我们将证书存放在 `/app/certs/` 这个目录下。我在上面的`docker-compose.yml`里设置了相应的文件映射。使用下面的 Shell 指令，我们可以生成一份自签名证书到当前目录的 `./cert` 目录下。

```sh
mkdir -p ./cert
export DERP_IP="192.168.24.4" # 改成你自己设备的 IP
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout ./cert/${DERP_IP}.key -out ./cert/${DERP_IP}.crt -subj "/CN=${DERP_IP}" -addext "subjectAltName=IP:${DERP_IP}"
```

我们需要在 `derpyml` 中设置 `insecurefortests: true` 以允许受试的 Tailscale 客户端跳过 TLS 检验。Headscale 的这个 `derpyml` 文件中的所有属性名都需要是小写。我试过在这里填写 [tailcfg 包的 DERPNode 定义](https://pkg.go.dev/tailscale.com@v1.90.1/tailcfg#DERPNode) 提供的 `InsecureForTests`，但是客户端中没有下发相应字段。希望 Headscale 未来可以修复这个问题。


在客户端上我们可以通过 `tailscale debug derp-map` [^2] 检查 Tailnet 后端下发的 DERP 配置。理想情况下这个配置项应该和我们上述填写的 `derp.yml` 内容一致。这项检查可以帮助我们检查 `derp.yml` 是否完整地被下发到客户端。

[^2]: (https://headscale.net/stable/ref/derp/?h=#check-derp-server-connectivity)

`tailscale debug derp headscale` 这一测试是不必要的。该测试不受 `InsecureForTests` 影响，始终会进行 TLS 校验。我们只需要确认 `tailscale status` 和 `tailscale ping` 工作正常即可。

以上。
