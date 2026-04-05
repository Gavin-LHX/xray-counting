# xray-counting

Xray client counting toolkit with CLI scripts and a lightweight web dashboard.

## Features

- Count unique clients by source IP from Xray `access.log`
- Show Top-N active source IPs
- Web dashboard (auto refresh)
- HTTPS support (443)
- Let's Encrypt via ACME:
  - `acme` (standalone, port 80)
  - `acme-dns` (DNS validation fallback)

## Files

- `cxc.sh` - Chinese CLI output for quick counting
- `count_xray_clients.sh` - Generic CLI counter
- `xray_dashboard.py` - Python web dashboard
- `cxc-web.sh` - Service manager + ACME helper

## Dependencies (install before Quick Start)

If you are root, remove `sudo`.

### Debian / Ubuntu (apt)

```bash
sudo apt update
sudo apt install -y bash curl wget python3 openssl gawk coreutils procps iproute2
```

### CentOS / Rocky / AlmaLinux (yum)

```bash
sudo yum install -y bash curl wget python3 openssl gawk coreutils procps-ng iproute
```

Optional (only if you want certbot mode):

```bash
# Debian / Ubuntu
sudo apt install -y certbot

# CentOS / Rocky / AlmaLinux
sudo yum install -y certbot
```

If `wget` is not available, use `curl`:

```bash
curl -fsSL -o cxc.sh https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/cxc.sh
curl -fsSL -o cxc-web.sh https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/cxc-web.sh
```

## Quick Start

### 1) Download scripts

```bash
wget -O cxc.sh https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/cxc.sh
wget -O count_xray_clients.sh https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/count_xray_clients.sh
wget -O xray_dashboard.py https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/xray_dashboard.py
wget -O cxc-web.sh https://raw.githubusercontent.com/Gavin-LHX/xray-counting/main/cxc-web.sh
chmod +x cxc.sh count_xray_clients.sh cxc-web.sh
```

### 2) CLI counting

```bash
bash cxc.sh
bash cxc.sh /var/log/xray/access.log 10
```

### 3) Start dashboard (HTTP)

```bash
bash cxc-web.sh start
```

Default: `http://SERVER_IP:8080`

### 4) Enable HTTPS (443)

```bash
HTTPS_ENABLE=1 PORT=443 SSL_CERT=/root/fullchain.pem SSL_KEY=/root/privkey.pem bash cxc-web.sh restart
```

Default: `https://SERVER_IP:443`

## ACME Certificate

### Method A: standalone (needs public port 80)

```bash
ACME_DOMAIN=example.com ACME_EMAIL=you@example.com bash cxc-web.sh acme
```

### Method B: DNS fallback (no 80 required)

Cloudflare example:

```bash
export CF_Token="your_cf_api_token"
export CF_Account_ID="your_cf_account_id"
ACME_DOMAIN=example.com ACME_EMAIL=you@example.com ACME_DNS_PROVIDER=dns_cf bash cxc-web.sh acme-dns
```

Aliyun DNS example:

```bash
export Ali_Key="your_aliyun_key"
export Ali_Secret="your_aliyun_secret"
ACME_DOMAIN=example.com ACME_EMAIL=you@example.com ACME_DNS_PROVIDER=dns_ali bash cxc-web.sh acme-dns
```

Manual DNS mode:

```bash
ACME_DOMAIN=example.com ACME_EMAIL=you@example.com bash cxc-web.sh acme-dns
```

Wildcard cert:

```bash
ACME_WILDCARD=1 ACME_DOMAIN=example.com ACME_EMAIL=you@example.com ACME_DNS_PROVIDER=dns_cf bash cxc-web.sh acme-dns
```

Then restart HTTPS:

```bash
HTTPS_ENABLE=1 PORT=443 bash cxc-web.sh restart
```

## Common Commands

```bash
bash cxc-web.sh status
bash cxc-web.sh restart
bash cxc-web.sh stop
```

## Security Notes

- Do not commit passwords, private keys, or API tokens to GitHub.
- Prefer SSH key login and restrict root login.
- If exposed to internet, use firewall / reverse proxy / access control.

## License

MIT
