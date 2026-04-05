# xray-counting

一个用于统计 Xray 客户端连接情况的小工具集合，支持：

- 命令行统计客户端数（按来源 IP 去重）
- 显示活跃来源 IP TOP N
- 提供一个简单网页面板实时查看统计结果

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
  - 面板服务管理脚本：`start|stop|restart|status`

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

### 1) 上传脚本并赋权

```bash
chmod +x cxc.sh
```

### 2) 直接统计

```bash
bash cxc.sh
```

默认读取：

```text
/var/log/xray/access.log
```

### 3) 指定日志路径和 TOP 数量

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

### 1) 启动面板

```bash
chmod +x cxc-web.sh
bash cxc-web.sh start
```

默认监听：

```text
0.0.0.0:8080
```

浏览器访问：

```text
http://你的服务器IP:8080
```

### 1.1) 启用 HTTPS（支持 443）

准备证书后可直接启用 HTTPS。默认环境变量如下：

- `HTTPS_ENABLE=1`
- `PORT=443`
- `SSL_CERT=/root/fullchain.pem`
- `SSL_KEY=/root/privkey.pem`

启动示例：

```bash
HTTPS_ENABLE=1 PORT=443 SSL_CERT=/root/fullchain.pem SSL_KEY=/root/privkey.pem bash cxc-web.sh restart
```

浏览器访问：

```text
https://你的服务器IP:443
```

如果你是自签名证书，浏览器会提示不受信任，这是正常现象。

### 1.2) 没有证书时快速生成自签名证书（测试用）

```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout /root/privkey.pem \
  -out /root/fullchain.pem \
  -subj "/CN=你的服务器IP或域名"
```

然后执行上面的 HTTPS 启动命令即可。

### 2) 常用管理命令

```bash
bash cxc-web.sh status
bash cxc-web.sh restart
bash cxc-web.sh stop
```

## 面板展示内容

- 客户端数（来源 IP 去重）
- 请求命中总次数（日志匹配条数）
- 活跃来源 IP TOP 10（可配置）

## 可配置项

`cxc-web.sh` 支持环境变量：

- `PORT`：监听端口（默认 `8080`）
- `TOP_N`：TOP 显示数量（默认 `10`）
- `HTTPS_ENABLE`：是否启用 HTTPS（`1` 启用，默认 `0`）
- `SSL_CERT`：证书文件路径（默认 `/root/fullchain.pem`）
- `SSL_KEY`：私钥文件路径（默认 `/root/privkey.pem`）

示例：

```bash
PORT=9000 TOP_N=20 bash cxc-web.sh restart
HTTPS_ENABLE=1 PORT=443 SSL_CERT=/root/fullchain.pem SSL_KEY=/root/privkey.pem TOP_N=20 bash cxc-web.sh restart
```

## 常见问题

### 为什么统计结果是 0？

常见原因：

- `access.log` 文件为空
- Xray 未开启 access 日志
- 日志路径与脚本读取路径不一致
- 当前时间段没有客户端请求

### 统计的是“用户数”吗？

不是。当前统计逻辑是按“来源 IP 去重”，如果多个客户端共用同一个 NAT 出口，统计值会小于真实用户数。

## 安全说明

- 不要把服务器密码、SSH 私钥、IP 白名单等敏感信息提交到 GitHub。
- 建议使用 SSH 密钥登录，并限制 root 远程登录权限。
- 如需公网暴露面板，请配合防火墙、反向代理和访问控制。

## License

MIT
