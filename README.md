# 🌐 dnstm-setup

> **Interactive DNS Tunnel Setup Wizard** — automated server deployment for unrestricted internet access.

Deploys [dnstm](https://github.com/net2share/dnstm) DNS tunnel servers with **Slipstream**, **DNSTT**, **NoizDNS**, and **VayDNS** protocols. Designed to help people in restricted regions stay connected to the free internet.

---

## 📑 Table of Contents

- [🆕 What's New in v1.4](#-whats-new-in-v14)
- [🔍 How DNS Tunneling Works](#-how-dns-tunneling-works)
- [🏗️ Architecture](#️-architecture)
- [📦 What Gets Installed](#-what-gets-installed)
- [✅ Prerequisites](#-prerequisites)
- [🚀 Quick Start](#-quick-start)
- [📋 Setup Steps Explained](#-setup-steps-explained)
- [🌍 DNS Records Guide](#-dns-records-guide)
- [⌨️ Usage](#️-usage)
- [❓ In-TUI Help System](#-in-tui-help-system)
- [📱 Client Apps](#-client-apps)
- [🛠️ Management Commands](#️-management-commands)
- [👤 SSH Tunnel User Management](#-ssh-tunnel-user-management)
- [🔐 SOCKS Proxy Authentication](#-socks-proxy-authentication)
- [🔌 Xray Backend Integration](#-xray-backend-integration)
- [🗑️ Uninstall](#️-uninstall)
- [📖 Manual Setup Guide](#-manual-setup-guide)
- [🔧 Troubleshooting](#-troubleshooting)
- [🙏 Acknowledgments](#-acknowledgments)
- [🔗 Related Projects](#-related-projects)
- [💖 Donate](#-donate)
- [📄 License](#-license)
- [👤 Author](#-author)
- [📖 راهنمای فارسی](#-راهنمای-فارسی)

---

## 🆕 What's New in v1.4

### ⚡ VayDNS Tunnels (Optimized)

Two new tunnel types — **VayDNS + SOCKS** (`v` subdomain) and **VayDNS + SSH** (`vz` subdomain). [VayDNS](https://github.com/net2share/vaydns) is an optimized fork of DNSTT by net2share with KCP/smux sessions, auto-recovery, and a leaner wire protocol. Runs in `-dnstt-compat` mode for backwards compatibility with existing SlipNet clients.

- **Up to 8 tunnels** (Slipstream + DNSTT + NoizDNS + VayDNS, each with SOCKS and SSH)
- **Zero extra configuration** — VayDNS binary is downloaded automatically during setup
- **Graceful degradation** — if the download fails, the script continues with other tunnel types
- **Transport option 4** in `--add-tunnel` TUI
- **`--monitor`** — new command for live tunnel stats (CPU, memory, uptime, connections)
- **`--diag`** — new command for comprehensive tunnel diagnostics

### 🔌 Xray Backend Integration (Optional)

New optional feature to connect an existing **3x-ui panel** (or raw Xray) to a DNS tunnel. Accessible via `--add-xray` or management menu option 8. This gives users modern proxy protocols tunneled through DNS:

- **Auto-detects** 3x-ui (native or Docker) — or **installs it for you** (full panel or headless mode)
- **4 protocols**: VLESS, Shadowsocks (chacha20-ietf-poly1305), VMess, Trojan
- **Internal-only inbound** on `127.0.0.1` — not exposed to the internet, only reachable through the DNSTT tunnel
- **Generates client configs** — SlipNet URL for the tunnel + client URI for Nekobox/v2rayNG
- **Compatible with any V2Ray client** that supports proxy chaining (Nekobox, v2rayNG, Shadowrocket, Clash, etc.)

### Other Improvements

- **9 DNS records** (was 5) — NS records for NoizDNS (`n`, `z`) and VayDNS (`v`, `vz`) subdomains
- **`--add-domain`** now creates NoizDNS and VayDNS tunnels for backup domains too
- **`--add-tunnel`** now offers 4 transport choices: Slipstream, DNSTT, NoizDNS, VayDNS
- **`--manage`** (TUI option 9) adds Change DNSTT MTU — update MTU on existing DNSTT tunnels without recreating them
- **`--status`** displays all tunnel info and SlipNet URLs including VayDNS
- **`--remove-tunnel`** properly cleans up Xray, NoizDNS, and VayDNS service overrides
- **Security hardening** — SQL injection prevention, cookie jar cleanup, restrictive file permissions, URL-safe base64 encoding
- **Portable code** — no `grep -P` (Perl regex), no `python3` dependency, pure bash URL encoding

---

## 🔍 How DNS Tunneling Works

DNS (Domain Name System) is the internet's phone book — every device on the planet needs it to work. DNS tunneling encodes your internet traffic inside DNS queries and responses.

> 💡 **Why DNS?** Censors can block VPNs, Tor, and direct connections, but they almost never block DNS because doing so would break the internet for everyone. Even during total internet shutdowns, DNS queries often still work through ISP resolvers.

**How it works:**

1. 📱 Your phone (running SlipNet) encodes internet traffic as DNS queries
2. 🔒 These queries look like normal DNS lookups (e.g., `abc123.t.yourdomain.com`)
3. 🌍 The queries travel through public DNS resolvers (Google `8.8.8.8`, Cloudflare `1.1.1.1`, etc.)
4. 🖥️ Your server receives the queries, decodes the hidden data, and forwards it to the real internet
5. ↩️ Responses travel back the same way, encoded inside DNS responses

Because the traffic looks like ordinary DNS resolution, it passes through filters undetected.

---

## 🏗️ Architecture

```
  📱 Phone (SlipNet App)
     |
     | DNS queries (encoded traffic)
     v
  🌍 Public DNS Resolver (8.8.8.8 / 1.1.1.1 / 9.9.9.9)
     |
     | DNS delegation (NS records point to your server)
     v
  🖥️ Your Server — Port 53
     |
     v
  🔀 DNS Router (multiplexes port 53)
     |
     +---> t.domain ---> Slipstream ---> microsocks (SOCKS5) ---> 🌐 Internet
     |                    (QUIC + TLS)
     |
     +---> d.domain ---> DNSTT --------> microsocks (SOCKS5) ---> 🌐 Internet
     |                    (Noise + Curve25519)
     |
     +---> s.domain ---> Slipstream ---> SSH Tunnel ------------> 🌐 Internet
     |                    (QUIC + TLS)   (port forwarding)
     |
     +---> ds.domain --> DNSTT --------> SSH Tunnel ------------> 🌐 Internet
     |                    (Noise + Curve25519) (port forwarding)
     |
     +---> n.domain ---> NoizDNS ------> microsocks (SOCKS5) ---> 🌐 Internet
     |                    (DPI-resistant DNSTT fork)
     |
     +---> z.domain ---> NoizDNS ------> SSH Tunnel ------------> 🌐 Internet
     |                    (DPI-resistant)   (port forwarding)
     |
     +---> v.domain ---> VayDNS -------> microsocks (SOCKS5) ---> 🌐 Internet
     |                    (optimized DNSTT, KCP/smux)
     |
     +---> vz.domain --> VayDNS -------> SSH Tunnel ------------> 🌐 Internet
     |                    (optimized)      (port forwarding)
     |
     +---> x.domain ---> DNSTT --------> Xray (VLESS/SS/VMess/Trojan) -> 🌐 Internet
                          (Noise + Curve25519) (optional, via --add-xray)
```

### 🔗 How DNS Delegation Works

When someone queries `t.yourdomain.com`, the global DNS system follows this chain:

1. Client asks its resolver: *"What is xyz.t.yourdomain.com?"*
2. Resolver asks Cloudflare (your domain's nameserver): *"What is t.yourdomain.com?"*
3. Cloudflare sees the NS record: *"For t.yourdomain.com, ask ns.yourdomain.com"*
4. Cloudflare sees the A record: *"ns.yourdomain.com is at `<your server IP>`"*
5. Resolver sends the query directly to your server on port 53
6. Your server's DNS Router receives it and routes to the correct tunnel

> This is why you need both an **A record** (telling the internet where your server is) and **NS records** (delegating subdomains to your server).

---

## 📦 What Gets Installed

| Component | Description | Details |
|---|---|---|
| 🎛️ **dnstm** | DNS Tunnel Manager | CLI tool that manages all tunnel binaries, services, and routing |
| 🔀 **DNS Router** | Port 53 multiplexer | Inspects incoming DNS queries and routes them to the correct tunnel by subdomain |
| ⚡ **Slipstream Server** | QUIC-based DNS tunnel | TLS encryption with self-signed certificates — Speed: **~63 KB/s** |
| 🔐 **DNSTT Server** | Classic DNS tunnel | Noise protocol with Curve25519 key pairs — Speed: **~42 KB/s** |
| 🛡️ **NoizDNS Server** | DPI-resistant DNS tunnel | Modified DNSTT fork with enhanced query encoding to evade Deep Packet Inspection — Speed: **~42 KB/s** |
| ⚡ **VayDNS Server** | Optimized DNS tunnel | DNSTT fork with KCP/smux sessions, auto-recovery, and leaner wire protocol — Speed: **~42 KB/s** |
| 🧦 **microsocks** | SOCKS5 proxy | Lightweight proxy shared by all tunnels (port auto-assigned by dnstm) |
| 👤 **sshtun-user** | SSH user manager | *(Optional)* Creates restricted users that can only do port forwarding |

### 🚇 Eight Tunnel Types

| Tunnel | Subdomain | Transport | Backend | Use Case |
|---|---|---|---|---|
| ⚡ **slip1** | `t.domain` | Slipstream (QUIC) | SOCKS | Fastest — recommended for most users |
| 🔐 **dnstt1** | `d.domain` | DNSTT (Noise) | SOCKS | Fallback if Slipstream is blocked |
| 🛡️ **noiz1** | `n.domain` | NoizDNS (DPI-resistant) | SOCKS | Best for heavy censorship / DPI environments |
| ⚡ **vay1** | `v.domain` | VayDNS (optimized) | SOCKS | Optimized DNSTT with auto-recovery |
| 🔑 **slip-ssh** | `s.domain` | Slipstream (QUIC) | SSH | When you need per-user authentication |
| 🔑 **dnstt-ssh** | `ds.domain` | DNSTT (Noise) | SSH | SSH fallback if Slipstream is blocked |
| 🛡️ **noiz-ssh** | `z.domain` | NoizDNS (DPI-resistant) | SSH | DPI-resistant SSH tunnel |
| ⚡ **vay-ssh** | `vz.domain` | VayDNS (optimized) | SSH | Optimized SSH tunnel with auto-recovery |

> 🧦 **SOCKS backend:** Optionally secured with SOCKS5 username/password authentication. Without auth, anyone who knows the domain can connect.
>
> 🔑 **SSH backend:** Requires username + password. Provides per-user access control. The SSH user is restricted — even if credentials leak, no one can access your server.
>
> 🛡️ **NoizDNS:** A DPI-resistant fork of DNSTT by [anonvector](https://github.com/anonvector) (same author as SlipNet). Uses alternative DNS query encoding designed to evade Deep Packet Inspection systems in heavily censored networks. In SlipNet, select **NoizDNS** as the tunnel type for `n` and `z` subdomains.
>
> ⚡ **VayDNS:** An optimized fork of DNSTT by [net2share](https://github.com/net2share/vaydns) with KCP/smux reliable sessions, auto-recovery on connection failure, and a leaner wire protocol. Runs in `-dnstt-compat` mode so existing SlipNet/DNSTT clients work. In SlipNet, select **DNSTT** as the tunnel type for `v` and `vz` subdomains.

---

## ✅ Prerequisites

Before running the script, you need:

### 1. 🖥️ A VPS (Virtual Private Server)
- Running **Ubuntu** or **Debian** (tested on Ubuntu 20.04 / 22.04 / 24.04)
- Root access (SSH as root or sudo)
- Public IPv4 address
- Port 53 (UDP + TCP) open in any external firewall / hosting provider panel

### 2. 🌐 A Domain
- Any domain works (cheap TLDs like `.live`, `.xyz` are fine)
- The domain **must** use [Cloudflare DNS](https://cloudflare.com) (free plan) to manage records
- You can buy domains from Namecheap, Cloudflare Registrar, or any registrar

### 3. 📥 curl
- Usually pre-installed on Ubuntu/Debian
- If missing, the script will offer to install it for you

---

## 🚀 Quick Start

SSH into your server as root, then:

```bash
curl -fsSL -o dnstm-setup.sh https://raw.githubusercontent.com/SamNet-dev/dnstm-setup/master/dnstm-setup.sh
sudo bash dnstm-setup.sh
```

> 💡 **Tip:** Press **h** at any prompt for detailed help on that step.

### Add a Backup Domain

Already set up? Add another domain to the same server as a fallback:

```bash
sudo bash dnstm-setup.sh --add-domain
```

This creates a new set of tunnels on the same server with a different domain. If one domain gets blocked, the other still works.

---

## 📋 Setup Steps Explained

The wizard has **12 steps**. Here's what each one does:

<details>
<summary><b>Step 1 — ✅ Pre-flight Checks</b></summary>

- Verifies you're running as root
- Checks the OS is Ubuntu/Debian
- Ensures `curl` is installed (offers to install if missing)
- Auto-detects your server's public IP via `api.ipify.org`
</details>

<details>
<summary><b>Step 2 — 🌐 Domain Configuration</b></summary>

- Asks for your domain name (e.g. `example.com`)
- Strips whitespace, `http://`, and trailing slashes automatically
- Validates the domain contains at least one dot
</details>

<details>
<summary><b>Step 3 — 📝 DNS Records (Cloudflare)</b></summary>

- Shows you exactly which DNS records to create in Cloudflare
- Displays a formatted box with all 9 records (1 A + 8 NS)
- Explains why "DNS Only" (grey cloud) is required
- Waits for your confirmation before proceeding
</details>

<details>
<summary><b>Step 4 — 🔓 Free Port 53</b></summary>

- Checks if anything is already using port 53
- Detects `systemd-resolved` by both process name and `127.0.0.53` address
- Offers to disable it and set DNS to `8.8.8.8` (Google DNS)
- If dnstm is already on port 53 (re-run), skips this step
- Verifies port 53 is actually free after changes
</details>

<details>
<summary><b>Step 5 — 📥 Install dnstm</b></summary>

- Downloads the dnstm binary from GitHub releases
- Runs `dnstm install --mode multi` to set up multi-tunnel mode
- If dnstm is already installed, asks if you want to re-install/update
- Installs: tunnel binaries, system user, firewall rules, DNS Router, microsocks
</details>

<details>
<summary><b>Step 6 — 🔍 Verify Port 53</b></summary>

- Confirms the DNS Router is listening on port 53
- If not, attempts to start it
- Opens port 53 TCP/UDP in ufw and iptables (if present)
- Reminds you to check external firewalls (hosting provider panel)
</details>

<details>
<summary><b>Step 7 — 🚇 Create Tunnels</b></summary>

- Asks for DNSTT MTU size (default 1232, range 512–1400) — useful for networks with packet size restrictions
- Creates up to 8 tunnels using `dnstm tunnel add`:
  - `slip1` — Slipstream + SOCKS on `t.yourdomain.com`
  - `dnstt1` — DNSTT + SOCKS on `d.yourdomain.com`
  - `slip-ssh` — Slipstream + SSH on `s.yourdomain.com`
  - `dnstt-ssh` — DNSTT + SSH on `ds.yourdomain.com`
  - `noiz1` — NoizDNS + SOCKS on `n.yourdomain.com` (if binary available)
  - `noiz-ssh` — NoizDNS + SSH on `z.yourdomain.com` (if binary available)
  - `vay1` — VayDNS + SOCKS on `v.yourdomain.com` (if binary available)
  - `vay-ssh` — VayDNS + SSH on `vz.yourdomain.com` (if binary available)
- Extracts and displays public keys for DNSTT, NoizDNS, and VayDNS
- Handles "already exists" gracefully on re-runs
</details>

<details>
<summary><b>Step 8 — ▶️ Start Services</b></summary>

- Starts the DNS Router
- Starts all tunnels (up to 8)
- Verifies NoizDNS and VayDNS tunnels started correctly (removes dead ones to protect the router)
- Shows current tunnel status via `dnstm tunnel list`
- Handles "already running" gracefully
</details>

<details>
<summary><b>Step 9 — 🧦 Verify SOCKS Proxy</b></summary>

- **Asks if you want SOCKS5 authentication** — recommended for security
  - If yes: prompts for username (default: `proxy`) and password
  - Configures auth via `dnstm backend auth` (dnstm v0.6.8+)
  - If no: proxy runs open (anyone who knows the domain can connect)
- Checks if microsocks is running (process or systemd service)
- Starts it if not running
- Tests the SOCKS proxy by detecting the microsocks port and making a request through it
</details>

<details>
<summary><b>Step 10 — 👤 SSH Tunnel User</b></summary>

- **Required for SSH tunnels (s/ds) to work** — skipping means SSH tunnels won't function
- Downloads `sshtun-user` tool if not installed
- Configures SSH with security restrictions
- Creates a restricted user that can only do SSH port forwarding
- Asks for username (default: "tunnel") and password
- Shows how to create one later if skipped
</details>

<details>
<summary><b>Step 11 — 🧪 Verification Tests</b></summary>

Runs 6 automated tests:
1. **SOCKS proxy** — HTTP request through microsocks
2. **Tunnel status** — Checks all tunnels are running
3. **DNS Router** — Verifies router is active
4. **Port 53** — Confirms dnstm is on port 53
5. **DNS delegation** — End-to-end reachability via public resolvers
6. **SSH readiness** — Verifies sshd is running and tunnel user was created
</details>

<details>
<summary><b>Step 12 — 📊 Summary</b></summary>

Displays everything you need:
- Server IP and domain
- All tunnel endpoints (up to 8)
- DNSTT, NoizDNS, and VayDNS public keys
- `dnst://` share URLs for dnstc CLI client
- `slipnet://` deep-link URLs for SlipNet Android app (tap to import) — includes SOCKS credentials when auth is enabled
- SOCKS proxy credentials (if authentication was enabled) or warning if open
- SSH tunnel credentials (if configured) or warning if not set up
- List of DNS resolvers for SlipNet
- Client app download link
- Useful management commands
</details>

---

## 🌍 DNS Records Guide

Create these records in your **Cloudflare** dashboard:

### Record 1 — A Record (Address)

| Field | Value |
|---|---|
| Type | `A` |
| Name | `ns` |
| IPv4 address | Your server's IP (e.g. `198.23.249.154`) |
| Proxy status | **DNS Only** (grey cloud — click to toggle OFF) |

> ☝️ This tells the internet: *"ns.yourdomain.com is at this IP address."*

### Records 2-9 — NS Records (Delegation)

| Type | Name | Target | Tunnel |
|---|---|---|---|
| `NS` | `t` | `ns.yourdomain.com` | Slipstream + SOCKS |
| `NS` | `d` | `ns.yourdomain.com` | DNSTT + SOCKS |
| `NS` | `n` | `ns.yourdomain.com` | NoizDNS + SOCKS (DPI-resistant) |
| `NS` | `v` | `ns.yourdomain.com` | VayDNS + SOCKS (optimized) |
| `NS` | `s` | `ns.yourdomain.com` | Slipstream + SSH |
| `NS` | `ds` | `ns.yourdomain.com` | DNSTT + SSH |
| `NS` | `z` | `ns.yourdomain.com` | NoizDNS + SSH (DPI-resistant) |
| `NS` | `vz` | `ns.yourdomain.com` | VayDNS + SSH (optimized) |

> ☝️ These tell the internet: *"For queries about t/d/n/v/s/ds/z/vz.yourdomain.com, ask ns.yourdomain.com (your server)."*

### ⚠️ Common Mistakes

| Mistake | Why it breaks |
|---|---|
| Using `tns` instead of `ns` | The A record name must be exactly `ns` |
| Leaving Cloudflare proxy ON 🟠 | Must be DNS Only (grey cloud ⚪) — orange cloud intercepts queries |
| Setting NS value to an IP | NS records must point to a hostname (`ns.yourdomain.com`), not an IP |
| Forgetting to save | Click Save after adding each record! |

---

## ⌨️ Usage

```bash
# 🚀 Run the interactive setup wizard (first time)
sudo bash dnstm-setup.sh

# 🎛️ Post-setup management menu (all actions in one place)
sudo bash dnstm-setup.sh --manage

# 🔧 Set custom DNSTT MTU (default: 1232, range: 512-1400)
sudo bash dnstm-setup.sh --mtu 1200

# 🌐 Add a backup domain with custom MTU
sudo bash dnstm-setup.sh --add-domain --mtu 1200

# 🚇 Add a single tunnel (interactive — Slipstream, DNSTT, NoizDNS, or VayDNS)
sudo bash dnstm-setup.sh --add-tunnel

# 🔌 Connect existing Xray panel (3x-ui) via DNS tunnel
sudo bash dnstm-setup.sh --add-xray

# 🔒 Apply security hardening to all services
sudo bash dnstm-setup.sh --harden

# ❌ Remove a specific tunnel (interactive picker)
sudo bash dnstm-setup.sh --remove-tunnel
# Or specify the tag directly
sudo bash dnstm-setup.sh --remove-tunnel slip1

# 👤 Manage SSH tunnel users (add, list, update, delete)
sudo bash dnstm-setup.sh --users

# 📊 Show all tunnels, credentials, and share URLs
sudo bash dnstm-setup.sh --status

# 📈 Monitor tunnel usage (CPU, memory, connections, logs)
sudo bash dnstm-setup.sh --monitor

# 🔍 Run tunnel diagnostics (binaries, services, ports, config)
sudo bash dnstm-setup.sh --diag

# 🗑️ Remove ALL installed components (nuclear option)
sudo bash dnstm-setup.sh --uninstall

# ❓ Show help (no root needed)
bash dnstm-setup.sh --help

# ℹ️ Show project information (no root needed)
bash dnstm-setup.sh --about
```

---

## ❓ In-TUI Help System

Press **`h`** at any prompt during the interactive setup to open the help menu:

```
  ┌──────────────────────────────────────────────────────────┐
  │ Help — Pick a Topic                                      │
  └──────────────────────────────────────────────────────────┘

  1  Domains & DNS Basics
  2  DNS Records (Cloudflare Setup)
  3  Port 53 & systemd-resolved
  4  dnstm — DNS Tunnel Manager
  5  SSH Tunnel Users
  6  Architecture & How It Works

  ────────────────────────────────────────
  7  About

  Pick a topic (1-7) or Enter to go back:
```

Each topic gives deep explanations of how things work, why each step is needed, and what the terminology means. Browse multiple topics and return to the setup prompt when ready.

---

## 📱 Client Apps

### 🤖 Android — SlipNet

**SlipNet** supports both Slipstream and DNSTT tunnels.

📥 **Download:** https://github.com/anonvector/SlipNet/releases

| Setting | Value |
|---|---|
| 🌐 **Domain** | Your tunnel subdomain (e.g. `t.yourdomain.com`) |
| 🔍 **DNS Resolver** | Any public resolver (see below) |
| 🔄 **Transport** | Slipstream (for t/s), DNSTT (for d/v/vz), or NoizDNS (for n/z) |
| 🔑 **DNSTT Public Key** | The key shown in Step 7 (only for d tunnel) |

### 🍎 iOS — HTTP Injector

**HTTP Injector** supports DNSTT tunnels (the `d` subdomain). Slipstream is not supported on iOS.

📥 **Download:** [App Store](https://apps.apple.com/us/app/http-injector/id1659992827)

| Setting | Value |
|---|---|
| 🔄 **Protocol** | DNS Tunnel (DNSTT) |
| 🌐 **Domain** | `d.yourdomain.com` |
| 🔍 **DNS Resolver** | Any public resolver (see below) |
| 🔑 **DNSTT Public Key** | The key shown in Step 7 |

> ⚠️ iOS users can only use the **DNSTT tunnel** (`d` subdomain). Slipstream tunnels (`t`/`s`) are Android-only via SlipNet.

### 📊 Platform Support

| Platform | App | Slipstream (t/s) | DNSTT (d) |
|---|---|---|---|
| 🤖 Android | SlipNet | ✅ | ✅ |
| 🍎 iOS | HTTP Injector | ❌ | ✅ |

### 🔗 Share URLs

The setup generates two types of share URLs for easy client configuration:

| URL Scheme | App | How to Use |
|---|---|---|
| `dnst://` | **dnstc** (CLI client) | Import with `dnstc tunnel import dnst://...` |
| `slipnet://` | **SlipNet** (Android) | Tap the link on your phone — opens SlipNet and imports the profile automatically |

- **`dnst://`** URLs are generated by `dnstm tunnel share` and contain JSON-encoded tunnel config
- **`slipnet://`** URLs are generated by the setup script and contain all fields SlipNet needs (domain, resolver, public key, SSH credentials)
- HTTP Injector (iOS) does not support URL import — configure manually using the settings above

> 💡 The easiest way to set up a client is to copy a `slipnet://` link from the server summary and open it on your Android phone — SlipNet will import everything automatically.

### 🌍 Recommended DNS Resolvers

| Provider | IP | Note |
|---|---|---|
| 🔵 Google | `8.8.8.8:53` | Most widely available |
| 🟠 Cloudflare | `1.1.1.1:53` | Fast, privacy-focused |
| 🟣 Quad9 | `9.9.9.9:53` | Security-focused |
| 🔴 OpenDNS | `208.67.222.222:53` | Cisco-backed |
| 🟢 AdGuard | `94.140.14.14:53` | Ad-blocking DNS |
| 🔵 CleanBrowsing | `185.228.168.9:53` | Family-safe DNS |

> 💡 Try different resolvers if one doesn't work in your region. Some ISPs may block specific resolvers.

---

## 🛠️ Management Commands

After setup, manage your tunnels with these commands:

```bash
# 🎛️ Interactive management menu (all actions below in one menu)
sudo bash dnstm-setup.sh --manage

# 📊 Show everything: tunnels, credentials, share URLs (all in one)
sudo bash dnstm-setup.sh --status

# 🚇 Add a single tunnel (interactive — pick Slipstream/DNSTT/NoizDNS/VayDNS, backend, domain, tag)
sudo bash dnstm-setup.sh --add-tunnel

# 🔌 Add Xray backend (connect existing 3x-ui panel via DNS tunnel)
sudo bash dnstm-setup.sh --add-xray

# ❌ Remove a specific tunnel (interactive picker or pass tag directly)
sudo bash dnstm-setup.sh --remove-tunnel
sudo bash dnstm-setup.sh --remove-tunnel slip1

# 📋 View all tunnels and their status
dnstm tunnel list

# 🔗 Generate share URLs for a tunnel
# dnst:// URLs (for dnstc CLI client):
dnstm tunnel share -t slip1
dnstm tunnel share -t dnstt-ssh --user tunnel --password secret
# slipnet:// URLs (for SlipNet Android app) are generated automatically
# in the setup summary — tap the link on your phone to import the profile

# 📊 Check DNS Router status
dnstm router status

# 📜 View DNS Router logs
dnstm router logs

# 🔍 View logs for a specific tunnel
dnstm tunnel logs --tag slip1
dnstm tunnel logs --tag dnstt1
dnstm tunnel logs --tag slip-ssh

# ⏹️ Stop / ▶️ Start a specific tunnel
dnstm tunnel stop --tag slip1
dnstm tunnel start --tag slip1

# 🔀 Stop / Start the DNS Router
dnstm router stop
dnstm router start

# 🧪 Test the SOCKS proxy locally (check port with: ss -tlnp | grep microsocks)
# Without authentication:
curl --socks5 127.0.0.1:<MICROSOCKS_PORT> https://api.ipify.org
# With SOCKS5 authentication:
curl --socks5-basic --proxy socks5://127.0.0.1:<MICROSOCKS_PORT> --proxy-user user:pass https://api.ipify.org
```

---

## 👤 SSH Tunnel User Management

Manage SSH tunnel users after setup with the built-in user management TUI:

```bash
sudo bash dnstm-setup.sh --users
```

This opens an interactive menu:

| Option | Action |
|---|---|
| **1** | **List users** — show all SSH tunnel users |
| **2** | **Add user** — create a new tunnel user (with password or auto-generated) |
| **3** | **Change password** — update an existing user's password |
| **4** | **Delete user** — remove a user (with confirmation) |
| **0** | **Exit** |

> **What are SSH tunnel users?** These are restricted system users that can only create SSH tunnels (SOCKS proxy, port forwarding) — they have no shell access and cannot run commands on your server. They're required for the SSH-based tunnels (`s` and `ds` subdomains).

If `sshtun-user` is not installed, the script will automatically download and configure it on first run.

---

## 🔐 SOCKS Proxy Authentication

During setup (Step 9), the wizard asks whether to enable SOCKS5 authentication on the microsocks proxy. This controls access to the **SOCKS tunnels** (`t` and `d` subdomains).

### With Authentication (Recommended)

When enabled, microsocks requires a **username and password** for every SOCKS5 connection. This means:
- Only clients with the correct credentials can use the tunnel
- The `slipnet://` share URLs automatically include the credentials (clients auto-configure)
- The `authMode` field in SlipNet is set to `1` (username/password)

Authentication is configured via `dnstm backend auth` (requires dnstm v0.6.8+).

### Without Authentication

When disabled, the proxy is **open** — anyone who can resolve the DNS tunnel domain can connect. Security relies solely on the domain being secret.

### Changing Auth After Setup

To **add or change** authentication:

```bash
sudo dnstm backend auth -t socks -u youruser -p yourpassword
```

To **remove** authentication:

```bash
sudo dnstm backend auth -t socks --disable
```

> **Note:** When adding a backup domain with `--add-domain`, the script auto-detects existing SOCKS authentication via `dnstm backend status` and includes the credentials in the generated share URLs.

---

## 🔌 Xray Backend Integration

> **Optional feature** — connect an existing Xray panel (3x-ui) to a DNSTT tunnel for modern proxy protocol support.

If you already have a [3x-ui](https://github.com/mhsanaei/3x-ui) panel running on your server, this feature lets you route DNS tunnel traffic through Xray. Instead of the default microsocks (SOCKS5) backend, users get access to **VLESS, Shadowsocks, VMess, or Trojan** protocols — all tunneled through DNS.

### How It Works

```
  📱 Phone
     |
     +-- SlipNet app -------> DNSTT tunnel (DNS queries on port 53)
     |   (transport layer)        |
     |                            v
     +-- Nekobox/v2rayNG --> 🖥️ Server: DNSTT decodes traffic
         (proxy protocol)        |
                                 v
                            Xray inbound (127.0.0.1 only)
                                 |
                                 v
                            🌐 Free Internet
```

**Key points:**
- **SlipNet** handles the DNSTT tunnel (transport — how traffic reaches the server through DNS)
- **Nekobox/v2rayNG** handles the proxy protocol (VLESS/SS/VMess/Trojan — what runs inside the tunnel)
- The Xray inbound listens on `127.0.0.1` only — it is **not exposed** to the internet, only reachable through the DNSTT tunnel
- Your existing 3x-ui panel manages the inbound — you can see it in the dashboard

### Supported Protocols

| Protocol | Description |
|---|---|
| **VLESS** | Lightweight, recommended — minimal overhead |
| **Shadowsocks** | Widely supported, uses chacha20-ietf-poly1305 |
| **VMess** | Original V2Ray protocol |
| **Trojan** | HTTPS-like traffic pattern |

### Usage

**Via CLI:**

```bash
# Add Xray backend (auto-detects 3x-ui, creates inbound + DNSTT tunnel)
sudo bash dnstm-setup.sh --add-xray

# Optionally set DNSTT MTU (works in any order)
sudo bash dnstm-setup.sh --add-xray --mtu 1100
sudo bash dnstm-setup.sh --mtu 1100 --add-xray
```

**Via Management Menu:**

```bash
sudo bash dnstm-setup.sh --manage
# Select option 8 → Xray backend
```

### What the Script Does

1. **Auto-detects** Xray installation (3x-ui panel or raw Xray binary)
2. **If not found, offers to install:**
   - **Full panel (3x-ui)** — web dashboard with user management, traffic stats, custom admin credentials and port
   - **Headless (Xray only)** — lightweight, no web panel, config.json managed directly
3. **Reads/sets credentials** for the panel (or generates them for headless mode)
4. **Creates a new inbound** on 127.0.0.1 (your chosen protocol: VLESS/SS/VMess/Trojan)
5. **Creates a DNSTT tunnel** with subdomain `x.yourdomain.com`
6. **Overrides the tunnel upstream** to point at the Xray inbound (instead of microsocks)
7. **Generates** a SlipNet URL (for the tunnel) and a client URI (for the proxy protocol)

### Installation Modes

| Mode | What you get | Best for |
|---|---|---|
| **Full panel (3x-ui)** | Web dashboard, user management, traffic stats, data limits, expiry dates | Managing multiple users |
| **Headless (Xray only)** | Xray binary + config.json, no web UI, minimal resource usage | Single user, low-resource VPS |

When installing 3x-ui, you choose:
- **Admin username** (default: `admin`)
- **Admin password** (default: `password`)
- **Panel web port** (default: `2053`)

### Required DNS Record

After running `--add-xray`, add this record in Cloudflare:

| Type | Name | Value | Proxy |
|---|---|---|---|
| **NS** | `x` | `ns.yourdomain.com` | OFF (grey cloud) |

> This delegates `x.yourdomain.com` to your server, just like the other tunnel subdomains.

### Removing an Xray Tunnel

```bash
sudo bash dnstm-setup.sh --remove-tunnel xray1
```

This removes the DNSTT tunnel, the systemd service override, and the tunnel config file. The Xray inbound itself is **not** removed automatically:
- **Panel mode (3x-ui):** Delete the inbound from the 3x-ui web dashboard
- **Headless mode:** Edit `/usr/local/etc/xray/config.json` and remove the inbound entry manually

### Prerequisites

- **dnstm-setup** must be already configured (run the full setup first)
- `curl` and `jq` are required (`jq` is auto-installed if missing)
- **3x-ui is optional** — if not installed, the script offers to install it for you (full panel or headless)

<details>
<summary><b>📱 Client Setup Guide (SlipNet + Nekobox)</b></summary>

### Step-by-Step Client Configuration

After running `--add-xray`, the script outputs two URLs:

1. **SlipNet URL** (`slipnet://...`) — configures the DNSTT tunnel
2. **Client URI** (`vless://...` / `ss://...` / etc.) — configures the proxy protocol

#### Step 1: Import the DNSTT tunnel into SlipNet

1. Open **SlipNet** on your Android phone
2. Copy the `slipnet://` URL from the setup output
3. Tap **Import from clipboard** in SlipNet (or open the URL directly — it auto-imports)
4. The tunnel profile is created automatically

#### Step 2: Enable Proxy Only Mode in SlipNet

1. In SlipNet, go to the imported profile's settings
2. Enable **"Proxy Only Mode"**
3. This exposes a local SOCKS proxy on `127.0.0.1:1080`
4. SlipNet now acts as a pure tunnel — it does NOT proxy your traffic directly

#### Step 3: Add the Xray proxy in Nekobox (or v2rayNG)

1. Open **Nekobox** (or any V2Ray-compatible app)
2. Tap **Add proxy** → **Import from clipboard**
3. Paste the client URI (`vless://...`, `ss://...`, `vmess://...`, or `trojan://...`)
4. The proxy config is created with `127.0.0.1` as the address and the Xray inbound port

#### Step 4: Chain Nekobox through SlipNet

1. In Nekobox, go to the proxy settings
2. Set **Outbound proxy** (or "chain") to use `SOCKS5` at `127.0.0.1:1080`
3. This routes all Nekobox traffic through SlipNet's DNSTT tunnel

#### Step 5: Enable UDP over TCP

1. In both SlipNet and Nekobox, find the **UDP over TCP** option
2. Enable it in both apps
3. This wraps UDP traffic (DNS, etc.) into TCP before entering the tunnel, improving stability

#### Step 6: Bypass SlipNet from Nekobox routing

1. In Nekobox, go to **Route settings** → **App routing**
2. Add **SlipNet** to the bypass/direct list
3. This prevents a routing loop (Nekobox trying to send SlipNet's own traffic through SlipNet)

#### Compatible Client Apps

Any V2Ray/Xray-compatible app that supports proxy chaining works:

| Platform | App | Proxy Chain Support |
|---|---|---|
| Android | **Nekobox** | Yes |
| Android | **v2rayNG** | Yes (custom routing) |
| Android | **Hiddify** | Yes |
| Android | **Clash Meta** | Yes |
| iOS | **Shadowrocket** | Yes |
| iOS | **Stash** | Yes |
| iOS | **V2Box** | Yes |
| Desktop | **Nekoray** | Yes |
| Desktop | **v2rayN** | Yes |
| Desktop | **Clash Verge** | Yes |

> **Note:** The generated client URIs (`vless://`, `ss://`, `vmess://`, `trojan://`) use standard formats compatible with all these apps. The address in the URI is `127.0.0.1` because the client connects through the DNSTT tunnel, not directly to the server.

</details>

---

## 🗑️ Uninstall

To remove everything installed by this script:

```bash
sudo bash dnstm-setup.sh --uninstall
```

**Removes:**
- ✅ All dnstm tunnels and the DNS Router
- ✅ dnstm binary and `/etc/dnstm` configuration (including Xray tunnel configs)
- ✅ sshtun-user binary (if installed)
- ✅ microsocks service
- ✅ Xray and NoizDNS systemd service overrides
- ✅ NoizDNS server binary

**Not removed** (must be done manually):
- ⚠️ Xray/3x-ui panel — only DNSTT tunnel configs are cleaned up, the panel is untouched
- ⚠️ Xray inbounds created via `--add-xray` — remove them from the 3x-ui dashboard
- ⚠️ DNS records in Cloudflare — delete them from your dashboard
- ⚠️ systemd-resolved — re-enable with:
  ```bash
  chattr -i /etc/resolv.conf 2>/dev/null
  rm /etc/resolv.conf && ln -s ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  systemctl unmask systemd-resolved.socket systemd-resolved.service
  systemctl enable systemd-resolved && systemctl start systemd-resolved
  ```

---

## 📖 Manual Setup Guide

If you prefer to set things up manually step by step (without this script), follow the complete manual guide:

📝 **[Complete Guide to Setting Up a DNS Tunnel](https://telegra.ph/Complete-Guide-to-Setting-Up-a-DNS-Tunnel-03-04)** *(Farsi)*

---

## 🔧 Troubleshooting

<details>
<summary><b>🔴 Port 53 is still in use after disabling systemd-resolved</b></summary>

```bash
# Check what's using port 53
ss -ulnp | grep -E ':53\b'

# If systemd-resolved is still there, force it (stop socket too!)
systemctl stop systemd-resolved.socket systemd-resolved.service
systemctl disable systemd-resolved.socket systemd-resolved.service
systemctl mask systemd-resolved.socket systemd-resolved.service
pkill -9 systemd-resolve
# Fix resolv.conf (remove symlink, write real file, lock it)
chattr -i /etc/resolv.conf 2>/dev/null; rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
chattr +i /etc/resolv.conf
```
</details>

<details>
<summary><b>🔴 Tunnels not starting</b></summary>

```bash
# Check tunnel status
dnstm tunnel list

# Check logs for errors
dnstm tunnel logs --tag slip1
dnstm router logs

# Try restarting
dnstm router stop
dnstm router start
dnstm tunnel start --tag slip1
```
</details>

<details>
<summary><b>🔴 SOCKS proxy not responding</b></summary>

```bash
# Check if microsocks is running
systemctl status microsocks

# Restart it
systemctl restart microsocks

# Test locally (check port with: ss -tlnp | grep microsocks)
curl --socks5 127.0.0.1:<MICROSOCKS_PORT> https://api.ipify.org
```
</details>

<details>
<summary><b>🔴 DNS records not working</b></summary>

- Make sure the A record name is exactly `ns` (not `tns`, not `ns1`)
- Make sure the A record proxy is **OFF** (grey cloud ⚪, not orange 🟠)
- NS record values must be `ns.yourdomain.com` (not an IP address)
- Wait 5–10 minutes for DNS propagation after creating records
- Test with: `dig NS t.yourdomain.com` — should show `ns.yourdomain.com`
</details>

<details>
<summary><b>🔴 SlipNet can't connect</b></summary>

- Try different DNS resolvers (`8.8.8.8`, `1.1.1.1`, `9.9.9.9`)
- Make sure you selected the correct transport (Slipstream for t/s, DNSTT for d)
- For DNSTT, verify the public key matches the one shown during setup
- Check that port 53 UDP and TCP are open in your hosting provider's firewall panel
</details>

---

## 🙏 Acknowledgments

This project builds on the incredible work of these open-source projects:

| Protocol | Author | Repository | Description |
|---|---|---|---|
| 🔐 **DNSTT** | David Fifield | [bamsoftware.com/software/dnstt](https://www.bamsoftware.com/software/dnstt/) | DNS tunnel using Noise protocol with Curve25519 encryption. Supports UDP DNS, DoH, and DoT. |
| ⚡ **Slipstream** | EndPositive | [EndPositive/slipstream](https://github.com/EndPositive/slipstream) | High-performance covert channel over DNS, powered by QUIC multipath with adaptive congestion control. |

Thank you to **David Fifield** and **EndPositive** for making internet freedom possible through their research and open-source contributions. 🫡

---

## 🔗 Related Projects

| Project | Description |
|---|---|
| 🎛️ [dnstm](https://github.com/net2share/dnstm) | DNS Tunnel Manager CLI |
| ⚡ [VayDNS](https://github.com/net2share/vaydns) | Optimized DNSTT fork with KCP/smux sessions |
| 👤 [sshtun-user](https://github.com/net2share/sshtun-user) | Restricted SSH tunnel user manager |
| 📱 [SlipNet](https://github.com/anonvector/SlipNet) | Android VPN client for DNS tunnels |

---

## 💖 Donate

If this project helps you or someone you know access the free internet, consider supporting continued development:

### 👉 **[samnet.dev/donate](https://www.samnet.dev/donate/)**

---

## 📄 License

MIT

---

## 👤 Author

Made By **SamNet Technologies** — Saman

🔗 https://github.com/SamNet-dev

---

<div dir="rtl">

# 📖 راهنمای فارسی

## dnstm-setup — ابزار نصب خودکار تانل DNS

ابزار نصب تعاملی (Interactive) برای راه‌اندازی سرور تانل DNS جهت دسترسی به اینترنت آزاد. این اسکریپت تمام مراحل نصب و پیکربندی را به صورت خودکار انجام می‌دهد.

---

## 🔍 تانل DNS چیست؟

تانل DNS روشی برای عبور ترافیک اینترنت از طریق درخواست‌های DNS است. از آنجا که DNS تقریباً هرگز مسدود نمی‌شود (حتی در زمان قطعی اینترنت)، این تکنولوژی یک کانال قابل اعتماد برای دسترسی به اینترنت فراهم می‌کند.

> 💡 **چرا DNS؟** سانسورکنندگان می‌توانند VPN، Tor و اتصالات مستقیم را مسدود کنند، اما تقریباً هرگز DNS را مسدود نمی‌کنند زیرا این کار اینترنت را برای همه خراب می‌کند.

**نحوه عملکرد:**

1. 📱 گوشی شما (با اپلیکیشن SlipNet) ترافیک اینترنت را به صورت درخواست‌های DNS رمزگذاری می‌کند
2. 🔒 این درخواست‌ها مانند جستجوی DNS معمولی به نظر می‌رسند
3. 🌍 درخواست‌ها از طریق DNS resolverهای عمومی (مانند 8.8.8.8) عبور می‌کنند
4. 🖥️ سرور شما درخواست‌ها را دریافت، رمزگشایی و به اینترنت واقعی ارسال می‌کند
5. ↩️ پاسخ‌ها به همین روش برمی‌گردند

---

## 🏗️ معماری سیستم

</div>

```
  📱 گوشی (اپلیکیشن SlipNet)
     |
     | درخواست‌های DNS (ترافیک رمزگذاری شده)
     v
  🌍 DNS Resolver عمومی (8.8.8.8 / 1.1.1.1)
     |
     v
  🖥️ سرور شما — پورت 53
     |
     v
  🔀 DNS Router (مالتی‌پلکسر)
     |
     +---> t.domain  ---> Slipstream ---> microsocks (SOCKS5) ---> 🌐 اینترنت
     +---> d.domain  ---> DNSTT --------> microsocks (SOCKS5) ---> 🌐 اینترنت
     +---> n.domain  ---> NoizDNS ------> microsocks (SOCKS5) ---> 🌐 اینترنت (مقاوم DPI)
     +---> s.domain  ---> Slip+SSH -----> تانل SSH --------------> 🌐 اینترنت
     +---> ds.domain --> DNSTT+SSH ----> تانل SSH --------------> 🌐 اینترنت
     +---> z.domain  ---> NoizDNS+SSH --> تانل SSH --------------> 🌐 اینترنت (مقاوم DPI)
     +---> x.domain  ---> DNSTT --------> Xray (VLESS/SS/VMess/Trojan) -> 🌐 اینترنت
                          (اختیاری، با --add-xray)
```

<div dir="rtl">

---

## ✅ پیش‌نیازها

### 1. 🖥️ سرور (VPS)
- سیستم‌عامل **Ubuntu** یا **Debian**
- دسترسی root (SSH به عنوان root)
- آدرس IP عمومی (IPv4)
- پورت 53 (UDP و TCP) در فایروال باز باشد

### 2. 🌐 دامنه
- هر دامنه‌ای قابل استفاده است (دامنه‌های ارزان مثل `.live`، `.xyz` کافی هستند)
- دامنه **باید** از [Cloudflare DNS](https://cloudflare.com) استفاده کند (پلن رایگان)
- می‌توانید دامنه را از Namecheap یا هر ثبت‌کننده‌ای بخرید

### 3. 📥 curl
- معمولاً روی Ubuntu/Debian نصب است
- اگر نصب نباشد، اسکریپت پیشنهاد نصب خودکار می‌دهد

---

## 🚀 نصب سریع

وارد سرور خود شوید (SSH) و دستورات زیر را اجرا کنید:

</div>

```bash
curl -fsSL -o dnstm-setup.sh https://raw.githubusercontent.com/SamNet-dev/dnstm-setup/master/dnstm-setup.sh
sudo bash dnstm-setup.sh
```

<div dir="rtl">

> 💡 در هر مرحله کلید **h** را بزنید تا راهنمای کامل آن بخش نمایش داده شود.

### افزودن دامنه پشتیبان

اگر قبلاً نصب انجام شده، می‌توانید دامنه دیگری به همان سرور اضافه کنید:

</div>

```bash
sudo bash dnstm-setup.sh --add-domain
```

<div dir="rtl">

اگر یک دامنه مسدود شود، دامنه دیگر همچنان کار می‌کند.

### مدیریت کاربران SSH

بعد از نصب، می‌توانید کاربران تانل SSH رو مدیریت کنید:

</div>

```bash
sudo bash dnstm-setup.sh --users
```

<div dir="rtl">

---

## 🌍 تنظیمات DNS در Cloudflare

این رکوردها را در داشبورد Cloudflare ایجاد کنید:

### رکورد 1 — A Record

| فیلد | مقدار |
|---|---|
| Type | `A` |
| Name | `ns` |
| IPv4 | آدرس IP سرور شما |
| Proxy | **DNS Only** (ابر خاکستری ⚪ — نه نارنجی 🟠!) |

### رکوردهای 2 تا 7 — NS Record

| Type | Name | Target | تانل |
|---|---|---|---|
| `NS` | `t` | `ns.yourdomain.com` | Slipstream + SOCKS |
| `NS` | `d` | `ns.yourdomain.com` | DNSTT + SOCKS |
| `NS` | `n` | `ns.yourdomain.com` | NoizDNS + SOCKS (مقاوم DPI) |
| `NS` | `s` | `ns.yourdomain.com` | Slipstream + SSH |
| `NS` | `ds` | `ns.yourdomain.com` | DNSTT + SSH |
| `NS` | `z` | `ns.yourdomain.com` | NoizDNS + SSH (مقاوم DPI) |

### ⚠️ اشتباهات رایج

| اشتباه | چرا خراب می‌کند |
|---|---|
| استفاده از `tns` به جای `ns` | نام رکورد A باید دقیقاً `ns` باشد |
| روشن بودن پروکسی Cloudflare 🟠 | باید خاموش باشد (ابر خاکستری ⚪) |
| قرار دادن IP به جای دامنه | مقدار NS باید `ns.yourdomain.com` باشد نه آدرس IP |
| فراموش کردن ذخیره | بعد از هر رکورد حتماً Save بزنید! |

---

## 📋 مراحل نصب

اسکریپت شامل **۱۲ مرحله** است:

1. ✅ **بررسی‌های اولیه** — root بودن، سیستم‌عامل، curl، شناسایی IP سرور
2. 🌐 **پیکربندی دامنه** — وارد کردن نام دامنه
3. 📝 **رکوردهای DNS** — نمایش رکوردهای مورد نیاز و تأیید ایجاد آنها
4. 🔓 **آزادسازی پورت 53** — غیرفعال کردن systemd-resolved در صورت نیاز
5. 📥 **نصب dnstm** — دانلود و نصب مدیر تانل DNS
6. 🔍 **بررسی پورت 53** — تأیید اینکه DNS Router روی پورت 53 گوش می‌دهد
7. 🚇 **ایجاد تانل‌ها** — تنظیم MTU و ساخت ۴ تانل (Slipstream+SOCKS، DNSTT+SOCKS، Slipstream+SSH، DNSTT+SSH)
8. ▶️ **شروع سرویس‌ها** — راه‌اندازی روتر و تمام تانل‌ها
9. 🧦 **بررسی پروکسی SOCKS** — انتخاب فعال‌سازی احراز هویت SOCKS5 (نام کاربری/رمز عبور)، تست microsocks (تشخیص خودکار پورت)
10. 👤 **کاربر SSH** — ایجاد کاربر محدود برای تانل SSH (بدون آن تانل‌های SSH کار نمی‌کنند)
11. 🧪 **تست‌های نهایی** — ۶ تست خودکار برای تأیید عملکرد
12. 📊 **خلاصه** — نمایش تمام اطلاعات اتصال، اطلاعات احراز هویت SOCKS، لینک‌های dnst:// (برای dnstc) و slipnet:// (برای اپ SlipNet)

---

## 🚇 شش نوع تانل

| تانل | ساب‌دامین | پروتکل | سرعت | توضیح |
|---|---|---|---|---|
| ⚡ **Slipstream + SOCKS** | `t` | QUIC + TLS | ~63 KB/s | سریع‌ترین — پیشنهادی برای اکثر کاربران |
| 🔐 **DNSTT + SOCKS** | `d` | Noise + Curve25519 | ~42 KB/s | جایگزین اگر Slipstream مسدود شود |
| 🛡️ **NoizDNS + SOCKS** | `n` | NoizDNS (مقاوم DPI) | ~42 KB/s | بهترین برای محیط‌های سانسور شدید |
| 🔑 **Slipstream + SSH** | `s` | QUIC + TLS + SSH | ~60 KB/s | نیاز به نام کاربری و رمز عبور |
| 🔑 **DNSTT + SSH** | `ds` | Noise + Curve25519 + SSH | ~40 KB/s | جایگزین SSH اگر Slipstream مسدود شود |
| 🛡️ **NoizDNS + SSH** | `z` | NoizDNS + SSH (مقاوم DPI) | ~40 KB/s | تانل SSH مقاوم در برابر DPI |

> 🧦 **بک‌اند SOCKS:** امکان فعال‌سازی احراز هویت SOCKS5 با نام کاربری و رمز عبور. بدون احراز هویت، هر کسی که دامنه را بداند می‌تواند وصل شود.
>
> 🔑 **بک‌اند SSH:** نیاز به نام کاربری و رمز عبور. حتی اگر رمز لو برود، کاربر فقط می‌تواند تانل بزند و دسترسی shell ندارد.

---

## 📱 اپلیکیشن‌های کلاینت

### 🤖 اندروید — SlipNet

**SlipNet** از هر دو پروتکل Slipstream و DNSTT پشتیبانی می‌کند.

📥 **دانلود:** https://github.com/anonvector/SlipNet/releases

| تنظیم | مقدار |
|---|---|
| 🌐 **Domain** | ساب‌دامین تانل (مثلاً `t.yourdomain.com`) |
| 🔍 **DNS Resolver** | یکی از resolverهای عمومی (جدول زیر) |
| 🔄 **Transport** | Slipstream (برای t/s) یا DNSTT (برای d) |
| 🔑 **DNSTT Public Key** | کلید نمایش داده شده در مرحله ۷ (فقط برای تانل d) |

### 🍎 iOS — HTTP Injector

**HTTP Injector** فقط از تانل DNSTT (ساب‌دامین `d`) پشتیبانی می‌کند. Slipstream روی iOS پشتیبانی نمی‌شود.

📥 **دانلود:** [App Store](https://apps.apple.com/us/app/http-injector/id1659992827)

| تنظیم | مقدار |
|---|---|
| 🔄 **Protocol** | DNS Tunnel (DNSTT) |
| 🌐 **Domain** | `d.yourdomain.com` |
| 🔍 **DNS Resolver** | یکی از resolverهای عمومی (جدول زیر) |
| 🔑 **DNSTT Public Key** | کلید نمایش داده شده در مرحله ۷ |

> ⚠️ کاربران iOS فقط می‌توانند از **تانل DNSTT** (ساب‌دامین `d`) استفاده کنند. تانل‌های Slipstream (`t`/`s`) فقط روی اندروید با SlipNet کار می‌کنند.

### 📊 پشتیبانی پلتفرم‌ها

| پلتفرم | اپلیکیشن | Slipstream (t/s) | DNSTT (d) |
|---|---|---|---|
| 🤖 اندروید | SlipNet | ✅ | ✅ |
| 🍎 iOS | HTTP Injector | ❌ | ✅ |

### 🔗 لینک‌های اشتراک‌گذاری

اسکریپت دو نوع لینک اشتراک‌گذاری تولید می‌کند:

| نوع لینک | اپلیکیشن | نحوه استفاده |
|---|---|---|
| `dnst://` | **dnstc** (کلاینت خط فرمان) | وارد کردن با `dnstc tunnel import dnst://...` |
| `slipnet://` | **SlipNet** (اندروید) | روی لینک بزنید — اپ باز میشه و پروفایل خودکار اضافه میشه |

- لینک‌های `dnst://` توسط دستور `dnstm tunnel share` تولید می‌شوند و شامل اطلاعات JSON تانل هستند
- لینک‌های `slipnet://` توسط اسکریپت تولید می‌شوند و شامل تمام اطلاعات مورد نیاز SlipNet هستند (دامنه، resolver، کلید عمومی، اطلاعات SSH)
- HTTP Injector (iOS) از لینک پشتیبانی نمی‌کند — تنظیمات را دستی وارد کنید

> 💡 ساده‌ترین راه: لینک `slipnet://` را از خلاصه سرور کپی کنید و روی گوشی اندرویدتان باز کنید — SlipNet همه چیز را خودکار وارد می‌کند.

### 🌍 DNS Resolverهای پیشنهادی

| ارائه‌دهنده | آدرس | توضیح |
|---|---|---|
| 🔵 Google | `8.8.8.8:53` | پراستفاده‌ترین |
| 🟠 Cloudflare | `1.1.1.1:53` | سریع و خصوصی |
| 🟣 Quad9 | `9.9.9.9:53` | امنیت‌محور |
| 🔴 OpenDNS | `208.67.222.222:53` | پشتیبانی Cisco |
| 🟢 AdGuard | `94.140.14.14:53` | مسدودکننده تبلیغات |
| 🔵 CleanBrowsing | `185.228.168.9:53` | مناسب خانواده |

> 💡 اگر یک resolver کار نکرد، resolverهای دیگر را امتحان کنید. بعضی ISPها ممکن است برخی resolverها را مسدود کنند.

---

## 🛠️ دستورات مدیریتی

بعد از نصب، از این دستورات برای مدیریت تانل‌ها استفاده کنید:

</div>

```bash
# 🎛️ منوی مدیریت تعاملی (تمام عملیات در یک منو)
sudo bash dnstm-setup.sh --manage

# 📊 نمایش همه چیز: تانل‌ها، اطلاعات احراز هویت، لینک‌های اشتراک‌گذاری
sudo bash dnstm-setup.sh --status

# 🚇 افزودن یک تانل (تعاملی — انتخاب پروتکل، بک‌اند، دامنه)
sudo bash dnstm-setup.sh --add-tunnel

# 🔌 اتصال پنل Xray (3x-ui) به تانل DNS (اختیاری)
sudo bash dnstm-setup.sh --add-xray

# ❌ حذف یک تانل خاص (تعاملی یا مستقیم)
sudo bash dnstm-setup.sh --remove-tunnel
sudo bash dnstm-setup.sh --remove-tunnel slip1

# 📋 نمایش تمام تانل‌ها و وضعیت آنها
dnstm tunnel list

# 🔗 ایجاد لینک اشتراک‌گذاری (dnst:// برای dnstc)
dnstm tunnel share -t slip1
dnstm tunnel share -t dnstt-ssh --user tunnel --password secret
# لینک‌های slipnet:// برای اپ SlipNet خودکار در خلاصه نصب نمایش داده می‌شوند
# — لینک رو تو گوشی اندروید باز کنید تا پروفایل وارد SlipNet بشه

# 📊 بررسی وضعیت روتر
dnstm router status

# 📜 مشاهده لاگ‌های روتر
dnstm router logs

# 🔍 مشاهده لاگ تانل خاص
dnstm tunnel logs --tag slip1
dnstm tunnel logs --tag dnstt1
dnstm tunnel logs --tag slip-ssh

# ⏹️ توقف / ▶️ شروع یک تانل
dnstm tunnel stop --tag slip1
dnstm tunnel start --tag slip1

# 🔀 توقف / شروع روتر DNS
dnstm router stop
dnstm router start

# 🧪 تست پروکسی SOCKS (بررسی پورت: ss -tlnp | grep microsocks)
# بدون احراز هویت:
curl --socks5 127.0.0.1:<MICROSOCKS_PORT> https://api.ipify.org
# با احراز هویت SOCKS5:
curl --socks5-basic --proxy socks5://127.0.0.1:<MICROSOCKS_PORT> --proxy-user user:pass https://api.ipify.org
```

<div dir="rtl">

---

## 👤 مدیریت کاربران SSH

بعد از نصب، کاربران تانل SSH رو با منوی مدیریتی مدیریت کنید:

</div>

```bash
sudo bash dnstm-setup.sh --users
```

<div dir="rtl">

این دستور یک منوی تعاملی باز می‌کند:

| گزینه | عملکرد |
|---|---|
| **1** | **لیست کاربران** — نمایش تمام کاربران تانل SSH |
| **2** | **افزودن کاربر** — ساخت کاربر جدید (با رمز دستی یا خودکار) |
| **3** | **تغییر رمز** — بروزرسانی رمز عبور یک کاربر |
| **4** | **حذف کاربر** — حذف کاربر (با تأیید) |
| **0** | **خروج** |

> **کاربران تانل SSH چی هستن؟** کاربران محدود سیستمی هستن که فقط می‌تونن تانل SSH بزنن (پروکسی SOCKS، فوروارد پورت) — دسترسی shell ندارن و نمی‌تونن روی سرور شما دستوری اجرا کنن. برای تانل‌های SSH (ساب‌دامین‌های `s` و `ds`) لازمن.

اگر `sshtun-user` نصب نباشد، اسکریپت خودکار آن را دانلود و تنظیم می‌کند.

---

## 🔧 عیب‌یابی

### 🔴 پورت 53 همچنان در استفاده است

</div>

```bash
ss -ulnp | grep -E ':53\b'
systemctl stop systemd-resolved.socket systemd-resolved.service
systemctl mask systemd-resolved.socket systemd-resolved.service
pkill -9 systemd-resolve
chattr -i /etc/resolv.conf 2>/dev/null; rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
chattr +i /etc/resolv.conf
```

<div dir="rtl">

### 🔴 تانل‌ها شروع نمی‌شوند

</div>

```bash
dnstm tunnel list
dnstm tunnel logs --tag slip1
dnstm router logs
```

<div dir="rtl">

### 🔴 SlipNet وصل نمی‌شود
- DNS resolverهای مختلف را امتحان کنید
- مطمئن شوید Transport صحیح انتخاب شده (Slipstream برای t/s، DNSTT برای d)
- برای DNSTT، کلید عمومی را بررسی کنید
- پورت 53 (UDP و TCP) باید در فایروال هاستینگ باز باشد

---

## 🗑️ حذف کامل (Uninstall)

</div>

```bash
sudo bash dnstm-setup.sh --uninstall
```

<div dir="rtl">

این دستور تمام اجزا (تانل‌ها، روتر، dnstm، microsocks، sshtun-user، تنظیمات Xray) را حذف می‌کند.

**حذف نمی‌شود (دستی انجام دهید):**
- ⚠️ پنل Xray/3x-ui — فقط تنظیمات تانل DNS حذف می‌شوند، خود پنل باقی می‌ماند
- ⚠️ اینباندهای ساخته شده با `--add-xray` — از داشبورد 3x-ui حذف کنید
- ⚠️ رکوردهای DNS در Cloudflare — از داشبورد حذف کنید
- ⚠️ systemd-resolved — برای فعال‌سازی مجدد:

</div>

```bash
chattr -i /etc/resolv.conf 2>/dev/null
rm /etc/resolv.conf && ln -s ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
systemctl unmask systemd-resolved.socket systemd-resolved.service
systemctl enable systemd-resolved && systemctl start systemd-resolved
```

<div dir="rtl">

---

## 📖 راهنمای نصب دستی

اگر ترجیح می‌دهید مراحل را به صورت دستی (بدون این اسکریپت) انجام دهید:

📝 **[راهنمای کامل راه‌اندازی تانل DNS](https://telegra.ph/Complete-Guide-to-Setting-Up-a-DNS-Tunnel-03-04)**

---

## 💖 حمایت مالی

اگر این پروژه به شما یا کسی که می‌شناسید کمک کرده تا به اینترنت آزاد دسترسی داشته باشد، می‌توانید از ادامه توسعه حمایت کنید:

### 👉 **[samnet.dev/donate](https://www.samnet.dev/donate/)**

---

## 👤 سازنده

ساخته شده توسط **SamNet Technologies** — سامان

🔗 https://github.com/SamNet-dev

</div>
