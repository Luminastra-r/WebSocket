# Xray REALITY 部署指南

使用 Docker 在自己的 Linux 服务器上运行 Xray（VLESS + REALITY），并在电脑端使用 Clash Verge Rev 的 Mihomo 内核连接。项目名称沿用 WebSocket，实际传输方式为 TCP + REALITY，不使用 WebSocket。REALITY 不需要为服务器申请 TLS 证书。

## 你需要准备什么

- 一台有公网 IPv4 或 IPv6 的 Linux 服务器和 SSH 登录方式；建议 Ubuntu/Debian，1 核 1 GB 内存可用于轻量使用。
- 服务器能够访问 GitHub 和容器镜像仓库；TCP 443 未被占用，并在云服务商安全组和系统防火墙中开放。
- Docker 和 Docker Compose 插件（`docker compose version` 可用）。命令需要有 Docker 权限；必要时使用 `sudo`。
- 电脑端安装 [Clash Verge Rev](https://www.clashverge.dev/) 并使用 Mihomo 内核。

服务器公网 IP 用于客户端连接；下面的 REALITY 目标域名是另一个可从服务器访问的 HTTPS 网站，两者不是同一个地址。无需为服务器配置域名，但若使用自己的域名连接，它必须解析到服务器。

## 一、让 AI Agent 部署

可以通过 Codex、Trae、WorkBuddy 等支持终端操作的工具登录或连接到服务器工作目录，提供本项目仓库地址及下方提示词。不要把 SSH 密码、私钥或客户端配置发到公开聊天、Issue 或仓库中。先检查 Agent 将要执行的系统和防火墙操作。

```text
请在我的 Linux 服务器上部署这个仓库的 Xray VLESS + REALITY 服务。
先检查 Docker、Compose、443 端口及防火墙；缺少依赖时说明并安装。
按 README 生成新的 UUID、REALITY 密钥对和 short ID，使用配置模板创建
config/config.json，确保目标域名和 serverNames 一致，然后验证配置并启动。
生成完整的 Mihomo YAML 文件供 Clash Verge Rev 导入，检查容器状态。
不要提交或公开私钥、UUID、客户端配置和运行日志；不要覆盖已有服务。
```

也可以按下面的步骤手动完成。以下命令在服务器终端执行。

## 二、获取项目并生成配对信息

```bash
git clone https://github.com/Luminastra-r/WebSocket.git
cd WebSocket
mkdir -p logs
# 生成 UUID
docker run --rm ghcr.io/xtls/xray-core:latest uuid
# 生成 REALITY 密钥对
docker run --rm ghcr.io/xtls/xray-core:latest x25519
# 生成 16 位十六进制 short ID
openssl rand -hex 8
```

妥善记录 UUID、short ID 和密钥对。不同 Xray 版本的输出可能将公钥标为 `Public key` 或 `Password`；将它作为客户端的 `public-key`。`Private key` 只放在服务端。请勿把这些值提交到 GitHub；客户端 YAML 也应作为敏感文件保存和传输。

## 三、配置并启动服务端

```bash
cp config/config.template.json config/config.json
nano config/config.json
```

替换模板中的 `{{UUID}}`、`{{PRIVATE_KEY}}` 和 `{{DOMAIN}}`。例如保留模板的 `dest` 为 `www.microsoft.com:443`，则 `{{DOMAIN}}` 填 `www.microsoft.com`；将 `shortIds` 数组中的 `0` 替换为上一步生成的 short ID。目标网站需从服务器可访问且支持 REALITY；更换时同时修改 `dest` 和 `serverNames`，并在客户端同步 `servername`。

模板没有启用 Vision flow，客户端也不要填写 `flow`。保存后执行：

```bash
chmod 600 config/config.json
docker compose build
docker compose run --rm --no-deps xray-proxy run -test -config /usr/local/etc/xray/config.json
docker compose up -d
docker compose ps
docker compose logs --tail=50 xray-proxy
```

配置检查通过、容器保持运行后继续。修改配置后执行 `docker compose restart`。默认监听服务器 TCP 443；如需改端口，同时修改 Compose 端口映射、服务器防火墙和客户端端口。

## 四、生成并导入 Clash 配置

在自己的电脑上创建 `clash.yaml`，将尖括号内容替换为自己的值；不要保留尖括号。使用安全方式传递参数，不要公开分享该文件。

```yaml
mixed-port: 7890
allow-lan: false
mode: rule
log-level: warning
proxies:
  - name: 我的服务器
    type: vless
    server: <服务器公网IP或域名>
    port: 443
    uuid: <服务端UUID>
    network: tcp
    tls: true
    udp: true
    servername: www.microsoft.com
    client-fingerprint: chrome
    reality-opts:
      public-key: <REALITY公钥>
      short-id: "<服务端short ID>"
proxy-groups:
  - name: 代理选择
    type: select
    proxies:
      - 我的服务器
      - DIRECT
rules:
  - MATCH,代理选择
```

`server` 是你自己的服务器，`servername` 必须与服务端 `serverNames` 匹配；UUID、short ID 必须与服务端一致，公钥必须与服务端私钥属于同一对。上面规则默认将流量交给“代理选择”，可在客户端切换为 DIRECT。

打开 Clash Verge Rev，在「订阅」或「配置」页面导入本地 YAML 并启用，选择「我的服务器」，按需开启系统代理。使用客户端的延迟测试或访问网站验证连接。不同版本界面名称可能略有差异。

## 排查与维护

- 容器启动失败：查看 `docker compose logs --tail=100 xray-proxy`，检查 JSON、密钥、端口占用及镜像拉取情况。
- 无法连接：检查安全组、防火墙的 TCP 443、服务器公网地址、UUID、密钥对、short ID 和 servername；还要确认服务器可以访问 REALITY 目标站点。
- 更新：在项目目录执行 `git pull`、`docker compose build --pull`、`docker compose up -d`，并检查日志。镜像使用 `latest`，更新前建议备份配置。
- 停止服务：`docker compose down`；查看日志：`docker compose logs -f xray-proxy`。

运行配置和密钥泄露后应重新生成并同步更新客户端。旧版本遗留的证书脚本与 REALITY 部署无关，不需要运行。

## 许可

[MIT License](LICENSE)
