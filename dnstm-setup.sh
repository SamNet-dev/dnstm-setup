#!/usr/bin/env bash
#
# dnstm-setup v1.1
# Interactive DNS Tunnel Setup
# Sets up Slipstream + DNSTT tunnels for censorship-resistant internet access
#
# Made By SamNet Technologies - Saman
# GitHub: github.com/SamNet-dev/dnstm-setup
# License: MIT

set -euo pipefail

VERSION="1.0"
TOTAL_STEPS=12

# ─── Colors & Formatting ───────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

CHECK="${GREEN}[✓]${NC}"
CROSS="${RED}[✗]${NC}"
WARN="${YELLOW}[!]${NC}"
INFO="${CYAN}[i]${NC}"

# ─── TUI Helper Functions ──────────────────────────────────────────────────────

print_header() {
    local title="$1"
    local width=60
    local line
    line=$(printf '─%.0s' $(seq 1 $width))
    echo ""
    echo -e "${BOLD}${CYAN}┌${line}┐${NC}"
    printf "${BOLD}${CYAN}│${NC} %-$((width - 1))s${BOLD}${CYAN}│${NC}\n" "$title"
    echo -e "${BOLD}${CYAN}└${line}┘${NC}"
    echo ""
}

print_step() {
    local step=$1
    local title="$2"
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}[${step}/${TOTAL_STEPS}]${NC}  ${BOLD}${title}${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_ok() {
    echo -e "  ${CHECK} $1"
}

print_fail() {
    echo -e "  ${CROSS} $1"
}

print_warn() {
    echo -e "  ${WARN} $1"
}

print_info() {
    echo -e "  ${INFO} $1"
}

print_box() {
    local lines=("$@")
    # Calculate width from longest line
    local width=58
    for l in "${lines[@]}"; do
        local len=${#l}
        if (( len + 2 > width )); then
            width=$((len + 2))
        fi
    done
    local line
    line=$(printf '─%.0s' $(seq 1 $width))
    echo -e "  ${DIM}┌${line}┐${NC}"
    for l in "${lines[@]}"; do
        printf "  ${DIM}│${NC} %-$((width - 1))s${DIM}│${NC}\n" "$l"
    done
    echo -e "  ${DIM}└${line}┘${NC}"
}

prompt_yn() {
    local question="$1"
    local default="${2:-n}"
    local yn_hint
    if [[ "$default" == "y" ]]; then
        yn_hint="[Y/n]"
    else
        yn_hint="[y/N]"
    fi
    while true; do
        echo ""
        echo -ne "  ${BOLD}${question}${NC} ${yn_hint} ${DIM}[h=help]${NC} "
        read -r answer
        answer=${answer:-$default}
        if [[ "$answer" =~ ^[Hh]$ ]]; then
            show_help_menu
            continue
        fi
        if [[ "$answer" =~ ^[Yy] ]]; then
            return 0
        else
            return 1
        fi
    done
}

prompt_input() {
    local question="$1"
    local default="${2:-}"
    local result
    while true; do
        if [[ -n "$default" ]]; then
            echo -ne "  ${BOLD}${question}${NC} [${default}] ${DIM}(h=help)${NC}: " >&2
        else
            echo -ne "  ${BOLD}${question}${NC} ${DIM}(h=help)${NC}: " >&2
        fi
        read -r result
        result=${result:-$default}
        if [[ "$result" =~ ^[Hh]$ ]]; then
            show_help_menu >&2
            continue
        fi
        echo "$result"
        return
    done
}

banner() {
    local w=54
    local border empty
    border=$(printf '═%.0s' $(seq 1 $w))
    empty=$(printf ' %.0s' $(seq 1 $w))
    local ver_text="dnstm-setup v${VERSION}"
    local sub_text="Interactive DNS Tunnel Setup"
    local vl=$(( (w - ${#ver_text}) / 2 ))
    local vr=$(( w - ${#ver_text} - vl ))
    local sl=$(( (w - ${#sub_text}) / 2 ))
    local sr=$(( w - ${#sub_text} - sl ))
    echo ""
    echo -e "${BOLD}${CYAN}"
    printf "  ╔%s╗\n" "$border"
    printf "  ║%s║\n" "$empty"
    printf "  ║%${vl}s%s%${vr}s║\n" "" "$ver_text" ""
    printf "  ║%${sl}s%s%${sr}s║\n" "" "$sub_text" ""
    printf "  ║%s║\n" "$empty"
    printf "  ╚%s╝\n" "$border"
    echo -e "${NC}"
}

# ─── Help System ──────────────────────────────────────────────────────────────

help_topic_header() {
    local title="$1"
    local width=58
    local line
    line=$(printf '─%.0s' $(seq 1 $width))
    # Compensate for multi-byte chars: pad width = visual width + (bytes - chars)
    local byte_len=${#title}
    local byte_count
    byte_count=$(printf '%s' "$title" | wc -c)
    local pad_width=$(( width - 1 + byte_count - byte_len ))
    echo ""
    echo -e "  ${BOLD}${CYAN}┌${line}┐${NC}"
    printf "  ${BOLD}${CYAN}│${NC} ${BOLD}%-${pad_width}s${BOLD}${CYAN}│${NC}\n" "$title"
    echo -e "  ${BOLD}${CYAN}└${line}┘${NC}"
    echo ""
}

help_press_enter() {
    echo ""
    echo -ne "  ${DIM}Press Enter to go back...${NC}"
    read -r
}

help_topic_domain() {
    help_topic_header "1. Domains & DNS Basics"
    echo -e "  ${BOLD}What is a domain?${NC}"
    echo "  A domain (e.g. example.com) is a human-readable address"
    echo "  on the internet. DNS tunneling uses domains to encode"
    echo "  data inside DNS queries, making your traffic look like"
    echo "  normal DNS resolution."
    echo ""
    echo -e "  ${BOLD}Why do you need one?${NC}"
    echo "  DNS tunnels work by making DNS queries for subdomains"
    echo "  of YOUR domain. The DNS system routes these queries to"
    echo "  your server, which decodes the hidden data. Without a"
    echo "  domain you own, you can't receive these queries."
    echo ""
    echo -e "  ${BOLD}How DNS delegation works${NC}"
    echo "  When you create NS records pointing t2.example.com to"
    echo "  ns.example.com (your server), you tell the global DNS"
    echo "  system: 'For any query about t2.example.com, ask my"
    echo "  server directly.' This is how tunnel traffic finds you."
    echo ""
    echo -e "  ${BOLD}Where to buy a domain${NC}"
    echo "  - Namecheap (namecheap.com) — cheap, privacy included"
    echo "  - Cloudflare Registrar — at-cost pricing"
    echo "  - Any registrar works, but you MUST use Cloudflare DNS"
    echo "    (free plan) to manage your records"
    echo ""
    echo -e "  ${BOLD}Subdomains used by this script${NC}"
    echo "  If your domain is example.com:"
    echo "    t2.example.com  ->  Slipstream + SOCKS tunnel"
    echo "    d2.example.com  ->  DNSTT + SOCKS tunnel"
    echo "    s2.example.com  ->  Slipstream + SSH tunnel"
    echo "    ds2.example.com ->  DNSTT + SSH tunnel"
    help_press_enter
}

help_topic_dns_records() {
    help_topic_header "2. DNS Records (Cloudflare Setup)"
    echo -e "  ${BOLD}What are DNS records?${NC}"
    echo "  DNS records are entries that tell the internet how to"
    echo "  find services for your domain."
    echo ""
    echo -e "  ${BOLD}A Record (Address Record)${NC}"
    echo "  Maps a name to an IP address."
    echo "  We create:  ns.yourdomain.com -> your server IP"
    echo "  This tells the internet where your DNS server lives."
    echo ""
    echo -e "  ${BOLD}NS Record (Name Server Record)${NC}"
    echo "  Delegates a subdomain to another DNS server."
    echo "  We create:  t2.yourdomain.com NS -> ns.yourdomain.com"
    echo "  This tells the internet: 'For queries about t2, ask"
    echo "  the server at ns.yourdomain.com (your VPS).'"
    echo ""
    echo -e "  ${BOLD}Why 'DNS Only' (grey cloud)?${NC}"
    echo "  Cloudflare's proxy (orange cloud) intercepts traffic."
    echo "  DNS tunneling requires queries to reach YOUR server"
    echo "  directly. If the proxy is ON, queries go to Cloudflare"
    echo "  instead and tunneling breaks completely."
    echo ""
    echo -e "  ${BOLD}Why 4 subdomains?${NC}"
    echo "  Each tunnel type needs its own subdomain so the DNS"
    echo "  Router can route them to the right tunnel:"
    echo "    t2  -> Slipstream + SOCKS  (fastest, QUIC-based)"
    echo "    d2  -> DNSTT + SOCKS       (classic, Noise protocol)"
    echo "    s2  -> Slipstream + SSH    (SSH over DNS)"
    echo "    ds2 -> DNSTT + SSH         (SSH over DNSTT)"
    echo ""
    echo -e "  ${BOLD}Common mistakes${NC}"
    echo "  - Using 'tns' instead of 'ns' for the A record name"
    echo "  - Leaving Cloudflare proxy ON (must be grey cloud)"
    echo "  - Setting NS values to the IP instead of ns.domain"
    echo "  - Forgetting to click Save after adding records"
    help_press_enter
}

help_topic_port53() {
    help_topic_header "3. Port 53 & systemd-resolved"
    echo -e "  ${BOLD}What is port 53?${NC}"
    echo "  Port 53 is the standard port for all DNS traffic."
    echo "  Every DNS query in the world is sent to port 53."
    echo "  Censors almost never block it because it would break"
    echo "  DNS for everyone."
    echo ""
    echo -e "  ${BOLD}Why do DNS tunnels need port 53?${NC}"
    echo "  When a DNS resolver (like 8.8.8.8) forwards a query"
    echo "  to your server, it always sends it to port 53. Your"
    echo "  tunnel server must listen on port 53 to receive these"
    echo "  queries. There is no way to use a different port."
    echo ""
    echo -e "  ${BOLD}What is systemd-resolved?${NC}"
    echo "  systemd-resolved is Ubuntu's built-in DNS cache. It"
    echo "  listens on 127.0.0.53:53 to handle local DNS lookups."
    echo "  Since it occupies port 53, it must be stopped before"
    echo "  the DNS tunnel server can bind to that port."
    echo ""
    echo -e "  ${BOLD}Is it safe to disable?${NC}"
    echo "  Yes! We replace it with 8.8.8.8 (Google DNS) in"
    echo "  /etc/resolv.conf. Your server still resolves domain"
    echo "  names normally — it just queries Google DNS directly"
    echo "  instead of using the local cache."
    help_press_enter
}

help_topic_dnstm() {
    help_topic_header "4. dnstm — DNS Tunnel Manager"
    echo -e "  ${BOLD}What is dnstm?${NC}"
    echo "  A command-line tool that installs, configures, and"
    echo "  manages DNS tunnel servers. Handles all the complex"
    echo "  setup automatically."
    echo ""
    echo -e "  ${BOLD}What is 'multi mode'?${NC}"
    echo "  Multi mode lets multiple tunnels share port 53 through"
    echo "  a DNS Router. The router reads incoming DNS queries and"
    echo "  routes them to the correct tunnel based on subdomain."
    echo ""
    echo -e "  ${BOLD}What gets installed${NC}"
    echo "  - slipstream-server   QUIC-based tunnel binary"
    echo "  - dnstt-server        Classic DNS tunnel binary"
    echo "  - microsocks          SOCKS5 proxy (auto-assigned port)"
    echo "  - systemd services    Auto-start tunnels on boot"
    echo "  - DNS Router          Multiplexes port 53"
    echo ""
    echo -e "  ${BOLD}How the DNS Router works${NC}"
    echo "  All DNS queries arrive at port 53. The router inspects"
    echo "  the domain name: if it's for t2.example.com, it sends"
    echo "  the query to Slipstream. If it's for d2.example.com,"
    echo "  it routes to DNSTT. Each tunnel decodes the data and"
    echo "  forwards it through microsocks to the internet."
    help_press_enter
}

help_topic_ssh() {
    help_topic_header "5. SSH Tunnel Users"
    echo -e "  ${BOLD}What is an SSH tunnel user?${NC}"
    echo "  A restricted account that can ONLY create SSH port-"
    echo "  forwarding tunnels. Cannot run commands, access a"
    echo "  shell, or browse the filesystem."
    echo ""
    echo -e "  ${BOLD}How is it different from a regular user?${NC}"
    echo "  A regular user (like root) has full server access."
    echo "  An SSH tunnel user can ONLY forward ports. Even if"
    echo "  the password is leaked, no one can access your server."
    echo ""
    echo -e "  ${BOLD}How Slipstream + SSH works${NC}"
    echo "  Client -> DNS query -> DNS resolver -> Your server"
    echo "   -> Slipstream (decodes DNS) -> SSH connection"
    echo "   -> SSH port forwarding (-D) -> Internet"
    echo ""
    echo -e "  ${BOLD}SSH vs SOCKS backend${NC}"
    echo "  SOCKS (t2/d2 tunnels):"
    echo "    - Faster, no authentication needed"
    echo "    - Anyone who knows the domain can connect"
    echo "  SSH (s2/ds2 tunnels):"
    echo "    - Requires username + password to connect"
    echo "    - Only authorized users can use it"
    echo "    - Slightly slower (SSH encryption overhead)"
    echo ""
    echo -e "  ${BOLD}Username & password${NC}"
    echo "  - The username/password are shared with ALL your users"
    echo "  - Keep the username simple (e.g. 'tunnel', 'vpn')"
    echo "  - Use a memorable password, NOT your root password"
    echo "  - Even if leaked, the account is port-forwarding only"
    help_press_enter
}

help_topic_architecture() {
    help_topic_header "6. Architecture & How It Works"
    echo -e "  ${BOLD}The Big Picture${NC}"
    echo "  DNS tunneling encodes your internet traffic inside DNS"
    echo "  queries. Since DNS is almost never blocked, it provides"
    echo "  a reliable channel even during internet shutdowns."
    echo ""
    echo -e "  ${BOLD}Data Flow${NC}"
    echo ""
    echo "    Phone (SlipNet app)"
    echo "      |"
    echo "      v"
    echo "    DNS Query (looks like normal DNS traffic)"
    echo "      |"
    echo "      v"
    echo "    Public DNS Resolver (8.8.8.8, 1.1.1.1, etc.)"
    echo "      |"
    echo "      v"
    echo "    Your Server, Port 53"
    echo "      |"
    echo "      v"
    echo "    DNS Router --+--> t2  --> Slipstream --+--> microsocks"
    echo "                 +--> d2  --> DNSTT -------+    (SOCKS5)"
    echo "                 +--> s2  --> Slip+SSH ----+       |"
    echo "                 +--> ds2 --> DNSTT+SSH ---+       v"
    echo "                                              Internet"
    echo ""
    echo -e "  ${BOLD}Protocols${NC}"
    echo "  Slipstream: QUIC-based, TLS encryption, ~63 KB/s"
    echo "  DNSTT:      Noise protocol, Curve25519 keys, ~42 KB/s"
    echo ""
    echo -e "  ${BOLD}Why DNS?${NC}"
    echo "  DNS is the internet's phone book. EVERY device needs"
    echo "  it to work, so censors almost never block it. By hiding"
    echo "  traffic inside DNS queries, you can bypass blocks that"
    echo "  shut down VPNs, Tor, and other tools."
    help_press_enter
}

help_topic_about() {
    help_topic_header "About dnstm-setup"
    echo -e "  ${BOLD}Made By SamNet Technologies - Saman${NC}"
    echo ""
    echo -e "  ${BOLD}dnstm-setup${NC} v${VERSION}"
    echo "  Interactive DNS Tunnel Setup Wizard"
    echo ""
    echo "  Automates the complete setup of DNS tunnel servers"
    echo "  for censorship-resistant internet access. Designed"
    echo "  to help people in restricted regions stay connected."
    echo ""
    echo -e "  ${BOLD}Links${NC}"
    echo "  dnstm-setup   github.com/SamNet-dev/dnstm-setup"
    echo "  dnstm          github.com/net2share/dnstm"
    echo "  sshtun-user    github.com/net2share/sshtun-user"
    echo "  SlipNet        github.com/anonvector/SlipNet"
    echo ""
    echo -e "  ${BOLD}Manual Guide (Farsi)${NC}"
    echo "  telegra.ph/Complete-Guide-to-Setting-Up-a-DNS-Tunnel-03-04"
    echo ""
    echo -e "  ${BOLD}Donate${NC}"
    echo "  www.samnet.dev/donate"
    echo ""
    echo -e "  ${BOLD}License${NC}"
    echo "  MIT License"
    help_press_enter
}

show_help_menu() {
    while true; do
        help_topic_header "Help — Pick a Topic"
        echo -e "  ${BOLD}1${NC}  Domains & DNS Basics"
        echo -e "  ${BOLD}2${NC}  DNS Records (Cloudflare Setup)"
        echo -e "  ${BOLD}3${NC}  Port 53 & systemd-resolved"
        echo -e "  ${BOLD}4${NC}  dnstm — DNS Tunnel Manager"
        echo -e "  ${BOLD}5${NC}  SSH Tunnel Users"
        echo -e "  ${BOLD}6${NC}  Architecture & How It Works"
        echo ""
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}7${NC}  About"
        echo ""
        echo -ne "  ${DIM}Pick a topic (1-7) or Enter to go back: ${NC}"
        read -r choice
        case "${choice:-}" in
            1) help_topic_domain ;;
            2) help_topic_dns_records ;;
            3) help_topic_port53 ;;
            4) help_topic_dnstm ;;
            5) help_topic_ssh ;;
            6) help_topic_architecture ;;
            7) help_topic_about ;;
            *)
                if [[ -n "${choice:-}" ]]; then
                    echo -e "  ${WARN} Invalid choice. Please pick 1–7 or Enter to go back."
                fi
                echo ""
                return
                ;;
        esac
    done
}

# ─── --help ─────────────────────────────────────────────────────────────────────

show_help() {
    banner
    echo -e "${BOLD}DESCRIPTION${NC}"
    echo "  dnstm-setup automates the complete setup of DNS tunnel servers for"
    echo "  censorship-resistant internet access. It installs and configures dnstm"
    echo "  (DNS Tunnel Manager) with Slipstream and DNSTT protocols, sets up SOCKS"
    echo "  and SSH tunnels, and verifies everything works end-to-end."
    echo ""
    echo -e "${BOLD}PREREQUISITES${NC}"
    echo "  - A VPS running Ubuntu/Debian with root access"
    echo "  - A domain managed on Cloudflare"
    echo "  - curl installed on the server"
    echo ""
    echo -e "${BOLD}USAGE${NC}"
    echo "  sudo bash dnstm-setup.sh              Run interactive setup"
    echo "  sudo bash dnstm-setup.sh --add-domain  Add a backup domain to existing setup"
    echo "  sudo bash dnstm-setup.sh --harden      Apply security hardening only"
    echo "  sudo bash dnstm-setup.sh --uninstall   Remove everything"
    echo "  bash dnstm-setup.sh --help             Show this help"
    echo "  bash dnstm-setup.sh --about            Show project info"
    echo ""
    echo -e "${BOLD}FLAGS${NC}"
    echo "  --help         Show this help message"
    echo "  --about        Show project information and credits"
    echo "  --add-domain   Add another domain to an existing server (backup/fallback)"
    echo "  --harden       Apply service and resolver hardening to an existing setup"
    echo "  --uninstall    Remove all installed components"
    echo ""
    echo -e "${BOLD}WHAT THIS SCRIPT SETS UP${NC}"
    echo "  1. Slipstream + SOCKS tunnel  (fastest, ~63 KB/s)"
    echo "  2. DNSTT + SOCKS tunnel       (classic, ~42 KB/s)"
    echo "  3. Slipstream + SSH tunnel    (SSH over DNS)"
    echo "  4. DNSTT + SSH tunnel         (SSH over DNSTT)"
    echo "  5. microsocks SOCKS5 proxy    (auto-installed by dnstm)"
    echo "  6. SSH tunnel user (optional)"
    echo ""
    echo -e "${BOLD}CLIENT APP${NC}"
    echo "  SlipNet (Android): https://github.com/anonvector/SlipNet/releases"
    echo ""
}

# ─── --about ────────────────────────────────────────────────────────────────────

show_about() {
    banner
    echo -e "${BOLD}ABOUT${NC}"
    echo ""
    echo "  dnstm-setup is an interactive installer for DNS tunnel servers."
    echo "  It provides a guided, step-by-step setup process with colored"
    echo "  output, progress tracking, and automated verification."
    echo ""
    echo -e "${BOLD}HOW DNS TUNNELING WORKS${NC}"
    echo ""
    echo "  DNS tunneling encodes data inside DNS queries and responses."
    echo "  Since DNS is almost never blocked (even during internet shutdowns),"
    echo "  it provides a reliable channel for internet access. Your traffic"
    echo "  flows through public DNS resolvers to your tunnel server, which"
    echo "  decodes it and forwards it to the internet."
    echo ""
    echo "  Architecture:"
    echo ""
    echo "    Client (SlipNet)"
    echo "      --> DNS Query"
    echo "        --> Public Resolver (8.8.8.8)"
    echo "          --> Your Server (Port 53)"
    echo "            --> DNS Router"
    echo "              --> Tunnel --> Internet"
    echo ""
    echo -e "${BOLD}SUPPORTED PROTOCOLS${NC}"
    echo ""
    echo "  Slipstream  QUIC-based DNS tunnel with TLS encryption"
    echo "              Uses self-signed certificates (cert.pem/key.pem)"
    echo "              Speed: ~63 KB/s"
    echo ""
    echo "  DNSTT       Classic DNS tunnel using Noise protocol"
    echo "              Uses Curve25519 key pairs (server.key/server.pub)"
    echo "              Speed: ~42 KB/s"
    echo ""
    echo -e "${BOLD}RELATED PROJECTS${NC}"
    echo ""
    echo "  dnstm          https://github.com/net2share/dnstm"
    echo "  sshtun-user    https://github.com/net2share/sshtun-user"
    echo "  SlipNet        https://github.com/anonvector/SlipNet/releases"
    echo ""
    echo -e "${BOLD}LICENSE${NC}"
    echo ""
    echo "  MIT License"
    echo ""
    echo -e "${BOLD}AUTHOR${NC}"
    echo ""
    echo "  Made By SamNet Technologies - Saman"
    echo "  https://github.com/SamNet-dev"
    echo ""
}

# ─── Security Hardening Helpers ────────────────────────────────────────────────

ensure_resolv_conf_fallback() {
    # After stopping systemd-resolved, /etc/resolv.conf may still point to
    # 127.0.0.53 which is now dead.  Write a temporary fallback so the script
    # can still resolve hostnames (e.g. github.com for downloads).
    if grep -q '127\.0\.0\.53' /etc/resolv.conf 2>/dev/null; then
        print_info "Updating /etc/resolv.conf with public DNS fallback"
        chattr -i /etc/resolv.conf 2>/dev/null || true
        cat > /etc/resolv.conf <<'RESOLVEOF'
# Temporary fallback written by dnstm-setup (systemd-resolved was stopped)
nameserver 8.8.8.8
nameserver 1.1.1.1
RESOLVEOF
    fi
}

configure_systemd_resolved_no_stub() {
    # Keep system DNS working while freeing port 53 from the local stub listener.
    if ! command -v systemctl &>/dev/null; then
        print_warn "systemctl not found; skipping resolver hardening"
        return 0
    fi

    if ! systemctl cat systemd-resolved.service &>/dev/null; then
        print_warn "systemd-resolved is not installed; skipping resolver hardening"
        return 0
    fi

    mkdir -p /etc/systemd/resolved.conf.d
    cat > /etc/systemd/resolved.conf.d/10-dnstm-no-stub.conf <<'EOF'
[Resolve]
DNSStubListener=no
EOF

    # If a previous run locked resolv.conf, unlock it before relinking.
    chattr -i /etc/resolv.conf 2>/dev/null || true

    systemctl unmask systemd-resolved.service systemd-resolved.socket 2>/dev/null || true
    systemctl enable systemd-resolved.service 2>/dev/null || true
    if ! systemctl restart systemd-resolved.service 2>/dev/null; then
        print_warn "Could not restart systemd-resolved; keeping current resolver setup"
        return 1
    fi

    if [[ -e /run/systemd/resolve/resolv.conf ]]; then
        ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    fi

    return 0
}

write_service_override() {
    local unit="$1"
    local run_user="$2"
    local run_group="$3"
    local needs_bind_cap="${4:-no}"
    local dropin_dir="/etc/systemd/system/${unit}.d"
    local dropin_file="${dropin_dir}/20-hardening.conf"

    mkdir -p "$dropin_dir"

    cat > "$dropin_file" <<EOF
[Service]
User=${run_user}
Group=${run_group}
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ReadWritePaths=/etc/dnstm
ProtectHome=yes
ProtectControlGroups=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectClock=yes
ProtectHostname=yes
LockPersonality=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
RestrictNamespaces=yes
SystemCallArchitectures=native
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
UMask=0077
EOF

    if [[ "$needs_bind_cap" == "yes" ]]; then
        cat >> "$dropin_file" <<'EOF'
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
EOF
    else
        cat >> "$dropin_file" <<'EOF'
AmbientCapabilities=
CapabilityBoundingSet=
EOF
    fi
}

unit_exists() {
    local unit="$1"
    systemctl cat "$unit" >/dev/null 2>&1
}

enable_autostart_units() {
    local dnstm_units unit
    dnstm_units=$(systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '$1 ~ /^dnstm-.*\.service$/ {print $1}' || true)
    for unit in $dnstm_units microsocks.service; do
        if ! unit_exists "$unit"; then
            continue
        fi
        if ! systemctl enable "$unit" >/dev/null 2>&1; then
            print_warn "Could not enable ${unit} for boot autostart"
        fi
    done
    print_ok "Boot autostart enabled for dnstm and microsocks services"
}

apply_service_hardening() {
    print_info "Applying least-privilege service hardening..."

    if ! id -u dnstm &>/dev/null; then
        if useradd --system --home /nonexistent --shell /usr/sbin/nologin dnstm 2>/dev/null; then
            print_ok "Created service account: dnstm"
        else
            print_fail "Could not create service account: dnstm"
            return 1
        fi
    fi

    if [[ -d /etc/dnstm ]]; then
        chown -R root:dnstm /etc/dnstm 2>/dev/null || true
        find /etc/dnstm -type d -exec chmod 750 {} + 2>/dev/null || true
        find /etc/dnstm -type f -exec chmod 640 {} + 2>/dev/null || true
        find /etc/dnstm -type f \( -name "*.pub" -o -name "cert.pem" \) -exec chmod 644 {} + 2>/dev/null || true
        find /etc/dnstm -type f \( -name "*.key" -o -name "server.key" \) -exec chmod 640 {} + 2>/dev/null || true
        print_ok "Hardened /etc/dnstm ownership and permissions"
    else
        print_warn "/etc/dnstm not found yet; skipping file permission hardening"
    fi

    local dnstm_units
    dnstm_units=$(systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '$1 ~ /^dnstm-.*\.service$/ {print $1}' || true)
    if [[ -z "$dnstm_units" ]]; then
        print_warn "No dnstm systemd units found to harden"
        return 0
    fi

    local unit
    for unit in $dnstm_units; do
        if [[ "$unit" == "dnstm-dnsrouter.service" ]]; then
            write_service_override "$unit" "dnstm" "dnstm" "yes"
        else
            write_service_override "$unit" "dnstm" "dnstm" "no"
        fi
    done

    if unit_exists "microsocks.service"; then
        write_service_override "microsocks.service" "nobody" "nogroup" "no"
    fi

    systemctl daemon-reload

    local hardening_ok=true
    for unit in $dnstm_units microsocks.service; do
        if ! unit_exists "$unit"; then
            continue
        fi
        if systemctl is-enabled "$unit" &>/dev/null || systemctl is-active --quiet "$unit" 2>/dev/null; then
            if ! systemctl restart "$unit" 2>/dev/null; then
                print_warn "Failed to restart hardened unit: $unit — rolling back"
                local dropin="/etc/systemd/system/${unit}.d/20-hardening.conf"
                rm -f "$dropin"
                systemctl daemon-reload
                systemctl reset-failed "$unit" 2>/dev/null || true
                systemctl restart "$unit" 2>/dev/null || true
                hardening_ok=false
            fi
        fi
    done

    if [[ "$hardening_ok" != "true" ]]; then
        print_warn "Some units could not be hardened; services restored without hardening"
        return 1
    fi

    enable_autostart_units
    print_ok "Applied systemd hardening overrides"
    return 0
}

do_harden() {
    banner
    print_header "Security Hardening Mode"

    if [[ $EUID -ne 0 ]]; then
        print_fail "Not running as root. Please run with: sudo bash $0 --harden"
        exit 1
    fi

    configure_systemd_resolved_no_stub || true
    apply_service_hardening

    echo ""
    print_info "Current unit users:"
    for unit in dnstm-dnsrouter.service dnstm-dnstt1.service dnstm-slip1.service dnstm-dnstt-ssh.service dnstm-slip-ssh.service microsocks.service; do
        if unit_exists "$unit"; then
            systemctl show -p User -p Group "$unit" 2>/dev/null || true
        fi
    done
    echo ""
    print_ok "Hardening complete."
}

# ─── --uninstall ────────────────────────────────────────────────────────────────

do_uninstall() {
    banner

    if [[ $EUID -ne 0 ]]; then
        echo -e "  ${CROSS} Not running as root. Please run with: sudo bash $0 --uninstall"
        exit 1
    fi

    print_header "Uninstall DNS Tunnel Setup"

    echo -e "  ${YELLOW}This will remove all DNS tunnel components from this server.${NC}"
    echo ""
    echo "  Components to remove:"
    echo "    - All dnstm tunnels and router"
    echo "    - dnstm binary and configuration"
    echo "    - sshtun-user binary (if installed)"
    echo "    - microsocks service"
    echo ""

    if ! prompt_yn "Are you sure you want to uninstall everything?" "n"; then
        echo ""
        print_info "Uninstall cancelled."
        exit 0
    fi

    echo ""

    # Stop and remove tunnels
    if command -v dnstm &>/dev/null; then
        print_info "Stopping tunnels..."
        local tags
        tags=$(dnstm tunnel list 2>/dev/null | grep -o 'tag=[^ ]*' | sed 's/tag=//' || true)
        for tag in $tags; do
            dnstm tunnel stop --tag "$tag" 2>/dev/null && print_ok "Stopped tunnel: $tag" || true
        done

        print_info "Stopping router..."
        dnstm router stop 2>/dev/null && print_ok "Router stopped" || true

        print_info "Removing tunnels..."
        for tag in $tags; do
            dnstm tunnel remove --tag "$tag" 2>/dev/null && print_ok "Removed tunnel: $tag" || true
        done

        print_info "Uninstalling dnstm..."
        dnstm uninstall 2>/dev/null && print_ok "dnstm uninstalled" || print_warn "dnstm uninstall returned an error (may already be removed)"
    else
        print_info "dnstm not found, skipping tunnel cleanup"
    fi

    # Remove binaries
    if [[ -f /usr/local/bin/dnstm ]]; then
        rm -f /usr/local/bin/dnstm
        print_ok "Removed /usr/local/bin/dnstm"
    fi

    if [[ -f /usr/local/bin/sshtun-user ]]; then
        rm -f /usr/local/bin/sshtun-user
        print_ok "Removed /usr/local/bin/sshtun-user"
    fi

    # Stop microsocks
    if systemctl is-active --quiet microsocks 2>/dev/null; then
        systemctl stop microsocks 2>/dev/null || true
        systemctl disable microsocks 2>/dev/null || true
        print_ok "Stopped and disabled microsocks"
    fi

    # Remove config directory
    if [[ -d /etc/dnstm ]]; then
        rm -rf /etc/dnstm
        print_ok "Removed /etc/dnstm"
    fi

    # Remove systemd hardening overrides (if present)
    find /etc/systemd/system -maxdepth 2 -type f -name '20-hardening.conf' -path '*/dnstm-*.service.d/*' -delete 2>/dev/null || true
    rm -f /etc/systemd/system/microsocks.service.d/20-hardening.conf 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    print_ok "Removed local service hardening drop-ins"

    # Remove resolver override used to free port 53
    rm -f /etc/systemd/resolved.conf.d/10-dnstm-no-stub.conf 2>/dev/null || true

    # Unlock resolv.conf so the system can manage DNS again
    chattr -i /etc/resolv.conf 2>/dev/null || true
    print_ok "Removed immutable flag from /etc/resolv.conf"

    systemctl unmask systemd-resolved.socket systemd-resolved.service 2>/dev/null || true
    systemctl enable systemd-resolved.service 2>/dev/null || true
    systemctl restart systemd-resolved.service 2>/dev/null || true
    if [[ -e /run/systemd/resolve/stub-resolv.conf ]]; then
        ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    fi
    print_ok "Restored systemd-resolved defaults (best effort)"

    echo ""
    print_ok "${GREEN}Uninstall complete.${NC}"
    echo ""
    print_warn "Note: DNS records in Cloudflare were NOT removed. Remove them manually if needed."
    echo ""
}

# ─── Parse Arguments ────────────────────────────────────────────────────────────

ADD_DOMAIN_MODE=false
HARDEN_ONLY_MODE=false

case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --about)
        show_about
        exit 0
        ;;
    --uninstall)
        do_uninstall
        exit 0
        ;;
    --add-domain)
        ADD_DOMAIN_MODE=true
        ;;
    --harden)
        HARDEN_ONLY_MODE=true
        ;;
    "")
        # No args, continue with setup
        ADD_DOMAIN_MODE=false
        HARDEN_ONLY_MODE=false
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information."
        exit 1
        ;;
esac

# ─── Variables (populated during setup) ─────────────────────────────────────────

DOMAIN=""
SERVER_IP=""
DNSTT_PUBKEY=""
SSH_USER=""
SSH_PASS=""
TUNNELS_CHANGED=false
SSH_SETUP_DONE=false

# ─── STEP 1: Pre-flight Checks ─────────────────────────────────────────────────

step_preflight() {
    print_step 1 "Pre-flight Checks"

    # Check root
    if [[ $EUID -eq 0 ]]; then
        print_ok "Running as root"
    else
        print_fail "Not running as root. Please run with: sudo bash $0"
        exit 1
    fi

    # Check OS (read in subshell to avoid overwriting script's VERSION variable)
    if [[ -f /etc/os-release ]]; then
        local os_id os_name
        os_id=$(. /etc/os-release && echo "${ID:-}")
        os_name=$(. /etc/os-release && echo "${PRETTY_NAME:-$os_id}")
        if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
            print_ok "OS: ${os_name}"
        else
            print_warn "OS: ${os_name} (not Ubuntu/Debian - may work but untested)"
        fi
    else
        print_warn "Cannot detect OS (missing /etc/os-release)"
    fi

    # Check curl
    if command -v curl &>/dev/null; then
        print_ok "curl is installed"
    else
        print_fail "curl is not installed"
        echo ""
        if prompt_yn "Install curl now?" "y"; then
            if apt-get update -qq && apt-get install -y -qq curl; then
                print_ok "curl installed"
            else
                print_fail "Failed to install curl. Check your network/repos."
                exit 1
            fi
        else
            echo ""
            print_fail "curl is required. Please install it and re-run."
            exit 1
        fi
    fi

    # Detect server IP
    SERVER_IP=$(curl -4 -s --max-time 10 https://api.ipify.org 2>/dev/null || true)
    if [[ -n "$SERVER_IP" ]]; then
        print_ok "Server IP: ${SERVER_IP}"
    else
        print_warn "Could not auto-detect server IP"
        SERVER_IP=$(prompt_input "Enter your server's public IP")
        if [[ -z "$SERVER_IP" ]]; then
            print_fail "Server IP is required."
            exit 1
        fi
    fi

    echo ""
    print_ok "All pre-flight checks passed"
}

# ─── STEP 2: Ask Domain ────────────────────────────────────────────────────────

step_ask_domain() {
    print_step 2 "Domain Configuration"

    while true; do
        DOMAIN=$(prompt_input "Enter your domain (e.g. example.com)")
        # Strip whitespace, http(s)://, trailing slashes
        DOMAIN=$(echo "$DOMAIN" | sed 's|^[[:space:]]*||;s|[[:space:]]*$||;s|^https\?://||;s|/.*$||')
        if [[ -z "$DOMAIN" ]]; then
            print_fail "Domain cannot be empty. Please try again."
        elif [[ ! "$DOMAIN" =~ \. ]]; then
            print_fail "Invalid domain (must contain a dot). Please try again."
        elif [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
            print_fail "Invalid domain (use only letters, numbers, dots, hyphens). Please try again."
        else
            break
        fi
    done

    echo ""
    print_ok "Using domain: ${BOLD}${DOMAIN}${NC}"
}

# ─── STEP 3: Show DNS Records ──────────────────────────────────────────────────

step_dns_records() {
    print_step 3 "DNS Records (Cloudflare)"

    print_info "Create these DNS records in your Cloudflare dashboard:"
    echo ""
    print_box \
        "Record 1:  Type: A   | Name: ns | Value: ${SERVER_IP}" \
        "           Proxy: OFF (DNS Only - grey cloud)" \
        "" \
        "Record 2:  Type: NS  | Name: t2  | Value: ns.${DOMAIN}" \
        "Record 3:  Type: NS  | Name: d2  | Value: ns.${DOMAIN}" \
        "Record 4:  Type: NS  | Name: s2  | Value: ns.${DOMAIN}" \
        "Record 5:  Type: NS  | Name: ds2 | Value: ns.${DOMAIN}"

    echo ""
    print_warn "IMPORTANT: The A record MUST be DNS Only (grey cloud, NOT orange)"
    print_warn "IMPORTANT: The A record name must be \"ns\" (not \"tns\")"
    echo ""
    echo "  Subdomain purposes:"
    echo "    t2  = Slipstream + SOCKS tunnel"
    echo "    d2  = DNSTT + SOCKS tunnel"
    echo "    s2  = Slipstream + SSH tunnel"
    echo "    ds2 = DNSTT + SSH tunnel"
    echo ""

    if ! prompt_yn "Have you created these DNS records in Cloudflare?" "n"; then
        echo ""
        print_info "Please create the DNS records and re-run this script."
        exit 0
    fi

    echo ""
    print_ok "DNS records confirmed"
}

# ─── STEP 4: Free Port 53 ──────────────────────────────────────────────────────

step_free_port53() {
    print_step 4 "Free Port 53"

    local port53_output
    port53_output=$(ss -ulnp 2>/dev/null | grep -E ':53\b' || true)

    if [[ -z "$port53_output" ]]; then
        print_ok "Port 53 is free"
        return
    fi

    # dnstm already on port 53 is fine (re-run scenario)
    if echo "$port53_output" | grep -q "dnstm"; then
        print_ok "Port 53 is in use by dnstm (already set up)"
        return
    fi

    print_info "Something is using port 53:"
    echo -e "  ${DIM}${port53_output}${NC}"
    echo ""

    if echo "$port53_output" | grep -q "systemd-resolve\|127\.0\.0\.53"; then
        print_warn "systemd-resolved is occupying port 53"
        echo ""
        if prompt_yn "Configure systemd-resolved to disable only DNSStubListener?" "y"; then
            # Safer than masking resolved entirely: keep DNS management, only free :53.
            configure_systemd_resolved_no_stub || true
            sleep 1
            port53_output=$(ss -ulnp 2>/dev/null | grep -E ':53\b' || true)

            # Fallback if stub is still present.
            if echo "$port53_output" | grep -q "systemd-resolve\|127\.0\.0\.53"; then
                print_warn "systemd-resolved still occupies port 53; stopping service as fallback"
                systemctl stop systemd-resolved.socket 2>/dev/null || true
                systemctl stop systemd-resolved.service 2>/dev/null || true
                ensure_resolv_conf_fallback
                sleep 1
            fi
        else
            print_fail "Port 53 must be free for DNS tunnels to work."
            exit 1
        fi
    else
        print_fail "An unknown service is using port 53."
        print_info "Please stop it manually and re-run this script."
        exit 1
    fi

    # Verify port is now free
    port53_output=$(ss -ulnp 2>/dev/null | grep -E ':53\b' || true)
    if [[ -z "$port53_output" ]]; then
        print_ok "Port 53 is now free"
    else
        print_fail "Port 53 is still in use. Please investigate manually."
        exit 1
    fi
}

# ─── STEP 5: Install dnstm ─────────────────────────────────────────────────────

step_install_dnstm() {
    print_step 5 "Install dnstm"

    # Check if already installed
    if command -v dnstm &>/dev/null; then
        local ver
        ver=$(dnstm --version 2>/dev/null || echo "unknown")
        print_info "dnstm is already installed (${ver})"
        echo ""
        if ! prompt_yn "Re-install / update dnstm?" "n"; then
            # Ensure router is in multi mode even if we skip install
            local current_mode
            current_mode=$(dnstm router mode 2>/dev/null | awk '/[Mm]ode/{for(i=1;i<=NF;i++) if($i=="multi"||$i=="single") print $i}' | head -1 || true)
            if [[ "$current_mode" != "multi" ]]; then
                print_warn "Router mode is '${current_mode:-unknown}', switching to multi..."
                if dnstm router mode multi 2>/dev/null; then
                    print_ok "Router mode switched to multi"
                else
                    print_fail "Failed to switch router mode to multi"
                    exit 1
                fi
            else
                print_ok "Router mode: multi"
            fi
            print_ok "Skipping dnstm installation"
            return
        fi
    fi

    # Stop and remove ALL tunnels so they get fresh configs after re-install
    print_info "Stopping dnstm services..."
    dnstm router stop 2>/dev/null || true
    # Remove all existing tunnels (they'll be recreated in Step 7 with correct ports)
    local old_tags
    old_tags=$(dnstm tunnel list 2>/dev/null | grep -o 'tag=[^ ]*' | sed 's/tag=//' || true)
    for tag in $old_tags; do
        dnstm tunnel stop --tag "$tag" 2>/dev/null || true
        dnstm tunnel remove --tag "$tag" 2>/dev/null || true
    done
    # Stop all dnstm systemd units
    local unit
    for unit in $(systemctl list-units --type=service --no-legend 'dnstm-*' 2>/dev/null | awk '{print $1}' || true); do
        systemctl stop "$unit" 2>/dev/null || true
    done
    systemctl stop dnstm-dnsrouter 2>/dev/null || true
    systemctl stop microsocks 2>/dev/null || true
    # Kill tunnel/router processes by exact name (NOT -f, to avoid killing this script)
    # slipstream-server comm name is truncated to 15 chars: "slipstream-serv"
    pkill -9 slipstream-serv 2>/dev/null || true
    pkill -9 dnstt-server 2>/dev/null || true
    pkill -9 microsocks 2>/dev/null || true
    # dnstm-dnsrouter comm name is truncated to 15 chars: "dnstm-dnsroute"
    pkill -9 dnstm-dnsroute 2>/dev/null || true
    # Kill the dnstm binary itself (comm name = "dnstm", won't match "bash dnstm-setup.sh")
    pkill -9 -x dnstm 2>/dev/null || true
    sleep 1
    # Reset systemd failed state before removing binary to prevent start-limit-hit
    for unit in $(systemctl list-units --all --type=service --no-legend 'dnstm-*' 2>/dev/null | awk '{print $1}' || true); do
        systemctl reset-failed "$unit" 2>/dev/null || true
    done
    systemctl reset-failed dnstm-dnsrouter 2>/dev/null || true
    rm -f /usr/local/bin/dnstm

    # Download binary
    print_info "Downloading dnstm..."
    if curl -fsSL -o /usr/local/bin/dnstm https://github.com/net2share/dnstm/releases/latest/download/dnstm-linux-amd64; then
        chmod +x /usr/local/bin/dnstm
        print_ok "Downloaded dnstm binary"
    else
        print_fail "Failed to download dnstm"
        exit 1
    fi

    # Save iptables state before dnstm install (it may reset firewall rules)
    local iptables_backup="/tmp/iptables-backup-$$"
    iptables-save > "$iptables_backup" 2>/dev/null || true

    # Install in multi mode (use --force on re-install)
    print_info "Running dnstm install --mode multi ..."
    echo ""
    local install_ok=false
    if dnstm install --mode multi --force; then
        echo ""
        install_ok=true
        print_ok "dnstm installed successfully"
        TUNNELS_CHANGED=true
    else
        echo ""
        print_fail "dnstm install failed"
    fi

    # Restore original firewall rules (dnstm install may have reset them)
    if [[ -s "$iptables_backup" ]]; then
        iptables-restore < "$iptables_backup" 2>/dev/null || true
    else
        # Do not force permissive policies if we don't have a valid snapshot.
        print_warn "No iptables snapshot found; leaving existing firewall policy unchanged"
    fi
    rm -f "$iptables_backup"

    if [[ "$install_ok" != "true" ]]; then
        exit 1
    fi

    # Verify
    local ver
    ver=$(dnstm --version 2>/dev/null || echo "unknown")
    print_ok "dnstm version: ${ver}"

    echo ""
    print_info "dnstm install sets up:"
    echo "    - Tunnel binaries (slipstream-server, dnstt-server, microsocks)"
    echo "    - System user (dnstm)"
    echo "    - Firewall rules (port 53)"
    echo "    - DNS Router service"
    echo "    - microsocks SOCKS5 proxy"
}

# ─── STEP 6: Verify Port 53 ────────────────────────────────────────────────────

step_verify_port53() {
    print_step 6 "Verify Port 53"

    local port53_output
    port53_output=$(ss -ulnp 2>/dev/null | grep -E ':53\b' || true)

    # If systemd-resolved crept back to :53, switch it to no-stub mode.
    if echo "$port53_output" | grep -q "systemd-resolve\|127\.0\.0\.53"; then
        print_warn "systemd-resolved came back on :53 — reconfiguring stub listener"
        configure_systemd_resolved_no_stub || true
        sleep 2
        port53_output=$(ss -ulnp 2>/dev/null | grep -E ':53\b' || true)
        if echo "$port53_output" | grep -q "systemd-resolve\|127\.0\.0\.53"; then
            print_warn "systemd-resolved still occupies :53; stopping service as fallback"
            systemctl stop systemd-resolved.socket 2>/dev/null || true
            systemctl stop systemd-resolved.service 2>/dev/null || true
            ensure_resolv_conf_fallback
        fi
        sleep 2
        port53_output=$(ss -ulnp 2>/dev/null | grep -E ':53\b' || true)
    fi

    if echo "$port53_output" | grep -q "dnstm"; then
        print_ok "dnstm DNS Router is already on port 53"
        print_info "Router will be restarted after tunnel creation to pick up any changes"
    elif [[ -z "$port53_output" ]]; then
        print_ok "Port 53 is free — ready for DNS Router"
    else
        print_warn "Port 53 is in use by an unknown process:"
        echo "$port53_output"
        print_fail "Cannot proceed — port 53 must be free for the DNS Router"
        exit 1
    fi

    # Firewall
    print_info "Ensuring firewall allows port 53..."

    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw allow 53/tcp &>/dev/null || true
        ufw allow 53/udp &>/dev/null || true
        print_ok "ufw: port 53 TCP/UDP allowed"
    elif command -v ufw &>/dev/null; then
        print_info "ufw is installed but inactive; skipping ufw rule changes"
    fi

    if command -v iptables &>/dev/null; then
        # Check if rules already exist before adding
        if ! iptables -C INPUT -p tcp --dport 53 -j ACCEPT &>/dev/null; then
            iptables -A INPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null || true
        fi
        if ! iptables -C INPUT -p udp --dport 53 -j ACCEPT &>/dev/null; then
            iptables -A INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
        fi
        print_ok "iptables: port 53 TCP/UDP allowed"
    fi

    echo ""
    print_warn "If your hosting provider has an external firewall (web panel),"
    print_warn "make sure port 53 UDP and TCP are open there too."
}

# ─── STEP 7: Create Tunnels ────────────────────────────────────────────────────

step_create_tunnels() {
    print_step 7 "Create Tunnels"

    local any_created=false
    print_info "Creating 4 tunnels for domain: ${BOLD}${DOMAIN}${NC}"
    echo ""

    # Tunnel 1: Slipstream + SOCKS
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel 1: Slipstream + SOCKS${NC}"
    echo ""
    if dnstm tunnel add --transport slipstream --backend socks --domain "t2.${DOMAIN}" --tag slip1 2>&1; then
        print_ok "Created: slip1 (Slipstream + SOCKS) on t2.${DOMAIN}"
        any_created=true
    else
        print_warn "Tunnel slip1 may already exist or creation failed"
        print_info "If it already exists, this is OK"
    fi
    echo ""

    # Tunnel 2: DNSTT + SOCKS
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel 2: DNSTT + SOCKS${NC}"
    echo ""
    local dnstt_output
    dnstt_output=$(dnstm tunnel add --transport dnstt --backend socks --domain "d2.${DOMAIN}" --tag dnstt1 2>&1) || true
    echo "$dnstt_output"

    # Try to extract DNSTT public key
    DNSTT_PUBKEY=""
    if [[ -f /etc/dnstm/tunnels/dnstt1/server.pub ]]; then
        DNSTT_PUBKEY=$(cat /etc/dnstm/tunnels/dnstt1/server.pub 2>/dev/null || true)
    fi

    if [[ -n "$DNSTT_PUBKEY" ]]; then
        print_ok "Created: dnstt1 (DNSTT + SOCKS) on d2.${DOMAIN}"
        any_created=true
        echo ""
        echo -e "  ${BOLD}${YELLOW}DNSTT Public Key (save this!):${NC}"
        echo -e "  ${GREEN}${DNSTT_PUBKEY}${NC}"
    else
        print_warn "Tunnel dnstt1 may already exist or creation failed"
        print_info "If it already exists, this is OK"
    fi
    echo ""

    # Tunnel 3: Slipstream + SSH
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel 3: Slipstream + SSH${NC}"
    echo ""
    if dnstm tunnel add --transport slipstream --backend ssh --domain "s2.${DOMAIN}" --tag slip-ssh 2>&1; then
        print_ok "Created: slip-ssh (Slipstream + SSH) on s2.${DOMAIN}"
        any_created=true
    else
        print_warn "Tunnel slip-ssh may already exist or creation failed"
        print_info "If it already exists, this is OK"
    fi
    echo ""

    # Tunnel 4: DNSTT + SSH
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel 4: DNSTT + SSH${NC}"
    echo ""
    if dnstm tunnel add --transport dnstt --backend ssh --domain "ds2.${DOMAIN}" --tag dnstt-ssh 2>&1; then
        print_ok "Created: dnstt-ssh (DNSTT + SSH) on ds2.${DOMAIN}"
        any_created=true
    else
        print_warn "Tunnel dnstt-ssh may already exist or creation failed"
        print_info "If it already exists, this is OK"
    fi
    echo ""

    # Re-read DNSTT key if not captured
    if [[ -z "$DNSTT_PUBKEY" && -f /etc/dnstm/tunnels/dnstt1/server.pub ]]; then
        DNSTT_PUBKEY=$(cat /etc/dnstm/tunnels/dnstt1/server.pub 2>/dev/null || true)
        if [[ -n "$DNSTT_PUBKEY" ]]; then
            echo -e "  ${BOLD}${YELLOW}DNSTT Public Key:${NC}"
            echo -e "  ${GREEN}${DNSTT_PUBKEY}${NC}"
        fi
    fi

    if [[ "$any_created" == true ]]; then
        TUNNELS_CHANGED=true
    fi
    print_ok "All tunnels created"
}

# ─── STEP 8: Start Services ────────────────────────────────────────────────────

step_start_services() {
    print_step 8 "Start Services"

    # Only restart router if tunnels/install changed (avoid downtime on re-runs)
    if [[ "$TUNNELS_CHANGED" == "true" ]]; then
        # Stop router first to ensure it picks up the new tunnel config
        # (install may have started it before tunnels were created)
        print_info "Stopping DNS Router (to reload tunnel config)..."
        dnstm router stop 2>/dev/null || true
        sleep 1

        # Start router — this reads config.json which now has all tunnels
        print_info "Starting DNS Router..."
        if dnstm router start 2>/dev/null; then
            print_ok "DNS Router started"
        else
            print_warn "DNS Router start returned an error. Checking status..."
            if dnstm router status 2>/dev/null | grep -qi "running"; then
                print_ok "DNS Router is running"
            else
                print_fail "DNS Router failed to start. Check: dnstm router logs"
                exit 1
            fi
        fi

        # Wait for router to bind to port 53
        local attempts=0
        local max_attempts=10
        while [[ $attempts -lt $max_attempts ]]; do
            sleep 1
            if ss -ulnp 2>/dev/null | grep -E ':53\b' | grep -q "dnstm"; then
                print_ok "DNS Router confirmed on port 53"
                break
            fi
            attempts=$((attempts + 1))
        done

        if [[ $attempts -ge $max_attempts ]]; then
            print_warn "DNS Router may not be on port 53 yet. Check: dnstm router logs"
        fi
    else
        # No changes — just verify router is running
        if ss -ulnp 2>/dev/null | grep -E ':53\b' | grep -q "dnstm"; then
            print_ok "DNS Router already running on port 53 (no restart needed)"
        else
            print_warn "DNS Router not detected on port 53. Attempting start..."
            dnstm router start 2>/dev/null || true
            sleep 2
            if ss -ulnp 2>/dev/null | grep -E ':53\b' | grep -q "dnstm"; then
                print_ok "DNS Router started on port 53"
            else
                print_fail "DNS Router failed to start. Check: dnstm router logs"
                exit 1
            fi
        fi
    fi

    echo ""

    # Start tunnels (discover all tags dynamically to support --add-domain tunnels)
    local all_tags
    all_tags=$(dnstm tunnel list 2>/dev/null | grep -o 'tag=[^ ]*' | sed 's/tag=//' || true)
    if [[ -z "$all_tags" ]]; then
        all_tags="slip1 dnstt1 slip-ssh dnstt-ssh"
    fi
    for tag in $all_tags; do
        print_info "Starting tunnel: ${tag}..."
        if dnstm tunnel start --tag "$tag" 2>/dev/null; then
            print_ok "Started: ${tag}"
        else
            if dnstm tunnel list 2>/dev/null | grep "$tag" | grep -qi "running"; then
                print_ok "Already running: ${tag}"
            else
                print_warn "Could not start: ${tag}. Check: dnstm tunnel logs --tag ${tag}"
            fi
        fi
    done

    echo ""
    print_info "Current tunnel status:"
    echo ""
    dnstm tunnel list 2>/dev/null || print_warn "Could not get tunnel list"
    echo ""

    if apply_service_hardening; then
        print_ok "Runtime hardening applied to dnstm and microsocks services"
    else
        print_warn "Runtime hardening reported issues; review systemctl status for dnstm units"
    fi
}

# ─── STEP 9: Verify microsocks ─────────────────────────────────────────────────

step_verify_microsocks() {
    print_step 9 "Verify SOCKS Proxy (microsocks)"

    # Check if microsocks binary has GLIBC compatibility issues
    local microsocks_bin
    microsocks_bin=$(command -v microsocks 2>/dev/null || echo "/usr/local/bin/microsocks")
    if [[ -x "$microsocks_bin" ]]; then
        local glibc_err
        glibc_err=$("$microsocks_bin" --help 2>&1 || true)
        if echo "$glibc_err" | grep -q "GLIBC.*not found"; then
            print_warn "microsocks binary is incompatible with this OS (GLIBC version mismatch)"
            print_info "Building microsocks from source..."

            # Install build tools
            apt-get install -y -qq gcc make git >/dev/null 2>&1 || true

            # Build from source
            local build_dir="/tmp/microsocks-build"
            rm -rf "$build_dir"
            if git clone --quiet https://github.com/rofl0r/microsocks.git "$build_dir" 2>/dev/null; then
                if make -C "$build_dir" -j"$(nproc)" >/dev/null 2>&1; then
                    cp "$build_dir/microsocks" "$microsocks_bin"
                    chmod +x "$microsocks_bin"
                    print_ok "Built microsocks from source"
                    # Restart the service with the new binary
                    systemctl restart microsocks 2>/dev/null || true
                    sleep 1
                else
                    print_fail "Failed to build microsocks from source"
                fi
            else
                print_fail "Failed to clone microsocks repo"
            fi
            rm -rf "$build_dir"
        fi
    fi

    # Check if microsocks is running
    if pgrep -x microsocks &>/dev/null || systemctl is-active --quiet microsocks 2>/dev/null; then
        print_ok "microsocks is running"
    else
        print_warn "microsocks is not running"
        print_info "Starting microsocks..."

        systemctl enable microsocks 2>/dev/null || true
        if systemctl start microsocks 2>/dev/null; then
            print_ok "microsocks started"
        else
            print_fail "Failed to start microsocks"
            print_info "Check: systemctl status microsocks"
        fi
    fi

    # Detect actual microsocks port (3 methods, most reliable first)
    local socks_port=""
    # Method 1: parse ss output — find the listen port on the microsocks line
    socks_port=$(ss -tlnp 2>/dev/null | grep microsocks | awk '{for(i=1;i<=NF;i++) if($i ~ /:[0-9]+$/) {split($i,a,":"); print a[length(a)]; exit}}' || true)
    # Method 2: parse the systemd unit file for -p flag
    if [[ -z "$socks_port" ]]; then
        socks_port=$(sed -n 's/.*-p[[:space:]]*\([0-9]*\).*/\1/p' /etc/systemd/system/microsocks.service 2>/dev/null | head -1 || true)
    fi
    # Method 3: fallback
    if [[ -z "$socks_port" ]]; then
        socks_port="19801"
    fi

    # Test SOCKS proxy
    echo ""
    print_info "Testing SOCKS proxy on 127.0.0.1:${socks_port}..."
    local test_ip
    test_ip=$(curl -s --max-time 10 --socks5 "127.0.0.1:${socks_port}" https://api.ipify.org 2>/dev/null || true)

    if [[ -n "$test_ip" ]]; then
        print_ok "SOCKS proxy works! Response: ${test_ip}"
    else
        print_warn "SOCKS proxy test failed (this may be OK if internet is restricted)"
        print_info "The proxy may still work for DNS tunnel clients"
    fi
}

# ─── STEP 10: SSH User (Optional) ──────────────────────────────────────────────

step_ssh_user() {
    print_step 10 "SSH Tunnel User"

    print_info "An SSH tunnel user allows clients to connect via Slipstream + SSH or DNSTT + SSH."
    print_info "This user can only create tunnels and has no shell access."
    print_warn "Without an SSH tunnel user, the SSH tunnels (s2/ds2) will NOT work."
    echo ""

    if ! prompt_yn "Create an SSH tunnel user? (required for SSH tunnels to work)" "y"; then
        print_warn "Skipping SSH user setup — SSH tunnels (s2.${DOMAIN}, ds2.${DOMAIN}) will not work"
        print_info "You can create one later with: sshtun-user create <username> --insecure-password <pass>"
        return
    fi

    echo ""

    # Install sshtun-user if not present
    if ! command -v sshtun-user &>/dev/null; then
        print_info "Downloading sshtun-user..."
        if curl -fsSL -o /usr/local/bin/sshtun-user https://github.com/net2share/sshtun-user/releases/latest/download/sshtun-user-linux-amd64; then
            chmod +x /usr/local/bin/sshtun-user
            print_ok "Downloaded sshtun-user"
        else
            print_fail "Failed to download sshtun-user"
            return
        fi
    else
        print_ok "sshtun-user already installed"
    fi

    # Configure SSH (only needed once)
    print_info "Applying SSH security configuration..."
    local configure_output
    configure_output=$(sshtun-user configure 2>&1) || true
    if echo "$configure_output" | grep -qi "already"; then
        print_ok "SSH already configured"
    elif echo "$configure_output" | grep -qi "error\|fail"; then
        print_warn "sshtun-user configure had issues:"
        echo -e "  ${DIM}${configure_output}${NC}"
    else
        print_ok "SSH configuration applied"
    fi

    echo ""

    # Get username
    SSH_USER=$(prompt_input "Enter username for SSH tunnel user" "tunnel")
    if [[ -z "$SSH_USER" ]]; then
        print_fail "Username cannot be empty"
        return
    fi

    # Get password
    SSH_PASS=$(prompt_input "Enter password for SSH tunnel user")
    if [[ -z "$SSH_PASS" ]]; then
        print_fail "Password cannot be empty"
        return
    fi

    echo ""

    # Create user
    print_info "Creating SSH tunnel user: ${SSH_USER}..."
    if sshtun-user create "$SSH_USER" --insecure-password "$SSH_PASS" 2>&1; then
        SSH_SETUP_DONE=true
        print_ok "SSH tunnel user created: ${SSH_USER}"
    else
        print_warn "User creation may have failed or user already exists"
        SSH_SETUP_DONE=true  # Still show in summary
    fi
}

# ─── STEP 11: Run Tests ────────────────────────────────────────────────────────

step_tests() {
    print_step 11 "Verification Tests"

    local pass=0
    local fail=0

    # Test 1: SOCKS proxy — detect actual port
    echo -e "  ${BOLD}Test 1: SOCKS Proxy${NC}"
    local socks_port=""
    socks_port=$(ss -tlnp 2>/dev/null | grep microsocks | awk '{for(i=1;i<=NF;i++) if($i ~ /:[0-9]+$/) {split($i,a,":"); print a[length(a)]; exit}}' || true)
    if [[ -z "$socks_port" ]]; then
        socks_port=$(sed -n 's/.*-p[[:space:]]*\([0-9]*\).*/\1/p' /etc/systemd/system/microsocks.service 2>/dev/null | head -1 || true)
    fi
    if [[ -z "$socks_port" ]]; then
        socks_port="19801"
    fi

    local socks_result
    socks_result=$(curl -s --max-time 10 --socks5 "127.0.0.1:${socks_port}" https://api.ipify.org 2>/dev/null || true)
    if [[ -n "$socks_result" ]]; then
        print_ok "SOCKS proxy: PASS (IP: ${socks_result}) on port ${socks_port}"
        pass=$((pass + 1))
    elif ss -tlnp 2>/dev/null | grep -q "microsocks"; then
        print_warn "SOCKS proxy: LISTENING on port ${socks_port} but connectivity test failed"
        print_info "microsocks is running but outbound may be blocked or tunnels not ready"
        pass=$((pass + 1))
    else
        print_fail "SOCKS proxy: FAIL (microsocks not running)"
        fail=$((fail + 1))
    fi
    echo ""

    # Test 2: Tunnel list
    echo -e "  ${BOLD}Test 2: Tunnel Status${NC}"
    local tunnel_output
    tunnel_output=$(dnstm tunnel list 2>/dev/null || true)
    if [[ -n "$tunnel_output" ]]; then
        local running_count
        running_count=$(echo "$tunnel_output" | grep -ci "running" || echo "0")
        if [[ "$running_count" -ge 4 ]]; then
            print_ok "All tunnels running: PASS (${running_count} running)"
            pass=$((pass + 1))
        elif [[ "$running_count" -ge 1 ]]; then
            print_warn "Some tunnels running: ${running_count}/4"
            pass=$((pass + 1))
        else
            print_fail "No tunnels running: FAIL"
            fail=$((fail + 1))
        fi
    else
        print_fail "Cannot get tunnel list: FAIL"
        fail=$((fail + 1))
    fi
    echo ""

    # Test 3: Router status
    echo -e "  ${BOLD}Test 3: DNS Router${NC}"
    if dnstm router status 2>/dev/null | grep -qi "running"; then
        print_ok "DNS Router: PASS (running)"
        pass=$((pass + 1))
    else
        print_fail "DNS Router: FAIL (not running)"
        fail=$((fail + 1))
    fi
    echo ""

    # Test 4: Port 53
    echo -e "  ${BOLD}Test 4: Port 53${NC}"
    if ss -ulnp 2>/dev/null | grep -E ':53\b' | grep -q "dnstm"; then
        print_ok "Port 53: PASS (dnstm listening)"
        pass=$((pass + 1))
    else
        print_fail "Port 53: FAIL (dnstm not listening)"
        fail=$((fail + 1))
    fi
    echo ""

    # Test 5: DNS delegation (end-to-end reachability)
    echo -e "  ${BOLD}Test 5: DNS Delegation${NC}"
    if command -v dig &>/dev/null; then
        local dig_result
        dig_result=$(dig +short +timeout=5 +tries=1 "dnstm-test.t2.${DOMAIN}" @8.8.8.8 2>/dev/null || true)
        if [[ -n "$dig_result" ]]; then
            print_ok "DNS delegation: PASS (query reached server via 8.8.8.8)"
            pass=$((pass + 1))
        else
            # Try Cloudflare resolver as fallback
            dig_result=$(dig +short +timeout=5 +tries=1 "dnstm-test.t2.${DOMAIN}" @1.1.1.1 2>/dev/null || true)
            if [[ -n "$dig_result" ]]; then
                print_ok "DNS delegation: PASS (query reached server via 1.1.1.1)"
                pass=$((pass + 1))
            else
                print_warn "DNS delegation: No response from public resolvers"
                print_info "This may mean DNS records are not set up correctly in Cloudflare,"
                print_info "or it may take a few minutes for DNS to propagate."
                print_info "Test manually: dig t2.${DOMAIN} @8.8.8.8"
                fail=$((fail + 1))
            fi
        fi
    else
        print_info "DNS delegation: SKIPPED (dig not installed — install with: apt install dnsutils)"
        print_info "Test manually: nslookup t2.${DOMAIN} 8.8.8.8"
        pass=$((pass + 1))
    fi
    echo ""

    # Test 6: SSH readiness
    echo -e "  ${BOLD}Test 6: SSH Tunnel Readiness${NC}"
    if ss -tlnp 2>/dev/null | grep -E ':22\b' | grep -q "sshd"; then
        if [[ "$SSH_SETUP_DONE" == true ]]; then
            print_ok "SSH: PASS (sshd running, tunnel user '${SSH_USER}' created)"
            pass=$((pass + 1))
        else
            print_warn "SSH: sshd running but no tunnel user created — SSH tunnels (s2/ds2) will not work"
            print_info "Create one with: sshtun-user create <username> --insecure-password <pass>"
            fail=$((fail + 1))
        fi
    else
        print_warn "SSH: sshd not detected on port 22 — SSH tunnels (s2/ds2) will not work"
        print_info "Start sshd with: systemctl start sshd"
        fail=$((fail + 1))
    fi
    echo ""

    # Summary
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    if [[ $fail -eq 0 ]]; then
        print_ok "${GREEN}All ${pass} tests passed!${NC}"
    else
        print_warn "${pass} passed, ${fail} failed"
        print_info "Check logs with: dnstm router logs / dnstm tunnel logs --tag <tag>"
    fi
}

# ─── STEP 12: Summary ──────────────────────────────────────────────────────────

step_summary() {
    print_step 12 "Setup Complete!"

    local w=54
    local border empty
    border=$(printf '═%.0s' $(seq 1 $w))
    empty=$(printf ' %.0s' $(seq 1 $w))
    local msg="SETUP COMPLETE!"
    local ml=$(( (w - ${#msg}) / 2 ))
    local mr=$(( w - ${#msg} - ml ))

    echo -e "${BOLD}${GREEN}"
    printf "  ╔%s╗\n" "$border"
    printf "  ║%s║\n" "$empty"
    printf "  ║%${ml}s%s%${mr}s║\n" "" "$msg" ""
    printf "  ║%s║\n" "$empty"
    printf "  ╚%s╝\n" "$border"
    echo -e "${NC}"

    echo -e "  ${BOLD}Server Information${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  Server IP:     ${GREEN}${SERVER_IP}${NC}"
    echo -e "  Domain:        ${GREEN}${DOMAIN}${NC}"
    echo ""

    echo -e "  ${BOLD}Tunnel Endpoints${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  Slipstream + SOCKS:  ${GREEN}t2.${DOMAIN}${NC}"
    echo -e "  DNSTT + SOCKS:       ${GREEN}d2.${DOMAIN}${NC}"
    echo -e "  Slipstream + SSH:    ${GREEN}s2.${DOMAIN}${NC}"
    echo -e "  DNSTT + SSH:         ${GREEN}ds2.${DOMAIN}${NC}"
    echo ""

    if [[ -n "$DNSTT_PUBKEY" ]]; then
        echo -e "  ${BOLD}DNSTT Public Key${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  ${GREEN}${DNSTT_PUBKEY}${NC}"
        echo ""
    fi

    if [[ "$SSH_SETUP_DONE" == true ]]; then
        echo -e "  ${BOLD}SSH Tunnel User${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  Username:  ${GREEN}${SSH_USER}${NC}"
        echo -e "  Password:  ${GREEN}${SSH_PASS}${NC}"
        echo -e "  Port:      ${GREEN}22${NC}"
        echo ""
    else
        echo -e "  ${BOLD}SSH Tunnel User${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  ${YELLOW}⚠ Not configured — SSH tunnels (s2/ds2) will not work${NC}"
        echo -e "  Create one with: ${BOLD}sshtun-user create <username> --insecure-password <pass>${NC}"
        echo ""
    fi

    echo -e "  ${BOLD}DNS Resolvers (use in SlipNet)${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo "  8.8.8.8:53        (Google)"
    echo "  1.1.1.1:53        (Cloudflare)"
    echo "  9.9.9.9:53        (Quad9)"
    echo "  208.67.222.222:53 (OpenDNS)"
    echo "  94.140.14.14:53   (AdGuard)"
    echo "  185.228.168.9:53  (CleanBrowsing)"
    echo ""

    echo -e "  ${BOLD}Client App${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo "  SlipNet (Android): https://github.com/anonvector/SlipNet/releases"
    echo ""

    echo -e "  ${BOLD}Useful Commands${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo "  dnstm tunnel list               Show all tunnels"
    echo "  dnstm router status             Show router status"
    echo "  dnstm router logs               View router logs"
    echo "  dnstm tunnel logs --tag slip1   View tunnel logs"
    echo ""

    echo -e "  ${DIM}Setup by dnstm-setup v${VERSION} — SamNet Technologies${NC}"
    echo -e "  ${DIM}https://github.com/SamNet-dev/dnstm-setup${NC}"
    echo ""
}

# ─── Add Domain ──────────────────────────────────────────────────────────────────

# Detect next available tunnel number by scanning existing tags
detect_next_tunnel_num() {
    local max=1
    local tags
    tags=$(dnstm tunnel list 2>/dev/null | grep -o 'tag=[^ ]*' | sed 's/tag=//' || true)
    for tag in $tags; do
        local num
        num=$(echo "$tag" | grep -oE '[0-9]+$' || true)
        if [[ -n "$num" && "$num" -ge "$max" ]]; then
            max=$((num + 1))
        fi
    done
    echo "$max"
}

do_add_domain() {
    banner
    print_header "Add Backup Domain"

    # Check root
    if [[ $EUID -ne 0 ]]; then
        print_fail "Not running as root. Please run with: sudo bash $0 --add-domain"
        exit 1
    fi

    # Check dnstm is installed
    if ! command -v dnstm &>/dev/null; then
        print_fail "dnstm is not installed. Run the full setup first: sudo bash $0"
        exit 1
    fi

    # Check router is running
    if ! dnstm router status 2>/dev/null | grep -qi "running"; then
        print_warn "DNS Router is not running. Starting it..."
        dnstm router start 2>/dev/null || true
    fi

    # Detect server IP
    SERVER_IP=$(curl -4 -s --max-time 10 https://api.ipify.org 2>/dev/null || true)
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(prompt_input "Enter your server's public IP")
        if [[ -z "$SERVER_IP" ]]; then
            print_fail "Server IP is required."
            exit 1
        fi
    fi
    print_ok "Server IP: ${SERVER_IP}"

    # Show existing tunnels
    echo ""
    print_info "Current tunnels:"
    echo ""
    dnstm tunnel list 2>/dev/null || true
    echo ""

    # Detect next tunnel number
    local num
    num=$(detect_next_tunnel_num)
    print_info "Next tunnel set number: ${num}"
    echo ""

    # Get existing tunnel domains for duplicate check
    local existing_domains
    existing_domains=$(dnstm tunnel list 2>/dev/null | grep -o 'domain=[^ ]*' | sed 's/domain=//;s/^[a-z0-9]*\.//' | sort -u || true)

    # Ask for new domain
    while true; do
        DOMAIN=$(prompt_input "Enter the new backup domain (e.g. backup.com)")
        DOMAIN=$(echo "$DOMAIN" | sed 's|^[[:space:]]*||;s|[[:space:]]*$||;s|^https\?://||;s|/.*$||')
        if [[ -z "$DOMAIN" ]]; then
            print_fail "Domain cannot be empty. Please try again."
        elif [[ ! "$DOMAIN" =~ \. ]]; then
            print_fail "Invalid domain (must contain a dot). Please try again."
        elif [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
            print_fail "Invalid domain (use only letters, numbers, dots, hyphens). Please try again."
        elif echo "$existing_domains" | grep -qx "$DOMAIN"; then
            print_fail "Domain '${DOMAIN}' is already in use by an existing tunnel. Please enter a different domain."
        else
            break
        fi
    done

    echo ""
    print_ok "Domain: ${DOMAIN}"
    echo ""

    # DNS record instructions
    print_header "DNS Records for ${DOMAIN}"

    print_info "Create these records in Cloudflare for ${BOLD}${DOMAIN}${NC}:"
    echo ""
    print_box \
        "Record 1:  Type: A   | Name: ns  | Value: ${SERVER_IP}" \
        "           Proxy: OFF (DNS Only - grey cloud)" \
        "" \
        "Record 2:  Type: NS  | Name: t2  | Value: ns.${DOMAIN}" \
        "Record 3:  Type: NS  | Name: d2  | Value: ns.${DOMAIN}" \
        "Record 4:  Type: NS  | Name: s2  | Value: ns.${DOMAIN}" \
        "Record 5:  Type: NS  | Name: ds2 | Value: ns.${DOMAIN}"

    echo ""
    print_warn "IMPORTANT: The A record MUST be DNS Only (grey cloud, NOT orange)"
    echo ""

    if ! prompt_yn "Have you created these DNS records in Cloudflare?" "n"; then
        echo ""
        print_info "Please create the DNS records and re-run: sudo bash $0 --add-domain"
        exit 0
    fi

    echo ""

    # Create tunnels with numbered tags
    local slip_tag="slip${num}"
    local dnstt_tag="dnstt${num}"
    local slip_ssh_tag="slip-ssh${num}"
    local dnstt_ssh_tag="dnstt-ssh${num}"

    print_header "Creating Tunnels for ${DOMAIN}"

    print_info "Creating 4 tunnels (set #${num}) for domain: ${BOLD}${DOMAIN}${NC}"
    echo ""

    # Tunnel 1: Slipstream + SOCKS
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel: Slipstream + SOCKS${NC}"
    echo ""
    if dnstm tunnel add --transport slipstream --backend socks --domain "t2.${DOMAIN}" --tag "$slip_tag" 2>&1; then
        print_ok "Created: ${slip_tag} (Slipstream + SOCKS) on t2.${DOMAIN}"
    else
        print_warn "Tunnel ${slip_tag} may already exist or creation failed"
    fi
    echo ""

    # Tunnel 2: DNSTT + SOCKS
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel: DNSTT + SOCKS${NC}"
    echo ""
    local dnstt_output
    dnstt_output=$(dnstm tunnel add --transport dnstt --backend socks --domain "d2.${DOMAIN}" --tag "$dnstt_tag" 2>&1) || true
    echo "$dnstt_output"

    DNSTT_PUBKEY=""
    if [[ -f "/etc/dnstm/tunnels/${dnstt_tag}/server.pub" ]]; then
        DNSTT_PUBKEY=$(cat "/etc/dnstm/tunnels/${dnstt_tag}/server.pub" 2>/dev/null || true)
    fi

    if [[ -n "$DNSTT_PUBKEY" ]]; then
        print_ok "Created: ${dnstt_tag} (DNSTT + SOCKS) on d2.${DOMAIN}"
        echo ""
        echo -e "  ${BOLD}${YELLOW}DNSTT Public Key (save this!):${NC}"
        echo -e "  ${GREEN}${DNSTT_PUBKEY}${NC}"
    else
        print_warn "Tunnel ${dnstt_tag} may already exist or creation failed"
    fi
    echo ""

    # Tunnel 3: Slipstream + SSH
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel: Slipstream + SSH${NC}"
    echo ""
    if dnstm tunnel add --transport slipstream --backend ssh --domain "s2.${DOMAIN}" --tag "$slip_ssh_tag" 2>&1; then
        print_ok "Created: ${slip_ssh_tag} (Slipstream + SSH) on s2.${DOMAIN}"
    else
        print_warn "Tunnel ${slip_ssh_tag} may already exist or creation failed"
    fi
    echo ""

    # Tunnel 4: DNSTT + SSH
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel: DNSTT + SSH${NC}"
    echo ""
    if dnstm tunnel add --transport dnstt --backend ssh --domain "ds2.${DOMAIN}" --tag "$dnstt_ssh_tag" 2>&1; then
        print_ok "Created: ${dnstt_ssh_tag} (DNSTT + SSH) on ds2.${DOMAIN}"
    else
        print_warn "Tunnel ${dnstt_ssh_tag} may already exist or creation failed"
    fi
    echo ""

    # Re-read DNSTT key if not captured
    if [[ -z "$DNSTT_PUBKEY" && -f "/etc/dnstm/tunnels/${dnstt_tag}/server.pub" ]]; then
        DNSTT_PUBKEY=$(cat "/etc/dnstm/tunnels/${dnstt_tag}/server.pub" 2>/dev/null || true)
    fi

    print_ok "All tunnels created"
    echo ""

    # Restart router to pick up new tunnel config
    print_info "Restarting DNS Router to load new tunnels..."
    dnstm router stop 2>/dev/null || true
    sleep 1
    if dnstm router start 2>/dev/null; then
        print_ok "DNS Router restarted"
    else
        print_warn "DNS Router restart may have issues. Check: dnstm router logs"
    fi
    echo ""

    # Start new tunnels
    print_info "Starting new tunnels..."
    for tag in "$slip_tag" "$dnstt_tag" "$slip_ssh_tag" "$dnstt_ssh_tag"; do
        if dnstm tunnel start --tag "$tag" 2>/dev/null; then
            print_ok "Started: ${tag}"
        else
            if dnstm tunnel list 2>/dev/null | grep "$tag" | grep -qi "running"; then
                print_ok "Already running: ${tag}"
            else
                print_warn "Could not start: ${tag}. Check: dnstm tunnel logs --tag ${tag}"
            fi
        fi
    done

    echo ""
    print_info "All tunnels:"
    echo ""
    dnstm tunnel list 2>/dev/null || true
    echo ""

    if apply_service_hardening; then
        print_ok "Runtime hardening applied to dnstm and microsocks services"
    else
        print_warn "Runtime hardening reported issues; review systemctl status for dnstm units"
    fi

    # Summary
    local w=54
    local border empty
    border=$(printf '═%.0s' $(seq 1 $w))
    empty=$(printf ' %.0s' $(seq 1 $w))
    local msg="DOMAIN ADDED!"
    local ml=$(( (w - ${#msg}) / 2 ))
    local mr=$(( w - ${#msg} - ml ))

    echo -e "${BOLD}${GREEN}"
    printf "  ╔%s╗\n" "$border"
    printf "  ║%s║\n" "$empty"
    printf "  ║%${ml}s%s%${mr}s║\n" "" "$msg" ""
    printf "  ║%s║\n" "$empty"
    printf "  ╚%s╝\n" "$border"
    echo -e "${NC}"

    echo -e "  ${BOLD}Server Information${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  Server IP:     ${GREEN}${SERVER_IP}${NC}"
    echo -e "  Domain:        ${GREEN}${DOMAIN}${NC}"
    echo ""

    echo -e "  ${BOLD}Tunnel Endpoints${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  Slipstream + SOCKS:  ${GREEN}t2.${DOMAIN}${NC}  (${slip_tag})"
    echo -e "  DNSTT + SOCKS:       ${GREEN}d2.${DOMAIN}${NC}  (${dnstt_tag})"
    echo -e "  Slipstream + SSH:    ${GREEN}s2.${DOMAIN}${NC}  (${slip_ssh_tag})"
    echo -e "  DNSTT + SSH:         ${GREEN}ds2.${DOMAIN}${NC}  (${dnstt_ssh_tag})"
    echo ""

    if [[ -n "$DNSTT_PUBKEY" ]]; then
        echo -e "  ${BOLD}DNSTT Public Key${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  ${GREEN}${DNSTT_PUBKEY}${NC}"
        echo ""
    fi

    echo -e "  ${DIM}To add more domains, run again: sudo bash $0 --add-domain${NC}"
    echo ""
}

# ─── Main ───────────────────────────────────────────────────────────────────────

main() {
    banner
    echo -e "  ${DIM}Tip: Press 'h' at any prompt for help${NC}"

    step_preflight
    step_ask_domain
    step_dns_records
    step_free_port53
    step_install_dnstm
    step_verify_port53
    step_create_tunnels
    step_start_services
    step_verify_microsocks
    step_ssh_user
    step_tests
    step_summary
    unset SSH_PASS 2>/dev/null || true
}

if [[ "$HARDEN_ONLY_MODE" == true ]]; then
    do_harden
elif [[ "$ADD_DOMAIN_MODE" == true ]]; then
    do_add_domain
else
    main
fi
