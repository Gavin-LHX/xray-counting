# xray-counting

一个用于统计 Xray 客户端连接情况的小工具集合，支持：

- 命令行统计客户端数（按来源 IP 去重）
- 显示活跃来源 IP TOP N
- 提供简单网页面板实时查看统计结果
- 一键申请 Let's Encrypt 证书并启用 HTTPS/443

## 功能概览

- `cxc.sh`
  - 中文输出
  - 统计唯一客户端数（来源 IP 去重）
  - 显示活跃来源 IP TOP（默认前 10）
- `count_xray_clients.sh`
  - 通用英文版统计脚本
  - 支持按时间窗口统计（最近 N 分钟）
- `xray_dashboard.py`
  - Python 标准库实现的轻量 Web 面板（无第三方依赖）
  - 页面自动刷新（15 秒）
- `cxc-web.sh`
  - 面板服务管理：`start|stop|restart|status`
  - ACME 证书申请：`acme`

## 目录结构

```text
.
├── cxc.sh
├── cxc-web.sh
├── count_xray_clients.sh
└── xray_dashboard.py
```

## 运行要求

- Linux 服务器
- 已安装并运行 Xray
- 可读取 Xray `access.log`
- Python 3（用于网页面板）

## 快速开始（命令行统计）

### 0) 使用 raw.githubusercontent.com 一键下载

```bash
wget -O cxc.sh https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/cxc.sh
wget -O count_xray_clients.sh https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/count_xray_clients.sh
chmod +x cxc.sh count_xray_clients.sh
```

### 1) 直接统计

```bash
bash cxc.sh
```

默认读取：`/var/log/xray/access.log`

### 2) 指定日志路径和 TOP 数量

```bash
bash cxc.sh /var/log/xray/access.log 10
```

## 快速开始（网页面板）

### 0) 使用 raw.githubusercontent.com 一键下载

```bash
wget -O xray_dashboard.py https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/xray_dashboard.py
wget -O cxc-web.sh https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/cxc-web.sh
chmod +x cxc-web.sh
```

### 1) 启动 HTTP 面板

```bash
bash cxc-web.sh start
```

默认监听：`0.0.0.0:8080`

访问：`http://你的服务器IP:8080`

### 2) 启用 HTTPS（支持 443）

证书就位后：

```bash
HTTPS_ENABLE=1 PORT=443 SSL_CERT=/root/fullchain.pem SSL_KEY=/root/privkey.pem bash cxc-web.sh restart
```

访问：`https://你的服务器IP:443`

### 3) ACME 自动申请 Let's Encrypt 证书

方式一（推荐，环境变量）：

```bash
ACME_DOMAIN=你的域名 ACME_EMAIL=你的邮箱 bash cxc-web.sh acme
```

方式二（命令参数）：

```bash
bash cxc-web.sh acme 你的域名 你的邮箱
```

申请完成后，脚本会把证书安装到：

- `SSL_CERT`（默认 `/root/fullchain.pem`）
- `SSL_KEY`（默认 `/root/privkey.pem`）

然后执行：

```bash
HTTPS_ENABLE=1 PORT=443 bash cxc-web.sh restart
```

说明：

- ACME 申请使用 `standalone` 模式，需要 80 端口可被公网访问。
- `ACME_TOOL=auto` 时优先 `acme.sh`，其次 `certbot`。
- 可手动指定：`ACME_TOOL=acme.sh` 或 `ACME_TOOL=certbot`。

### 4) 常用管理命令

```bash
bash cxc-web.sh status
bash cxc-web.sh restart
bash cxc-web.sh stop
```

## 可配置项

`cxc-web.sh` 支持环境变量：

- `LOG_FILE`：Xray access 日志路径（默认 `/var/log/xray/access.log`）
- `PORT`：监听端口（默认 HTTP 为 `8080`，HTTPS 为 `443`）
- `TOP_N`：TOP 显示数量（默认 `10`）
- `HTTPS_ENABLE`：是否启用 HTTPS（`1` 启用，默认 `0`）
- `SSL_CERT`：证书路径（默认 `/root/fullchain.pem`）
- `SSL_KEY`：私钥路径（默认 `/root/privkey.pem`）
- `ACME_TOOL`：`auto|acme.sh|certbot`（默认 `auto`）
- `ACME_DOMAIN`：申请证书的域名
- `ACME_EMAIL`：申请证书的邮箱（可选）
- `ACME_SERVER`：ACME 服务端（默认 `letsencrypt`）

示例：

```bash
PORT=9000 TOP_N=20 bash cxc-web.sh restart
HTTPS_ENABLE=1 PORT=443 SSL_CERT=/root/fullchain.pem SSL_KEY=/root/privkey.pem TOP_N=20 bash cxc-web.sh restart
ACME_TOOL=acme.sh ACME_DOMAIN=example.com ACME_EMAIL=admin@example.com bash cxc-web.sh acme
```

## 常见问题

### 为什么统计结果是 0？

常见原因：

- `access.log` 文件为空
- Xray 未开启 access 日志
- 日志路径与脚本读取路径不一致
- 当前时间段没有客户端请求

### 统计的是“用户数”吗？

不是。当前统计逻辑是按“来源 IP 去重”。如果多个客户端共用同一个 NAT 出口，统计值会小于真实用户数。

## 安全说明

- 不要把服务器密码、SSH 私钥等敏感信息提交到 GitHub。
- 建议使用 SSH 密钥登录，并限制 root 远程登录权限。
- 面板对公网开放时，建议配合防火墙、反向代理和访问控制。

## License

MIT
