# xray-counting

Xray 客户端统计工具，包含命令行脚本和轻量网页面板。

## 功能

- 从 Xray `access.log` 按来源 IP 去重统计客户端数
- 展示活跃来源 IP TOP N
- 网页面板实时展示（自动刷新）
- 支持 HTTPS（443）
- 支持 ACME 申请 Let's Encrypt 证书：
  - `acme`（standalone，走 80 端口）
  - `acme-dns`（DNS 验证，备用方案）

## 文件说明

- `cxc.sh`：中文命令行统计脚本
- `count_xray_clients.sh`：通用统计脚本
- `xray_dashboard.py`：网页面板服务
- `cxc-web.sh`：面板管理 + ACME 证书申请

## 安装依赖（先执行）

如果你是 `root`，把 `sudo` 去掉即可。

### Debian / Ubuntu（apt）

```bash
sudo apt update
sudo apt install -y bash curl wget python3 openssl gawk coreutils procps iproute2
```

### CentOS / Rocky / AlmaLinux（yum）

```bash
sudo yum install -y bash curl wget python3 openssl gawk coreutils procps-ng iproute
```

可选依赖（仅 certbot 模式需要）：

```bash
# Debian / Ubuntu
sudo apt install -y certbot

# CentOS / Rocky / AlmaLinux
sudo yum install -y certbot
```

如果没有 `wget`，可改用 `curl` 下载：

```bash
curl -fsSL -o cxc.sh https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/cxc.sh
curl -fsSL -o cxc-web.sh https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/cxc-web.sh
```

## 快速开始

### 1) 下载脚本

```bash
wget -O cxc.sh https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/cxc.sh
wget -O count_xray_clients.sh https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/count_xray_clients.sh
wget -O xray_dashboard.py https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/xray_dashboard.py
wget -O cxc-web.sh https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/cxc-web.sh
chmod +x cxc.sh count_xray_clients.sh cxc-web.sh
```

### 2) 命令行统计

```bash
bash cxc.sh
bash cxc.sh /var/log/xray/access.log 10
```

### 3) 启动网页面板（HTTP）

```bash
bash cxc-web.sh start
```

默认访问：`http://服务器IP:8080`

### 4) 启用 HTTPS（443）

```bash
HTTPS_ENABLE=1 PORT=443 SSL_CERT=/root/fullchain.pem SSL_KEY=/root/privkey.pem bash cxc-web.sh restart
```

默认访问：`https://服务器IP:443`

## ACME 证书申请

### 方案 A：standalone（需要公网 80 端口）

```bash
ACME_DOMAIN=example.com ACME_EMAIL=you@example.com bash cxc-web.sh acme
```

### 方案 B：DNS 验证备用（不依赖 80 端口）

Cloudflare 示例：

```bash
export CF_Token="your_cf_api_token"
export CF_Account_ID="your_cf_account_id"
ACME_DOMAIN=example.com ACME_EMAIL=you@example.com ACME_DNS_PROVIDER=dns_cf bash cxc-web.sh acme-dns
```

阿里云 DNS 示例：

```bash
export Ali_Key="your_aliyun_key"
export Ali_Secret="your_aliyun_secret"
ACME_DOMAIN=example.com ACME_EMAIL=you@example.com ACME_DNS_PROVIDER=dns_ali bash cxc-web.sh acme-dns
```

手动 DNS 模式：

```bash
ACME_DOMAIN=example.com ACME_EMAIL=you@example.com bash cxc-web.sh acme-dns
```

泛域名证书：

```bash
ACME_WILDCARD=1 ACME_DOMAIN=example.com ACME_EMAIL=you@example.com ACME_DNS_PROVIDER=dns_cf bash cxc-web.sh acme-dns
```

申请完成后重启 HTTPS：

```bash
HTTPS_ENABLE=1 PORT=443 bash cxc-web.sh restart
```

## 常用命令

```bash
bash cxc-web.sh status
bash cxc-web.sh restart
bash cxc-web.sh stop
```

## 安全建议

- 不要把密码、私钥、API Token 提交到 GitHub
- 建议使用 SSH 密钥登录并限制 root 远程登录
- 对公网开放时建议配合防火墙和访问控制

## License

MIT
