#!/usr/bin/env bash
#
# dnstm-setup v1.3
# Interactive DNS Tunnel Setup
# Sets up Slipstream + DNSTT + NoizDNS tunnels for censorship-resistant internet access
#
# Made By SamNet Technologies - Saman
# GitHub: github.com/SamNet-dev/dnstm-setup
# License: MIT

set -euo pipefail

VERSION="1.3"
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
        read -r answer </dev/tty 2>/dev/null || read -r answer
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
        read -r result </dev/tty 2>/dev/null || read -r result
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
    read -r </dev/tty 2>/dev/null || read -r || true
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
    echo "  When you create NS records pointing t.example.com to"
    echo "  ns.example.com (your server), you tell the global DNS"
    echo "  system: 'For any query about t.example.com, ask my"
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
    echo "    t.example.com   ->  Slipstream + SOCKS tunnel"
    echo "    d.example.com   ->  DNSTT + SOCKS tunnel"
    echo "    s.example.com   ->  Slipstream + SSH tunnel"
    echo "    ds.example.com  ->  DNSTT + SSH tunnel"
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
    echo "  We create:  t.yourdomain.com NS -> ns.yourdomain.com"
    echo "  This tells the internet: 'For queries about t, ask"
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
    echo "    t   -> Slipstream + SOCKS  (fastest, QUIC-based)"
    echo "    d   -> DNSTT + SOCKS       (classic, Noise protocol)"
    echo "    s   -> Slipstream + SSH    (SSH over DNS)"
    echo "    ds  -> DNSTT + SSH         (SSH over DNSTT)"
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
    echo "  the domain name: if it's for t.example.com, it sends"
    echo "  the query to Slipstream. If it's for d.example.com,"
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
    echo "  SOCKS (t/d tunnels):"
    echo "    - Faster, no authentication needed"
    echo "    - Anyone who knows the domain can connect"
    echo "  SSH (s/ds tunnels):"
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
    echo "    DNS Router --+--> t   --> Slipstream --+--> microsocks"
    echo "                 +--> d   --> DNSTT -------+    (SOCKS5)"
    echo "                 +--> s   --> Slip+SSH ----+       |"
    echo "                 +--> ds  --> DNSTT+SSH ---+       v"
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
    echo "  sudo bash dnstm-setup.sh --manage      Post-setup management menu"
    echo "  sudo bash dnstm-setup.sh --add-domain  Add a backup domain to existing setup"
    echo "  sudo bash dnstm-setup.sh --mtu 1200    Set DNSTT MTU (default: 1232)"
    echo "  sudo bash dnstm-setup.sh --add-tunnel   Add a single tunnel interactively"
    echo "  sudo bash dnstm-setup.sh --add-xray    Connect existing Xray panel via DNS tunnel"
    echo "  sudo bash dnstm-setup.sh --remove-tunnel [tag]  Remove a specific tunnel"
    echo "  sudo bash dnstm-setup.sh --harden      Apply security hardening only"
    echo "  sudo bash dnstm-setup.sh --uninstall   Remove everything"
    echo "  sudo bash dnstm-setup.sh --status      Show all tunnels & share URLs"
    echo "  bash dnstm-setup.sh --help             Show this help"
    echo "  bash dnstm-setup.sh --about            Show project info"
    echo ""
    echo -e "${BOLD}FLAGS${NC}"
    echo "  --help         Show this help message"
    echo "  --about        Show project information and credits"
    echo "  --manage       Interactive management menu (all post-setup actions)"
    echo "  --status       Show all tunnels, credentials, and share URLs"
    echo "  --add-tunnel   Add a single tunnel (interactive: choose transport, backend, domain)"
    echo "  --add-xray     Connect existing 3x-ui panel to DNS tunnel (auto-detect + create inbound)"
    echo "  --remove-tunnel [tag]  Remove a specific tunnel (interactive if no tag given)"
    echo "  --add-domain   Add another domain to an existing server (backup/fallback)"
    echo "  --users        Manage SSH tunnel users (add, list, update, delete)"
    echo "  --mtu <value>  Set DNSTT MTU size (512-1400, default: 1232)"
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

# ─── SOCKS Auth Detection Helper ──────────────────────────────────────────────

# Detect SOCKS5 auth state from dnstm backend status.
# Sets globals: SOCKS_AUTH (true/false), SOCKS_USER, SOCKS_PASS
# Returns 0 if auth is enabled, 1 otherwise.
detect_socks_auth() {
    local status_output
    status_output=$(dnstm backend status -t socks 2>/dev/null || true)
    local detected_user detected_pass
    detected_user=$(echo "$status_output" | sed -n 's/^[[:space:]]*User:[[:space:]]*//p' | sed 's/[[:space:]]*$//' || true)
    detected_pass=$(echo "$status_output" | sed -n 's/^[[:space:]]*Password:[[:space:]]*//p' | sed 's/[[:space:]]*$//' || true)
    if [[ -n "$detected_user" && -n "$detected_pass" ]]; then
        # Reject credentials with pipe chars (would corrupt slipnet URL format)
        if [[ "$detected_user" == *"|"* || "$detected_pass" == *"|"* ]]; then
            SOCKS_AUTH=false
            SOCKS_USER=""
            SOCKS_PASS=""
            return 1
        fi
        SOCKS_AUTH=true
        SOCKS_USER="$detected_user"
        SOCKS_PASS="$detected_pass"
        return 0
    fi
    SOCKS_AUTH=false
    SOCKS_USER=""
    SOCKS_PASS=""
    return 1
}

# ─── Configure SOCKS Auth (manage menu) ──────────────────────────────────────

do_configure_socks_auth() {
    banner
    print_header "Configure SOCKS5 Authentication"

    if [[ $EUID -ne 0 ]]; then
        print_fail "Not running as root."
        exit 1
    fi

    if ! command -v dnstm &>/dev/null; then
        print_fail "dnstm is not installed."
        exit 1
    fi

    # Show current state
    echo ""
    detect_socks_auth || true
    if [[ "$SOCKS_AUTH" == true ]]; then
        echo -e "  ${BOLD}Current status:${NC} ${GREEN}Enabled${NC}"
        echo -e "  ${DIM}Username: ${SOCKS_USER}${NC}"
        echo ""
        echo -e "  ${BOLD}1)${NC}  Change credentials"
        echo -e "  ${BOLD}2)${NC}  Disable authentication"
        echo -e "  ${BOLD}0)${NC}  Cancel"
        echo ""
        local choice=""
        read -rp "  Select [0-2]: " choice || exit 0
        case "$choice" in
            1)
                echo ""
                ;;
            2)
                echo ""
                print_info "Disabling SOCKS5 authentication..."
                if dnstm backend auth -t socks --disable; then
                    print_ok "SOCKS5 authentication disabled"
                    sleep 2
                    if pgrep -x microsocks &>/dev/null || systemctl is-active --quiet microsocks 2>/dev/null; then
                        print_ok "microsocks restarted without authentication"
                    else
                        print_warn "microsocks may not have restarted — check: systemctl status microsocks"
                    fi
                else
                    print_fail "Failed to disable authentication"
                fi
                exit 0
                ;;
            *)
                exit 0
                ;;
        esac
    else
        echo -e "  ${BOLD}Current status:${NC} ${RED}Disabled (open proxy)${NC}"
        echo ""
        if ! prompt_yn "Enable SOCKS5 authentication?" "y"; then
            print_info "Cancelled."
            exit 0
        fi
        echo ""
    fi

    # Collect credentials
    local new_user new_pass
    new_user=$(prompt_input "Enter SOCKS proxy username" "proxy")
    new_user=$(echo "$new_user" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -z "$new_user" ]]; then
        print_fail "Username cannot be empty"
        exit 1
    fi
    if [[ "$new_user" == *"|"* || "$new_user" == *":"* ]]; then
        print_fail "Username cannot contain | or : characters"
        exit 1
    fi

    new_pass=$(prompt_input "Enter SOCKS proxy password")
    new_pass=$(echo "$new_pass" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -z "$new_pass" ]]; then
        print_fail "Password cannot be empty"
        exit 1
    fi
    if [[ "$new_pass" == *"|"* ]]; then
        print_fail "Password cannot contain the | character"
        exit 1
    fi

    echo ""
    print_info "Applying SOCKS5 authentication..."
    if dnstm backend auth -t socks -u "$new_user" -p "$new_pass"; then
        print_ok "SOCKS5 authentication enabled (user: ${new_user})"
        sleep 2
        if pgrep -x microsocks &>/dev/null || systemctl is-active --quiet microsocks 2>/dev/null; then
            print_ok "microsocks restarted with authentication"
        else
            print_warn "microsocks may not have restarted — check: systemctl status microsocks"
        fi

        # Verify auth enforcement
        local socks_port=""
        socks_port=$(ss -tlnp 2>/dev/null | grep microsocks | awk '{for(i=1;i<=NF;i++) if($i ~ /:[0-9]+$/) {split($i,a,":"); print a[length(a)]; exit}}' || true)
        if [[ -z "$socks_port" ]]; then
            socks_port="19801"
        fi
        local noauth_test
        noauth_test=$(curl -s --max-time 5 --socks5 "127.0.0.1:${socks_port}" https://api.ipify.org 2>/dev/null || true)
        if [[ -z "$noauth_test" ]]; then
            print_ok "Auth enforced: unauthenticated connections are rejected"
        else
            print_warn "Auth NOT enforced: proxy still works without credentials!"
            print_info "Try restarting: systemctl restart microsocks"
        fi
    else
        print_fail "Failed to configure SOCKS5 authentication"
        print_info "Try manually: dnstm backend auth -t socks -u ${new_user} -p <password>"
    fi
}

# ─── --status ───────────────────────────────────────────────────────────────────

do_status() {
    banner

    # Warn if not root (ss -p and file reads may not work)
    if [[ $EUID -ne 0 ]]; then
        print_warn "Running without root — some info may be unavailable"
        echo ""
    fi

    # Check dnstm is installed
    if ! command -v dnstm &>/dev/null; then
        print_fail "dnstm is not installed. Run the full setup first: sudo bash $0"
        exit 1
    fi

    # Save/restore global DOMAIN so generate_slipnet_url() can read it
    local _saved_domain="$DOMAIN"

    # Detect server IP
    local server_ip
    server_ip=$(curl -4 -s --max-time 10 https://api.ipify.org 2>/dev/null || true)
    if [[ -n "$server_ip" ]]; then
        echo -e "  ${BOLD}Server IP:${NC} ${GREEN}${server_ip}${NC}"
    fi
    echo ""

    # ─── Cache tunnel list output (reused throughout) ───
    local tunnel_list_output
    tunnel_list_output=$(dnstm tunnel list 2>/dev/null || true)

    echo -e "  ${BOLD}Tunnel Status${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    if [[ -n "$tunnel_list_output" ]]; then
        echo "$tunnel_list_output"
    else
        print_warn "Could not get tunnel list"
    fi
    echo ""

    # ─── Detect SOCKS auth via dnstm ───
    detect_socks_auth || true
    local socks_user="$SOCKS_USER" socks_pass="$SOCKS_PASS" socks_auth="$SOCKS_AUTH"

    echo -e "  ${BOLD}SOCKS Proxy Authentication${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    if [[ "$socks_auth" == true ]]; then
        echo -e "  Username:  ${GREEN}${socks_user}${NC}"
        echo -e "  Password:  ${GREEN}${socks_pass}${NC}"
    else
        echo -e "  ${YELLOW}No authentication (open proxy)${NC}"
    fi
    echo ""

    # ─── Detect microsocks port ───
    local socks_port=""
    socks_port=$(ss -tlnp 2>/dev/null | grep microsocks | awk '{for(i=1;i<=NF;i++) if($i ~ /:[0-9]+$/) {split($i,a,":"); print a[length(a)]; exit}}' || true)
    if [[ -z "$socks_port" ]]; then
        socks_port=$(sed -n 's/.*-p[[:space:]]*\([0-9]*\).*/\1/p' /etc/systemd/system/microsocks.service 2>/dev/null | head -1 || true)
    fi
    if [[ -n "$socks_port" ]]; then
        echo -e "  ${BOLD}microsocks Port:${NC} ${GREEN}${socks_port}${NC}"
        echo ""
    fi

    # ─── Collect all tunnel tags and their domains ───
    local tags
    tags=$(echo "$tunnel_list_output" | grep -o 'tag=[^ ]*' | sed 's/tag=//' || true)
    if [[ -z "$tags" ]]; then
        print_warn "No tunnels found"
        return
    fi

    # ─── Detect SSH users (check if sshtun-user is available) ───
    local ssh_user="" ssh_pass=""
    local has_ssh_users=false
    if command -v sshtun-user &>/dev/null; then
        local user_list
        user_list=$(timeout 10 sshtun-user list </dev/null 2>/dev/null || true)
        if [[ -n "$user_list" ]]; then
            has_ssh_users=true
            echo -e "  ${BOLD}SSH Tunnel Users${NC}"
            echo -e "  ${DIM}────────────────────────────────────────${NC}"
            echo "$user_list" | while IFS= read -r line; do
                echo -e "  ${GREEN}${line}${NC}"
            done
            echo ""
        fi
    fi

    # ─── Share URLs — dnst:// ───
    echo -e "  ${BOLD}Share URLs — dnst:// (for dnstc CLI)${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    local share_url
    for tag in $tags; do
        # SOCKS tunnels — no SSH credentials needed
        if echo "$tag" | grep -qE '^(slip[0-9]+|dnstt[0-9]+|noiz[0-9]+)$'; then
            share_url=$(dnstm tunnel share -t "$tag" 2>/dev/null || true)
            if [[ -n "$share_url" ]]; then
                echo -e "  ${GREEN}${tag}:${NC}"
                echo "  ${share_url}"
                echo ""
            fi
        fi
    done
    # SSH tunnels — need credentials
    local ssh_tags
    ssh_tags=$(echo "$tags" | grep -E 'ssh' || true)
    if [[ -n "$ssh_tags" ]]; then
        if [[ "$has_ssh_users" == true ]]; then
            echo -e "  ${DIM}SSH tunnel share URLs require credentials:${NC}"
            for tag in $ssh_tags; do
                echo -e "  ${DIM}  dnstm tunnel share -t ${tag} --user <username> --password <pass>${NC}"
            done
        else
            echo -e "  ${YELLOW}SSH tunnels: no users configured — create one with: sshtun-user create <user> --insecure-password <pass>${NC}"
        fi
        echo ""
    fi

    # ─── Share URLs — slipnet:// ───
    # We need the domain for each tunnel to generate slipnet:// URLs
    echo -e "  ${BOLD}Share URLs — slipnet:// (for SlipNet app)${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"

    local s_user="" s_pass=""
    if [[ "$socks_auth" == true ]]; then
        s_user="$socks_user"
        s_pass="$socks_pass"
    fi

    for tag in $tags; do
        # Extract domain for this tunnel from dnstm
        local tag_domain
        tag_domain=$(echo "$tunnel_list_output" | awk -v t="tag=${tag}" '{for(i=1;i<=NF;i++) if($i==t){print;next}}' | grep -o 'domain=[^ ]*' | sed 's/domain=//' || true)
        if [[ -z "$tag_domain" ]]; then
            continue
        fi

        # Extract base domain (strip subdomain prefix)
        DOMAIN=$(echo "$tag_domain" | sed 's/^[^.]*\.//')
        local subdomain
        subdomain=$(echo "$tag_domain" | sed 's/\..*//')

        # Get DNSTT pubkey if it's a dnstt or xray tunnel (both use DNSTT transport)
        local pubkey=""
        if echo "$tag" | grep -qE "^(dnstt|xray|noiz)"; then
            if [[ -f "/etc/dnstm/tunnels/${tag}/server.pub" ]]; then
                pubkey=$(cat "/etc/dnstm/tunnels/${tag}/server.pub" 2>/dev/null || true)
            fi
        fi

        local url=""
        case "$tag" in
            slip[0-9]*)
                url=$(generate_slipnet_url "ss" "$subdomain" "" "" "" "$s_user" "$s_pass")
                ;;
            dnstt[0-9]*)
                if [[ -n "$pubkey" ]]; then
                    url=$(generate_slipnet_url "dnstt" "$subdomain" "$pubkey" "" "" "$s_user" "$s_pass")
                fi
                ;;
            slip-ssh*)
                echo -e "  ${DIM}${tag}: requires SSH credentials — generate after adding user${NC}"
                continue
                ;;
            dnstt-ssh*)
                echo -e "  ${DIM}${tag}: requires SSH credentials — generate after adding user${NC}"
                continue
                ;;
            xray*)
                if [[ -n "$pubkey" ]]; then
                    url=$(generate_slipnet_url "dnstt" "$subdomain" "$pubkey" "" "" "$s_user" "$s_pass")
                fi
                ;;
            noiz[0-9]*)
                if [[ -n "$pubkey" ]]; then
                    url=$(generate_slipnet_url "sayedns" "$subdomain" "$pubkey" "" "" "$s_user" "$s_pass")
                fi
                ;;
            noiz-ssh*)
                echo -e "  ${DIM}${tag}: requires SSH credentials — generate after adding user${NC}"
                continue
                ;;
        esac

        if [[ -n "$url" ]]; then
            echo -e "  ${GREEN}${tag}:${NC}"
            echo "  ${url}"
            echo ""
        fi
    done

    # ─── Xray Tunnel Info (if configured) ───
    if [[ -d /etc/dnstm/xray ]] && ls /etc/dnstm/xray/*.conf >/dev/null 2>&1; then
        echo -e "  ${BOLD}Xray Backend Tunnels${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        local xconf
        for xconf in /etc/dnstm/xray/*.conf; do
            local XRAY_TAG="" XRAY_PORT="" XRAY_PROTOCOL="" XRAY_UUID="" XRAY_PASSWORD="" XRAY_PANEL="" XRAY_DOMAIN=""
            # shellcheck disable=SC1090
            source "$xconf"
            echo -e "  Tag:       ${GREEN}${XRAY_TAG}${NC}"
            echo -e "  Protocol:  ${GREEN}${XRAY_PROTOCOL}${NC}"
            echo -e "  Domain:    ${GREEN}${XRAY_DOMAIN}${NC}"
            echo -e "  Port:      ${GREEN}${XRAY_PORT}${NC} ${DIM}(127.0.0.1)${NC}"
            echo -e "  Panel:     ${GREEN}${XRAY_PANEL}${NC}"

            # Generate client URI
            local xcred=""
            if [[ -n "$XRAY_UUID" ]]; then
                xcred="$XRAY_UUID"
            else
                xcred="$XRAY_PASSWORD"
            fi
            if [[ -n "$xcred" ]]; then
                # Use 127.0.0.1 — client connects through DNSTT tunnel, traffic exits on server localhost
                local xuri
                xuri=$(generate_xray_client_uri "$XRAY_PROTOCOL" "127.0.0.1" "$XRAY_PORT" "$xcred" "DNSTT-${XRAY_PROTOCOL}")
                echo -e "  URI:       ${GREEN}${xuri}${NC}"
            fi
            echo ""
        done
    fi

    echo -e "  ${BOLD}DNS Resolvers (use in SlipNet)${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo "  8.8.8.8:53        (Google)"
    echo "  1.1.1.1:53        (Cloudflare)"
    echo "  9.9.9.9:53        (Quad9)"
    echo "  208.67.222.222:53 (OpenDNS)"
    echo ""

    # Restore global DOMAIN
    DOMAIN="$_saved_domain"
}

# ─── SlipNet URL Generator ────────────────────────────────────────────────────

# Generate a slipnet:// deep-link URL for the SlipNet Android app.
# Usage: generate_slipnet_url <tunnel_type> <subdomain> [pubkey] [ssh_user] [ssh_pass] [socks_user] [socks_pass]
#   tunnel_type: "ss", "dnstt", "sayedns", "slipstream_ssh", "dnstt_ssh", or "sayedns_ssh" (SlipNet constants)
#   subdomain:   e.g. "t" or "d"
#   pubkey:      DNSTT public key (required for dnstt, empty for slipstream)
#   ssh_user:    SSH tunnel username (optional)
#   ssh_pass:    SSH tunnel password (optional)
generate_slipnet_url() {
    local tunnel_type="$1"
    local subdomain="$2"
    local pubkey="${3:-}"
    local ssh_user="${4:-}"
    local ssh_pass="${5:-}"
    local socks_user="${6:-}"
    local socks_pass="${7:-}"
    local name="${subdomain}.${DOMAIN}"
    local ns_domain="${subdomain}.${DOMAIN}"
    local resolver="8.8.8.8:53:0"
    local ssh_enabled="0" ssh_port="22" ssh_host="127.0.0.1"
    local auth_mode="0"

    if [[ -n "$ssh_user" && -n "$ssh_pass" ]]; then
        ssh_enabled="1"
    fi

    if [[ -n "$socks_user" && -n "$socks_pass" ]]; then
        auth_mode="1"
    fi

    # v16 pipe-delimited format (36 fields):
    # 1:version 2:tunnelType 3:name 4:domain 5:resolvers 6:authMode 7:keepAlive
    # 8:cc 9:port 10:host 11:gso 12:dnsttPublicKey 13:socksUser 14:socksPass
    # 15:sshEnabled 16:sshUser 17:sshPass 18:sshPort 19:fwdDns 20:sshHost
    # 21:useServerDns 22:dohUrl 23:dnsTransport 24:sshAuthType 25:sshPrivKey
    # 26:sshKeyPass 27:torBridges 28:dnsttAuthoritative 29:naivePort
    # 30:naiveUser 31:naivePass 32:isLocked 33:lockHash 34:expiration
    # 35:allowSharing 36:boundDeviceId
    local data="16|${tunnel_type}|${name}|${ns_domain}|${resolver}|${auth_mode}|5000|bbr|1080|127.0.0.1|0|${pubkey}|${socks_user}|${socks_pass}|${ssh_enabled}|${ssh_user}|${ssh_pass}|${ssh_port}|0|${ssh_host}|0||udp|password|||0|0|443|||0||0|0|"
    echo "slipnet://$(echo -n "$data" | base64 -w0)"
}

# ─── microsocks GLIBC Fix ─────────────────────────────────────────────────────

compile_microsocks_from_source() {
    # The pre-built microsocks binary shipped by dnstm requires GLIBC ≥ 2.38.
    # Older distros (Ubuntu 22.04 = GLIBC 2.35, Debian 11 = 2.31) will fail to
    # run it.  This function compiles microsocks from source as a fallback.
    print_info "Compiling microsocks from source (GLIBC compatibility fix)..."

    # Ensure build tools are available
    if ! command -v gcc &>/dev/null || ! command -v make &>/dev/null; then
        print_info "Installing build tools (gcc, make, git)..."
        dpkg --configure -a 2>/dev/null || true
        apt-get update -qq 2>/dev/null || true
        apt-get install -y -qq build-essential git 2>/dev/null || true
    fi

    if ! command -v gcc &>/dev/null; then
        print_fail "Cannot install gcc — microsocks will not work"
        return 1
    fi

    local build_dir="/tmp/microsocks-build-$$"
    rm -rf "$build_dir"

    if ! git clone --depth 1 https://github.com/rofl0r/microsocks.git "$build_dir" 2>/dev/null; then
        print_fail "Failed to clone microsocks source"
        rm -rf "$build_dir"
        return 1
    fi

    if ! make -C "$build_dir" 2>/dev/null; then
        print_fail "Failed to compile microsocks"
        rm -rf "$build_dir"
        return 1
    fi

    if [[ ! -f "$build_dir/microsocks" ]]; then
        print_fail "microsocks binary not produced"
        rm -rf "$build_dir"
        return 1
    fi

    # Replace the broken binary
    systemctl stop microsocks 2>/dev/null || true
    cp "$build_dir/microsocks" /usr/local/bin/microsocks
    chmod +x /usr/local/bin/microsocks
    rm -rf "$build_dir"

    # Restart service
    systemctl reset-failed microsocks 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    if systemctl start microsocks 2>/dev/null; then
        sleep 2
        if pgrep -x microsocks &>/dev/null; then
            print_ok "microsocks compiled from source and running"
            return 0
        fi
    fi

    print_fail "microsocks compiled but failed to start"
    return 1
}

# Check whether the microsocks binary can actually execute on this system.
# Returns 0 if it works, 1 if GLIBC or another loader error is detected.
microsocks_binary_works() {
    local bin="${1:-/usr/local/bin/microsocks}"
    [[ -x "$bin" ]] || return 1
    # Use ldd to check for missing shared library versions.  GLIBC mismatches
    # show "not found" in ldd output (e.g. "GLIBC_2.38 not found").
    if ldd "$bin" 2>&1 | grep -qi "not found"; then
        return 1
    fi
    return 0
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
        ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf || true
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

    systemctl daemon-reload 2>/dev/null || true

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
                systemctl daemon-reload 2>/dev/null || true
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

    if ! command -v dnstm &>/dev/null; then
        print_fail "dnstm is not installed. Run the setup first before hardening."
        exit 1
    fi

    configure_systemd_resolved_no_stub || true
    if apply_service_hardening; then
        print_ok "Runtime hardening applied"
    else
        print_warn "Runtime hardening reported issues; review systemctl status for dnstm units"
    fi

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

# ─── --remove-tunnel ─────────────────────────────────────────────────────────────

do_remove_tunnel() {
    local target_tag="$1"
    banner

    if [[ $EUID -ne 0 ]]; then
        echo -e "  ${CROSS} Not running as root. Please run with: sudo bash $0 --remove-tunnel <tag>"
        exit 1
    fi

    if ! command -v dnstm &>/dev/null; then
        print_fail "dnstm is not installed. Nothing to remove."
        exit 1
    fi

    # Cache tunnel list output (reused throughout)
    local tunnel_output
    tunnel_output=$(dnstm tunnel list 2>/dev/null || true)

    # Show current tunnels
    print_header "Remove Tunnel"
    echo ""
    print_info "Current tunnels:"
    echo ""
    echo "$tunnel_output"
    echo ""

    # If no tag given, ask interactively
    if [[ -z "$target_tag" ]]; then
        local tags
        tags=$(echo "$tunnel_output" | grep -o 'tag=[^ ]*' | sed 's/tag=//' || true)
        if [[ -z "$tags" ]]; then
            print_warn "No tunnels found."
            exit 0
        fi

        # Show numbered list
        local i=1
        local tag_arr=()
        for tag in $tags; do
            local domain_info
            domain_info=$(echo "$tunnel_output" | awk -v t="tag=${tag}" '{for(i=1;i<=NF;i++) if($i==t){print;next}}' | grep -o 'domain=[^ ]*' | sed 's/domain=//' || true)
            echo -e "  ${BOLD}${i})${NC}  ${tag}  ${DIM}(${domain_info})${NC}"
            tag_arr+=("$tag")
            i=$((i + 1))
        done
        echo -e "  ${BOLD}0)${NC}  Cancel"
        echo ""

        local choice
        choice=$(prompt_input "Select tunnel to remove (1-${#tag_arr[@]})")
        if [[ "$choice" == "0" || -z "$choice" ]]; then
            print_info "Cancelled."
            exit 0
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#tag_arr[@]} ]]; then
            target_tag="${tag_arr[$((choice - 1))]}"
        else
            print_fail "Invalid selection."
            exit 1
        fi
    fi

    # Verify tunnel exists
    if ! echo "$tunnel_output" | grep -o 'tag=[^ ]*' | grep -qxF "tag=${target_tag}"; then
        print_fail "Tunnel '${target_tag}' not found."
        echo ""
        print_info "Available tunnels:"
        echo "$tunnel_output" | grep -o 'tag=[^ ]*' | sed 's/tag=/  /' || true
        exit 1
    fi

    local domain_info
    domain_info=$(echo "$tunnel_output" | awk -v t="tag=${target_tag}" '{for(i=1;i<=NF;i++) if($i==t){print;next}}' | grep -o 'domain=[^ ]*' | sed 's/domain=//' || true)

    echo ""
    if ! prompt_yn "Remove tunnel '${target_tag}' (${domain_info})?" "n"; then
        print_info "Cancelled."
        exit 0
    fi

    echo ""

    # Stop the tunnel
    print_info "Stopping tunnel: ${target_tag}..."
    if dnstm tunnel stop --tag "$target_tag" 2>/dev/null; then
        print_ok "Stopped: ${target_tag}"
    else
        print_warn "Stop command failed (tunnel may already be stopped)"
    fi

    # Remove the tunnel
    print_info "Removing tunnel: ${target_tag}..."
    if dnstm tunnel remove --tag "$target_tag" 2>/dev/null; then
        print_ok "Removed: ${target_tag}"
    else
        print_warn "Remove command returned an error (tunnel may already be gone)"
    fi

    # Clean up Xray config and systemd drop-in if this was an xray tunnel
    if [[ "$target_tag" == xray* ]]; then
        rm -f "/etc/dnstm/xray/${target_tag}.conf" 2>/dev/null || true
        rm -f "/etc/systemd/system/dnstm-${target_tag}.service.d/10-xray-upstream.conf" 2>/dev/null || true
        rmdir "/etc/systemd/system/dnstm-${target_tag}.service.d" 2>/dev/null || true
        systemctl daemon-reload 2>/dev/null || true
        print_ok "Cleaned up Xray config for ${target_tag}"
        print_warn "Note: The Xray inbound in your panel was NOT removed. Delete it manually if needed."
    fi

    # Clean up NoizDNS systemd drop-in if this was a noiz tunnel
    if [[ "$target_tag" == noiz* ]]; then
        rm -f "/etc/systemd/system/dnstm-${target_tag}.service.d/10-noizdns-binary.conf" 2>/dev/null || true
        rmdir "/etc/systemd/system/dnstm-${target_tag}.service.d" 2>/dev/null || true
        systemctl daemon-reload 2>/dev/null || true
        print_ok "Cleaned up NoizDNS override for ${target_tag}"
    fi

    # Restart router only if tunnels remain
    local remaining
    remaining=$(dnstm tunnel list 2>/dev/null | grep -o 'tag=[^ ]*' || true)
    if [[ -n "$remaining" ]]; then
        print_info "Restarting DNS Router..."
        dnstm router stop 2>/dev/null || true
        sleep 1
        if dnstm router start 2>/dev/null; then
            print_ok "DNS Router restarted"
        else
            print_warn "DNS Router restart may have issues. Check: dnstm router logs"
        fi
        echo ""
        print_info "Remaining tunnels:"
        echo ""
        dnstm tunnel list 2>/dev/null || true
    else
        dnstm router stop 2>/dev/null || true
        print_info "No tunnels remaining — DNS Router stopped"
    fi
    echo ""
    print_ok "Tunnel '${target_tag}' removed."
    echo ""
}

# ─── --add-tunnel ────────────────────────────────────────────────────────────────

do_add_tunnel() {
    banner

    if [[ $EUID -ne 0 ]]; then
        echo -e "  ${CROSS} Not running as root. Please run with: sudo bash $0 --add-tunnel"
        exit 1
    fi

    if ! command -v dnstm &>/dev/null; then
        print_fail "dnstm is not installed. Run the full setup first: sudo bash $0"
        exit 1
    fi

    print_header "Add Single Tunnel"

    # Show current tunnels
    echo ""
    print_info "Current tunnels:"
    echo ""
    dnstm tunnel list 2>/dev/null || print_info "(none)"
    echo ""

    # Detect server IP
    SERVER_IP=$(curl -4 -s --max-time 10 https://api.ipify.org 2>/dev/null || true)
    if [[ -n "$SERVER_IP" ]]; then
        print_ok "Server IP: ${SERVER_IP}"
    fi
    echo ""

    # 1. Choose transport
    echo -e "  ${BOLD}Transport:${NC}"
    echo -e "  ${BOLD}1)${NC}  Slipstream  ${DIM}(QUIC + TLS, faster ~63 KB/s)${NC}"
    echo -e "  ${BOLD}2)${NC}  DNSTT       ${DIM}(Noise + Curve25519, ~42 KB/s)${NC}"
    echo ""
    local transport_choice
    transport_choice=$(prompt_input "Select transport (1-2)" "1")
    local transport
    case "$transport_choice" in
        1) transport="slipstream" ;;
        2) transport="dnstt" ;;
        *)
            print_fail "Invalid selection. Use 1 or 2."
            exit 1
            ;;
    esac
    print_ok "Transport: ${transport}"
    echo ""

    # 2. Choose backend
    echo -e "  ${BOLD}Backend:${NC}"
    echo -e "  ${BOLD}1)${NC}  SOCKS  ${DIM}(connects to microsocks proxy)${NC}"
    echo -e "  ${BOLD}2)${NC}  SSH    ${DIM}(connects via SSH port forwarding, requires SSH user)${NC}"
    echo ""
    local backend_choice
    backend_choice=$(prompt_input "Select backend (1-2)" "1")
    local backend
    case "$backend_choice" in
        1) backend="socks" ;;
        2) backend="ssh" ;;
        *)
            print_fail "Invalid selection. Use 1 or 2."
            exit 1
            ;;
    esac
    print_ok "Backend: ${backend}"
    echo ""

    # 3. Get domain
    local domain
    domain=$(prompt_input "Enter the full tunnel domain (e.g. t.example.com)")
    domain=$(echo "$domain" | sed 's|^[[:space:]]*||;s|[[:space:]]*$||;s|^https\?://||;s|/.*$||')
    if [[ -z "$domain" || ! "$domain" == *.*.* ]]; then
        print_fail "Invalid domain. Must be a subdomain (e.g. t.example.com, not example.com)"
        exit 1
    fi
    print_ok "Domain: ${domain}"
    echo ""

    # 4. Get tag
    local tag
    tag=$(prompt_input "Enter a unique tag for this tunnel (e.g. slip1, dnstt2, my-tunnel)")
    tag=$(echo "$tag" | sed 's|[[:space:]]||g')
    if [[ -z "$tag" ]]; then
        print_fail "Tag cannot be empty."
        exit 1
    fi
    # Check if tag already exists
    if dnstm tunnel list 2>/dev/null | grep -o 'tag=[^ ]*' | grep -qxF "tag=${tag}"; then
        print_fail "Tunnel with tag '${tag}' already exists. Choose a different tag."
        exit 1
    fi
    print_ok "Tag: ${tag}"
    echo ""

    # 5. MTU for DNSTT
    local mtu_flag=""
    if [[ "$transport" == "dnstt" ]]; then
        local mtu_input
        mtu_input=$(prompt_input "DNSTT MTU size (512-1400)" "$DNSTT_MTU")
        if [[ "$mtu_input" =~ ^[0-9]+$ ]] && [[ "$mtu_input" -ge 512 ]] && [[ "$mtu_input" -le 1400 ]]; then
            mtu_flag="--mtu $mtu_input"
            print_ok "MTU: ${mtu_input}"
        else
            print_warn "Invalid MTU; using default ${DNSTT_MTU}"
            mtu_flag="--mtu $DNSTT_MTU"
        fi
        echo ""
    fi

    # Confirm
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Creating tunnel:${NC}"
    echo -e "  Transport: ${GREEN}${transport}${NC}"
    echo -e "  Backend:   ${GREEN}${backend}${NC}"
    echo -e "  Domain:    ${GREEN}${domain}${NC}"
    echo -e "  Tag:       ${GREEN}${tag}${NC}"
    echo ""

    if ! prompt_yn "Create this tunnel?" "y"; then
        print_info "Cancelled."
        exit 0
    fi

    echo ""

    # Create the tunnel
    print_info "Creating tunnel: ${tag}..."
    local create_output
    # shellcheck disable=SC2086
    create_output=$(dnstm tunnel add --transport "$transport" --backend "$backend" --domain "$domain" --tag "$tag" $mtu_flag 2>&1) || true
    echo "$create_output"

    if dnstm tunnel list 2>/dev/null | grep -o 'tag=[^ ]*' | grep -qxF "tag=${tag}"; then
        print_ok "Created: ${tag}"
    else
        print_fail "Tunnel creation may have failed. Check output above."
        exit 1
    fi

    # Show DNSTT pubkey if applicable
    if [[ "$transport" == "dnstt" && -f "/etc/dnstm/tunnels/${tag}/server.pub" ]]; then
        local pubkey
        pubkey=$(cat "/etc/dnstm/tunnels/${tag}/server.pub" 2>/dev/null || true)
        if [[ -n "$pubkey" ]]; then
            echo ""
            echo -e "  ${BOLD}${YELLOW}DNSTT Public Key (save this!):${NC}"
            echo -e "  ${GREEN}${pubkey}${NC}"
        fi
    fi

    echo ""

    # Start the tunnel
    print_info "Starting tunnel: ${tag}..."
    if dnstm tunnel start --tag "$tag" 2>/dev/null; then
        print_ok "Started: ${tag}"
    else
        print_warn "Could not start tunnel. Check: dnstm tunnel logs --tag ${tag}"
    fi

    # Restart router to pick up new config
    print_info "Restarting DNS Router..."
    dnstm router stop 2>/dev/null || true
    sleep 1
    if dnstm router start 2>/dev/null; then
        print_ok "DNS Router restarted"
    else
        print_warn "DNS Router restart may have issues. Check: dnstm router logs"
    fi

    echo ""

    # Show share URLs
    local subdomain
    subdomain=$(echo "$domain" | sed 's/\..*//')
    local base_domain
    base_domain=$(echo "$domain" | sed 's/^[^.]*\.//')

    echo -e "  ${BOLD}Share URL — dnst:// (for dnstc CLI)${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    local share_url
    share_url=$(dnstm tunnel share -t "$tag" 2>/dev/null || true)
    if [[ -n "$share_url" ]]; then
        echo -e "  ${share_url}"
    else
        print_info "Share URL not available (generate later with: dnstm tunnel share -t ${tag})"
    fi
    echo ""

    # Generate slipnet:// URL for non-SSH tunnels
    if [[ "$backend" == "socks" ]]; then
        # Detect existing SOCKS auth via dnstm
        detect_socks_auth || true
        local s_user="$SOCKS_USER" s_pass="$SOCKS_PASS"

        local pubkey_for_url=""
        if [[ "$transport" == "dnstt" && -f "/etc/dnstm/tunnels/${tag}/server.pub" ]]; then
            pubkey_for_url=$(cat "/etc/dnstm/tunnels/${tag}/server.pub" 2>/dev/null || true)
        fi

        local slipnet_type
        case "$transport" in
            slipstream) slipnet_type="ss" ;;
            dnstt) slipnet_type="dnstt" ;;
        esac

        DOMAIN="$base_domain"
        local slipnet_url
        slipnet_url=$(generate_slipnet_url "$slipnet_type" "$subdomain" "$pubkey_for_url" "" "" "$s_user" "$s_pass")
        echo -e "  ${BOLD}Share URL — slipnet:// (for SlipNet app)${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  ${slipnet_url}"
        echo ""
    else
        echo -e "  ${DIM}slipnet:// URL for SSH tunnels requires credentials.${NC}"
        echo -e "  ${DIM}Use --status after creating an SSH user to see all share URLs.${NC}"
        echo ""
    fi
    echo -e "  ${BOLD}Required DNS Record${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  Make sure this NS record exists in Cloudflare for ${GREEN}${base_domain}${NC}:"
    echo ""
    echo -e "  Type: ${GREEN}NS${NC}  |  Name: ${GREEN}${subdomain}${NC}  |  Target: ${GREEN}ns.${base_domain}${NC}"
    echo ""

    print_info "All tunnels:"
    echo ""
    dnstm tunnel list 2>/dev/null || true
    echo ""
    print_ok "Tunnel '${tag}' added."
    echo ""
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

    if [[ -f /usr/local/bin/noizdns-server ]]; then
        rm -f /usr/local/bin/noizdns-server
        print_ok "Removed /usr/local/bin/noizdns-server"
    fi

    # Stop microsocks
    if systemctl is-active --quiet microsocks 2>/dev/null; then
        systemctl stop microsocks 2>/dev/null || true
        systemctl disable microsocks 2>/dev/null || true
        print_ok "Stopped and disabled microsocks"
    fi

    # Remove config directory (includes /etc/dnstm/xray/)
    if [[ -d /etc/dnstm ]]; then
        rm -rf /etc/dnstm
        print_ok "Removed /etc/dnstm (including Xray tunnel configs)"
    fi

    # Remove systemd overrides (hardening + xray upstream drop-ins)
    find /etc/systemd/system -maxdepth 2 -type f -name '20-hardening.conf' -path '*/dnstm-*.service.d/*' -delete 2>/dev/null || true
    find /etc/systemd/system -maxdepth 2 -type f -name '10-xray-upstream.conf' -path '*/dnstm-*.service.d/*' -delete 2>/dev/null || true
    find /etc/systemd/system -maxdepth 2 -type f -name '10-noizdns-binary.conf' -path '*/dnstm-*.service.d/*' -delete 2>/dev/null || true
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
        ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf || true
    fi
    print_ok "Restored systemd-resolved defaults (best effort)"

    echo ""
    print_ok "${GREEN}Uninstall complete.${NC}"
    echo ""
    print_warn "Note: DNS records in Cloudflare were NOT removed. Remove them manually if needed."
    print_warn "Note: Xray/3x-ui panel was NOT removed (only DNSTT tunnel configs were cleaned up)."
    echo ""
}

# ─── Architecture Detection ────────────────────────────────────────────────────

detect_architecture() {
    # Detect system architecture using uname and map it to binary suffix
    # Supports: 386, amd64, arm64, armv7
    local machine_arch
    machine_arch=$(uname -m)

    case "$machine_arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        i386|i686)
            echo "386"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l|armv7)
            echo "armv7"
            ;;
        *)
            print_warn "Unsupported architecture: $machine_arch (defaulting to amd64)" >&2
            echo "amd64"
            ;;
    esac
}

# ─── User Management TUI ──────────────────────────────────────────────────────

do_manage_users() {
    banner
    print_header "SSH Tunnel User Management"

    # Check root
    if [[ $EUID -ne 0 ]]; then
        print_fail "Not running as root. Please run with: sudo bash $0 --users"
        exit 1
    fi

    # Install sshtun-user if not present
    if ! command -v sshtun-user &>/dev/null; then
        print_info "sshtun-user not found. Installing..."
        local arch
        arch=$(detect_architecture)
        if curl -fsSL -o /usr/local/bin/sshtun-user "https://github.com/net2share/sshtun-user/releases/latest/download/sshtun-user-linux-${arch}"; then
            chmod +x /usr/local/bin/sshtun-user
            print_ok "Downloaded sshtun-user for ${arch}"
        else
            print_fail "Failed to download sshtun-user for ${arch} architecture. Check your internet connection."
            exit 1
        fi

        # Run initial configure
        print_info "Applying SSH security configuration..."
        mkdir -p /run/sshd 2>/dev/null || true
        if timeout 30 sshtun-user configure </dev/null 2>&1; then
            print_ok "SSH configuration applied"
        else
            print_warn "SSH configuration may not have applied fully — user management may have issues"
        fi
        echo ""
    fi

    while true; do
        echo ""
        echo -e "  ${BOLD}SSH Tunnel User Management${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo ""
        echo -e "  ${BOLD}1${NC}  List users"
        echo -e "  ${BOLD}2${NC}  Add user"
        echo -e "  ${BOLD}3${NC}  Change password"
        echo -e "  ${BOLD}4${NC}  Delete user"
        echo -e "  ${BOLD}0${NC}  Exit"
        echo ""

        local choice=""
        read -rp "  Select [0-4]: " choice || break

        case "$choice" in
            1)
                echo ""
                print_info "SSH tunnel users:"
                echo ""
                timeout 10 sshtun-user list 2>&1 || print_warn "No users found or sshtun-user error"
                ;;
            2)
                echo ""
                local new_user new_pass
                new_user=$(prompt_input "Enter username for new tunnel user")
                new_user=$(echo "$new_user" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [[ -z "$new_user" ]]; then
                    print_fail "Username cannot be empty"
                    continue
                fi
                if [[ "$new_user" == *"|"* ]]; then
                    print_fail "Username cannot contain the | character"
                    continue
                fi
                new_pass=$(prompt_input "Enter password (leave blank to auto-generate)")
                new_pass=$(echo "$new_pass" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [[ "$new_pass" == *"|"* ]]; then
                    print_fail "Password cannot contain the | character"
                    continue
                fi
                echo ""
                local user_created=false
                if [[ -n "$new_pass" ]]; then
                    if timeout 30 sshtun-user create "$new_user" --insecure-password "$new_pass" 2>&1; then
                        print_ok "User '${new_user}' created"
                        user_created=true
                    else
                        print_fail "Failed to create user '${new_user}' (command timed out or failed)"
                    fi
                else
                    if timeout 30 sshtun-user create "$new_user" </dev/null 2>&1; then
                        print_ok "User '${new_user}' created (random password assigned)"
                        user_created=true
                    else
                        print_fail "Failed to create user '${new_user}' (command timed out or failed)"
                    fi
                fi

                # Generate slipnet:// URLs for SSH tunnels
                if [[ "$user_created" == true ]]; then
                    # Get the actual password (if auto-generated, read it back)
                    local final_pass="$new_pass"
                    if [[ -z "$final_pass" ]]; then
                        final_pass=$(sshtun-user show "$new_user" 2>/dev/null | grep -i pass | awk '{print $NF}' || true)
                    fi
                    if [[ -n "$final_pass" ]]; then
                        echo ""
                        print_info "SlipNet SSH config URLs for user '${new_user}':"
                        echo ""
                        # Find all SSH tunnels and generate URLs
                        local s_user="" s_pass=""
                        if detect_socks_auth; then
                            s_user="$SOCKS_USER"
                            s_pass="$SOCKS_PASS"
                        fi
                        local tunnel_domains
                        tunnel_domains=$(dnstm tunnel list 2>/dev/null || true)
                        # Get all unique base domains from tunnels
                        local domains
                        domains=$(echo "$tunnel_domains" | grep -o 'domain=[^ ]*' | sed 's/domain=//;s/^[a-z]*\.//' | sort -u || true)
                        for dom in $domains; do
                            DOMAIN="$dom"
                            local pubkey=""
                            # Find DNSTT pubkey for this domain
                            local dnstt_tag_name
                            dnstt_tag_name=$(echo "$tunnel_domains" | grep "domain=d\.${dom}" | grep -o 'tag=[^ ]*' | sed 's/tag=//' || true)
                            if [[ -n "$dnstt_tag_name" && -f "/etc/dnstm/tunnels/${dnstt_tag_name}/server.pub" ]]; then
                                pubkey=$(cat "/etc/dnstm/tunnels/${dnstt_tag_name}/server.pub" 2>/dev/null || true)
                            fi
                            # Slipstream + SSH
                            local url
                            url=$(generate_slipnet_url "slipstream_ssh" "s" "" "$new_user" "$final_pass" "$s_user" "$s_pass")
                            echo -e "  ${GREEN}s.${dom}:${NC}  ${url}"
                            # DNSTT + SSH
                            if [[ -n "$pubkey" ]]; then
                                url=$(generate_slipnet_url "dnstt_ssh" "ds" "$pubkey" "$new_user" "$final_pass" "$s_user" "$s_pass")
                                echo -e "  ${GREEN}ds.${dom}:${NC} ${url}"
                            fi
                            # NoizDNS + SSH
                            local noiz_ssh_pk=""
                            local noiz_ssh_tags
                            noiz_ssh_tags=$(echo "$tunnel_domains" | grep -o 'tag=noiz-ssh[^ ]*' | sed 's/tag=//' || true)
                            for ntag in $noiz_ssh_tags; do
                                if [[ -f "/etc/dnstm/tunnels/${ntag}/server.pub" ]]; then
                                    noiz_ssh_pk=$(cat "/etc/dnstm/tunnels/${ntag}/server.pub" 2>/dev/null || true)
                                    if [[ -n "$noiz_ssh_pk" ]]; then
                                        url=$(generate_slipnet_url "sayedns_ssh" "z" "$noiz_ssh_pk" "$new_user" "$final_pass" "$s_user" "$s_pass")
                                        echo -e "  ${GREEN}z.${dom}:${NC}  ${url}"
                                    fi
                                    break
                                fi
                            done
                        done
                    fi
                fi
                ;;
            3)
                echo ""
                local upd_user upd_pass
                upd_user=$(prompt_input "Enter username to update")
                upd_user=$(echo "$upd_user" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [[ -z "$upd_user" ]]; then
                    print_fail "Username cannot be empty"
                    continue
                fi
                if [[ "$upd_user" == *"|"* ]]; then
                    print_fail "Username cannot contain the | character"
                    continue
                fi
                upd_pass=$(prompt_input "Enter new password")
                upd_pass=$(echo "$upd_pass" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [[ -z "$upd_pass" ]]; then
                    print_fail "Password cannot be empty"
                    continue
                fi
                if [[ "$upd_pass" == *"|"* ]]; then
                    print_fail "Password cannot contain the | character"
                    continue
                fi
                echo ""
                if timeout 30 sshtun-user update "$upd_user" --insecure-password "$upd_pass" 2>&1; then
                    print_ok "Password updated for '${upd_user}'"
                else
                    print_fail "Failed to update user '${upd_user}'"
                fi
                ;;
            4)
                echo ""
                local del_user
                del_user=$(prompt_input "Enter username to delete")
                del_user=$(echo "$del_user" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [[ -z "$del_user" ]]; then
                    print_fail "Username cannot be empty"
                    continue
                fi
                if [[ "$del_user" == *"|"* ]]; then
                    print_fail "Username cannot contain the | character"
                    continue
                fi
                if prompt_yn "Are you sure you want to delete '${del_user}'?" "n"; then
                    if timeout 30 sshtun-user delete "$del_user" 2>&1; then
                        print_ok "User '${del_user}' deleted"
                    else
                        print_fail "Failed to delete user '${del_user}'"
                    fi
                else
                    print_info "Cancelled"
                fi
                ;;
            0)
                echo ""
                print_ok "Done"
                exit 0
                ;;
            *)
                print_warn "Invalid choice"
                ;;
        esac
    done
}

# ─── Xray Backend Integration ─────────────────────────────────────────────────

# Install 3x-ui panel with custom credentials and port.
# Usage: install_3xui <username> <password> <panel_port>
install_3xui() {
    local admin_user="$1"
    local admin_pass="$2"
    local panel_port="$3"

    print_info "Downloading and installing 3x-ui..."
    echo ""

    # Download the install script
    local install_script
    install_script=$(mktemp)
    if ! curl -fsSL -o "$install_script" "https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh" 2>/dev/null; then
        rm -f "$install_script"
        print_fail "Could not download 3x-ui install script."
        return 1
    fi

    # Run non-interactively with 'y' piped for prompts
    local install_log
    install_log=$(mktemp)
    if ! echo "y" | bash "$install_script" > "$install_log" 2>&1; then
        tail -5 "$install_log"
        rm -f "$install_log" "$install_script"
        print_fail "3x-ui installation failed."
        return 1
    fi
    tail -5 "$install_log"
    rm -f "$install_log" "$install_script"

    # Wait for service to start
    sleep 3

    if ! systemctl is-active --quiet x-ui 2>/dev/null; then
        print_fail "3x-ui service did not start."
        return 1
    fi
    print_ok "3x-ui installed and running"

    # Set custom credentials and port via database
    # IMPORTANT: if setting fails, we must output the ACTUAL values so the caller
    # uses correct credentials for the API (avoids mismatch)
    INSTALL_3XUI_ACTUAL_USER="$admin_user"
    INSTALL_3XUI_ACTUAL_PASS="$admin_pass"
    INSTALL_3XUI_ACTUAL_PORT="$panel_port"

    if command -v sqlite3 &>/dev/null && [[ -f /etc/x-ui/x-ui.db ]]; then
        # Escape single quotes for SQL safety (replace ' with '')
        local sql_user="${admin_user//\'/\'\'}"
        local sql_pass="${admin_pass//\'/\'\'}"

        if echo "UPDATE users SET username='${sql_user}', password='${sql_pass}' WHERE id=1;" | sqlite3 /etc/x-ui/x-ui.db 2>/dev/null; then
            print_ok "Set panel credentials: ${admin_user}"
        else
            print_warn "Could not set custom credentials. Using defaults: admin/admin"
            INSTALL_3XUI_ACTUAL_USER="admin"
            INSTALL_3XUI_ACTUAL_PASS="admin"
        fi

        # Set panel port (already validated as numeric, no injection risk)
        local existing
        existing=$(sqlite3 /etc/x-ui/x-ui.db "SELECT COUNT(*) FROM settings WHERE key='webPort'" 2>/dev/null || echo "0")
        if [[ "$existing" -gt 0 ]]; then
            if sqlite3 /etc/x-ui/x-ui.db "UPDATE settings SET value='${panel_port}' WHERE key='webPort'" 2>/dev/null; then
                print_ok "Set panel port: ${panel_port}"
            else
                print_warn "Could not set panel port. Using default: 2053"
                INSTALL_3XUI_ACTUAL_PORT="2053"
            fi
        else
            if sqlite3 /etc/x-ui/x-ui.db "INSERT INTO settings (key, value) VALUES ('webPort', '${panel_port}')" 2>/dev/null; then
                print_ok "Set panel port: ${panel_port}"
            else
                print_warn "Could not set panel port. Using default: 2053"
                INSTALL_3XUI_ACTUAL_PORT="2053"
            fi
        fi
    else
        print_warn "Could not set custom credentials (sqlite3 not available). Using defaults: admin/admin, port 2053"
        INSTALL_3XUI_ACTUAL_USER="admin"
        INSTALL_3XUI_ACTUAL_PASS="admin"
        INSTALL_3XUI_ACTUAL_PORT="2053"
    fi

    # Restart to apply credential and port changes
    systemctl restart x-ui 2>/dev/null || true
    sleep 2

    if systemctl is-active --quiet x-ui 2>/dev/null; then
        print_ok "3x-ui restarted with new settings"
    else
        print_warn "3x-ui may need manual restart: systemctl restart x-ui"
    fi
}

# Install raw Xray (headless, no web panel).
# Creates a minimal Xray setup with just the binary and config.
# Usage: install_xray_headless
install_xray_headless() {
    print_info "Installing Xray (headless mode, no web panel)..."

    # Check if Xray binary already exists
    if command -v xray &>/dev/null || [[ -f /usr/local/bin/xray ]]; then
        print_ok "Xray binary already installed"
    else
        # Install via official script — capture output to check exit code properly
        local install_log
        install_log=$(mktemp)
        if ! bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" -- install > "$install_log" 2>&1; then
            tail -5 "$install_log"
            rm -f "$install_log"
            print_fail "Xray installation failed."
            return 1
        fi
        tail -3 "$install_log"
        rm -f "$install_log"

        # Verify the binary was actually installed
        if ! command -v xray &>/dev/null && [[ ! -f /usr/local/bin/xray ]]; then
            print_fail "Xray binary not found after installation."
            return 1
        fi
        print_ok "Xray binary installed"
    fi

    # Ensure the config directory exists
    mkdir -p /usr/local/etc/xray

    # Create a minimal config with just an empty inbounds array
    # (the actual inbound will be added by create_headless_xray_inbound)
    if [[ ! -f /usr/local/etc/xray/config.json ]]; then
        cat > /usr/local/etc/xray/config.json <<'XRAYEOF'
{
  "log": {"loglevel": "warning"},
  "inbounds": [],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct"},
    {"protocol": "blackhole", "tag": "block"}
  ]
}
XRAYEOF
        chmod 600 /usr/local/etc/xray/config.json
        print_ok "Created minimal Xray config"
    fi

    # Enable and start the service
    systemctl enable xray 2>/dev/null || true
    systemctl start xray 2>/dev/null || true

    if systemctl is-active --quiet xray 2>/dev/null; then
        print_ok "Xray service running (headless)"
    else
        print_warn "Xray service may need manual start: systemctl start xray"
    fi
}

# Create an inbound directly in Xray config.json (headless mode, no panel).
# Usage: create_headless_xray_inbound
# Requires: XRAY_PROTOCOL, XRAY_INBOUND_PORT
# Sets: XRAY_UUID or XRAY_PASSWORD
create_headless_xray_inbound() {
    local config_file="/usr/local/etc/xray/config.json"

    if [[ ! -f "$config_file" ]]; then
        print_fail "Xray config not found at ${config_file}"
        return 1
    fi

    # Generate credentials
    XRAY_UUID=""
    XRAY_PASSWORD=""
    if [[ "$XRAY_PROTOCOL" == "vless" || "$XRAY_PROTOCOL" == "vmess" ]]; then
        XRAY_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || openssl rand -hex 16 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/')
    else
        XRAY_PASSWORD=$(openssl rand -hex 16)
    fi

    # Build the new inbound JSON
    local new_inbound
    case "$XRAY_PROTOCOL" in
        vless)
            new_inbound=$(jq -nc --arg uuid "$XRAY_UUID" --argjson port "$XRAY_INBOUND_PORT" '{
                "listen": "127.0.0.1", "port": $port, "protocol": "vless",
                "settings": {"clients": [{"id": $uuid, "flow": ""}], "decryption": "none"},
                "streamSettings": {"network": "tcp", "security": "none"},
                "tag": "dnstt-vless"
            }')
            ;;
        shadowsocks)
            new_inbound=$(jq -nc --arg pass "$XRAY_PASSWORD" --argjson port "$XRAY_INBOUND_PORT" '{
                "listen": "127.0.0.1", "port": $port, "protocol": "shadowsocks",
                "settings": {"method": "chacha20-ietf-poly1305", "password": $pass, "network": "tcp,udp"},
                "tag": "dnstt-shadowsocks"
            }')
            ;;
        vmess)
            new_inbound=$(jq -nc --arg uuid "$XRAY_UUID" --argjson port "$XRAY_INBOUND_PORT" '{
                "listen": "127.0.0.1", "port": $port, "protocol": "vmess",
                "settings": {"clients": [{"id": $uuid, "alterId": 0}]},
                "streamSettings": {"network": "tcp", "security": "none"},
                "tag": "dnstt-vmess"
            }')
            ;;
        trojan)
            new_inbound=$(jq -nc --arg pass "$XRAY_PASSWORD" --argjson port "$XRAY_INBOUND_PORT" '{
                "listen": "127.0.0.1", "port": $port, "protocol": "trojan",
                "settings": {"clients": [{"password": $pass}]},
                "streamSettings": {"network": "tcp", "security": "none"},
                "tag": "dnstt-trojan"
            }')
            ;;
    esac

    # Backup original config
    cp "$config_file" "${config_file}.bak.$(date +%s)" 2>/dev/null || true

    # Add inbound to the config using jq
    local tmp_config
    tmp_config=$(mktemp)
    if jq --argjson inbound "$new_inbound" '.inbounds += [$inbound]' "$config_file" > "$tmp_config" 2>/dev/null; then
        mv "$tmp_config" "$config_file"
        chmod 600 "$config_file"
        print_ok "Added inbound: ${XRAY_PROTOCOL} on 127.0.0.1:${XRAY_INBOUND_PORT}"
    else
        rm -f "$tmp_config"
        print_fail "Failed to update Xray config."
        return 1
    fi

    # Restart Xray to apply
    systemctl restart xray 2>/dev/null || true
    sleep 1
    if systemctl is-active --quiet xray 2>/dev/null; then
        print_ok "Xray restarted with new inbound"
    else
        print_warn "Xray may need manual restart: systemctl restart xray"
    fi
}

# Detect if an Xray panel (3x-ui) is installed on this server.
# Sets XRAY_PANEL_TYPE to "3xui" or "none"
# Sets XRAY_PANEL_PORT if detected
detect_xray_panel() {
    XRAY_PANEL_TYPE="none"
    XRAY_PANEL_PORT=""
    XRAY_PANEL_RUNNING=false

    # Check for 3x-ui (native install)
    local found_3xui=false
    if systemctl is-active --quiet x-ui 2>/dev/null; then
        found_3xui=true
        XRAY_PANEL_RUNNING=true
    elif systemctl list-unit-files 2>/dev/null | grep -q 'x-ui'; then
        found_3xui=true
    elif [[ -d /usr/local/x-ui ]]; then
        found_3xui=true
    elif command -v x-ui &>/dev/null; then
        found_3xui=true
    fi

    # Check for Docker-based 3x-ui
    if [[ "$found_3xui" == false ]] && command -v docker &>/dev/null; then
        if docker ps 2>/dev/null | grep -qi 'x-ui\|3x-ui'; then
            found_3xui=true
            XRAY_PANEL_RUNNING=true
        fi
    fi

    if [[ "$found_3xui" == true ]]; then
        XRAY_PANEL_TYPE="3xui"

        # Warn if service exists but is not running
        if [[ "$XRAY_PANEL_RUNNING" == false ]]; then
            print_warn "3x-ui is installed but NOT running."
            print_info "Start it with: systemctl start x-ui"
            echo ""
        fi

        # Try to detect panel port
        # Method 1: Parse x-ui config.json
        if [[ -f /usr/local/x-ui/config.json ]]; then
            XRAY_PANEL_PORT=$(jq -r '.port // .webPort // empty' /usr/local/x-ui/config.json 2>/dev/null || true)
        fi

        # Method 2: Check x-ui.db for webPort setting
        if [[ -z "$XRAY_PANEL_PORT" ]] && command -v sqlite3 &>/dev/null; then
            if [[ -f /etc/x-ui/x-ui.db ]]; then
                XRAY_PANEL_PORT=$(sqlite3 /etc/x-ui/x-ui.db "SELECT value FROM settings WHERE key='webPort'" 2>/dev/null || true)
            fi
        fi

        # Method 3: Try common 3x-ui ports (skip 443 — too likely to be nginx)
        if [[ -z "$XRAY_PANEL_PORT" ]]; then
            for port in 2053 54321 2087 2083; do
                if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
                    XRAY_PANEL_PORT="$port"
                    break
                fi
            done
        fi

        # Method 4: Fall back to default
        XRAY_PANEL_PORT="${XRAY_PANEL_PORT:-2053}"
    fi
}

# Get 3x-ui admin credentials. Tries to read from DB first, then asks user.
# Sets XRAY_ADMIN_USER and XRAY_ADMIN_PASS
get_3xui_credentials() {
    XRAY_ADMIN_USER=""
    XRAY_ADMIN_PASS=""

    # Try to read from database
    if command -v sqlite3 &>/dev/null && [[ -f /etc/x-ui/x-ui.db ]]; then
        XRAY_ADMIN_USER=$(sqlite3 /etc/x-ui/x-ui.db "SELECT username FROM users LIMIT 1" 2>/dev/null || true)
        XRAY_ADMIN_PASS=$(sqlite3 /etc/x-ui/x-ui.db "SELECT password FROM users LIMIT 1" 2>/dev/null || true)
    fi

    # Detect bcrypt-hashed passwords (3x-ui v2.0+ hashes by default)
    # Hashed passwords start with $2a$, $2b$, or $2y$ and cannot be used as plaintext
    if [[ -n "$XRAY_ADMIN_PASS" && "$XRAY_ADMIN_PASS" == \$2[aby]\$* ]]; then
        print_warn "Password in database is hashed (3x-ui v2.0+). Manual entry required."
        XRAY_ADMIN_PASS=""
    fi

    if [[ -n "$XRAY_ADMIN_USER" && -n "$XRAY_ADMIN_PASS" ]]; then
        print_ok "Read credentials from 3x-ui database"
        return 0
    fi

    # Ask user — keep DB username if we have it, only ask for what's missing
    echo ""
    echo -e "  ${BOLD}3x-ui Panel Credentials${NC}"
    echo -e "  ${DIM}(needed to create the Xray inbound via API)${NC}"
    echo ""
    if [[ -z "$XRAY_ADMIN_USER" ]]; then
        XRAY_ADMIN_USER=$(prompt_input "Panel username" "admin")
    else
        echo -e "  ${DIM}Username from database: ${XRAY_ADMIN_USER}${NC}"
    fi
    echo ""
    read -rsp "  Panel password [admin]: " XRAY_ADMIN_PASS
    XRAY_ADMIN_PASS="${XRAY_ADMIN_PASS:-admin}"
    echo ""

    if [[ -z "$XRAY_ADMIN_USER" ]]; then
        print_fail "Username cannot be empty."
        return 1
    fi
}

# Let user choose which Xray protocol to use for the inbound.
# Sets XRAY_PROTOCOL
pick_xray_protocol() {
    echo ""
    echo -e "  ${BOLD}Xray Protocol:${NC}"
    echo -e "  ${BOLD}1)${NC}  VLESS        ${DIM}(lightweight, recommended)${NC}"
    echo -e "  ${BOLD}2)${NC}  Shadowsocks  ${DIM}(widely supported, simple)${NC}"
    echo -e "  ${BOLD}3)${NC}  VMess        ${DIM}(V2Ray protocol)${NC}"
    echo -e "  ${BOLD}4)${NC}  Trojan       ${DIM}(HTTPS-like)${NC}"
    echo ""
    local choice
    choice=$(prompt_input "Select protocol (1-4)" "1")
    case "$choice" in
        1) XRAY_PROTOCOL="vless" ;;
        2) XRAY_PROTOCOL="shadowsocks" ;;
        3) XRAY_PROTOCOL="vmess" ;;
        4) XRAY_PROTOCOL="trojan" ;;
        *)
            print_fail "Invalid selection. Use 1-4."
            return 1
            ;;
    esac
    print_ok "Protocol: ${XRAY_PROTOCOL}"
}

# Auto-find a free port for the Xray inbound, let user override.
# Sets XRAY_INBOUND_PORT
pick_xray_port() {
    local port
    # Find a free port
    local attempts=0
    while true; do
        port=$((RANDOM % 50000 + 10000))
        if ! ss -tlnp 2>/dev/null | grep -q ":${port} "; then
            break
        fi
        attempts=$((attempts + 1))
        if [[ $attempts -ge 50 ]]; then
            port=18443
            break
        fi
    done

    echo ""
    XRAY_INBOUND_PORT=$(prompt_input "Xray inbound port (internal only, not exposed)" "$port")

    # Validate
    if ! [[ "$XRAY_INBOUND_PORT" =~ ^[0-9]+$ ]] || [[ "$XRAY_INBOUND_PORT" -lt 1 ]] || [[ "$XRAY_INBOUND_PORT" -gt 65535 ]]; then
        print_fail "Invalid port number. Must be between 1 and 65535."
        return 1
    fi

    if ss -tlnp 2>/dev/null | grep -q ":${XRAY_INBOUND_PORT} "; then
        print_warn "Port ${XRAY_INBOUND_PORT} is already in use. Continuing anyway (may be intended)."
    fi

    print_ok "Inbound port: ${XRAY_INBOUND_PORT} (127.0.0.1 only)"
}

# Create a new inbound on the 3x-ui panel via its API.
# Requires: XRAY_ADMIN_USER, XRAY_ADMIN_PASS, XRAY_PANEL_PORT, XRAY_PROTOCOL, XRAY_INBOUND_PORT
# Sets: XRAY_UUID (for vless/vmess) or XRAY_PASSWORD (for ss/trojan)
create_3xui_inbound() {
    local panel_url="http://127.0.0.1:${XRAY_PANEL_PORT}"
    local cookie_jar
    cookie_jar=$(mktemp)
    chmod 600 "$cookie_jar" 2>/dev/null || true

    # Ensure cookie jar is cleaned up on any exit path
    trap 'rm -f "$cookie_jar"' RETURN

    # Generate credentials for the inbound
    XRAY_UUID=""
    XRAY_PASSWORD=""
    if [[ "$XRAY_PROTOCOL" == "vless" || "$XRAY_PROTOCOL" == "vmess" ]]; then
        XRAY_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || openssl rand -hex 16 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/')
    else
        XRAY_PASSWORD=$(openssl rand -hex 16)
    fi

    # Login to panel
    print_info "Logging in to 3x-ui panel..."
    local login_resp
    login_resp=$(curl -s -c "$cookie_jar" -X POST "${panel_url}/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "username=${XRAY_ADMIN_USER}" \
        --data-urlencode "password=${XRAY_ADMIN_PASS}" \
        --max-time 10 2>/dev/null || true)

    if [[ -z "$login_resp" ]]; then
        print_fail "Could not connect to 3x-ui panel at ${panel_url}"
        print_info "Is the panel running? Check: systemctl status x-ui"
        return 1
    fi

    local login_success
    login_success=$(echo "$login_resp" | jq -r '.success // false' 2>/dev/null || echo "false")
    if [[ "$login_success" != "true" ]]; then
        print_fail "Login failed. Check username/password."
        print_info "Response: $(echo "$login_resp" | jq -r '.msg // "unknown error"' 2>/dev/null || echo "$login_resp")"
        return 1
    fi
    print_ok "Logged in to 3x-ui"

    # Build inbound settings JSON based on protocol
    local settings stream_settings sniffing_settings remark
    remark="DNSTT-${XRAY_PROTOCOL}-${XRAY_INBOUND_PORT}"

    sniffing_settings='{"enabled":true,"destOverride":["http","tls","quic","fakedns"]}'
    stream_settings='{"network":"tcp","security":"none","tcpSettings":{"header":{"type":"none"}}}'

    case "$XRAY_PROTOCOL" in
        vless)
            settings=$(jq -nc --arg uuid "$XRAY_UUID" '{
                "clients": [{"id": $uuid, "flow": "", "email": "dnstt-user", "limitIp": 0, "totalGB": 0, "expiryTime": 0, "enable": true}],
                "decryption": "none",
                "fallbacks": []
            }')
            ;;
        shadowsocks)
            settings=$(jq -nc --arg pass "$XRAY_PASSWORD" '{
                "method": "chacha20-ietf-poly1305",
                "password": $pass,
                "network": "tcp,udp",
                "clients": []
            }')
            ;;
        vmess)
            settings=$(jq -nc --arg uuid "$XRAY_UUID" '{
                "clients": [{"id": $uuid, "alterId": 0, "email": "dnstt-user", "limitIp": 0, "totalGB": 0, "expiryTime": 0, "enable": true}]
            }')
            ;;
        trojan)
            settings=$(jq -nc --arg pass "$XRAY_PASSWORD" '{
                "clients": [{"password": $pass, "email": "dnstt-user", "limitIp": 0, "totalGB": 0, "expiryTime": 0, "enable": true}],
                "fallbacks": []
            }')
            ;;
    esac

    # Create inbound via API
    print_info "Creating inbound: ${XRAY_PROTOCOL} on 127.0.0.1:${XRAY_INBOUND_PORT}..."
    local inbound_data
    inbound_data=$(jq -nc \
        --arg remark "$remark" \
        --argjson port "$XRAY_INBOUND_PORT" \
        --arg protocol "$XRAY_PROTOCOL" \
        --arg settings "$settings" \
        --arg stream "$stream_settings" \
        --arg sniffing "$sniffing_settings" \
        '{
            "up": 0, "down": 0,
            "total": 0,
            "remark": $remark,
            "enable": true,
            "expiryTime": 0,
            "listen": "127.0.0.1",
            "port": $port,
            "protocol": $protocol,
            "settings": $settings,
            "streamSettings": $stream,
            "sniffing": $sniffing
        }')

    local create_resp
    create_resp=$(curl -s -b "$cookie_jar" -X POST "${panel_url}/panel/api/inbounds/add" \
        -H "Content-Type: application/json" \
        -d "$inbound_data" \
        --max-time 10 2>/dev/null || true)

    if [[ -z "$create_resp" ]]; then
        print_fail "No response from panel when creating inbound."
        return 1
    fi

    local create_success
    create_success=$(echo "$create_resp" | jq -r '.success // false' 2>/dev/null || echo "false")
    if [[ "$create_success" != "true" ]]; then
        print_fail "Failed to create inbound."
        print_info "Response: $(echo "$create_resp" | jq -r '.msg // "unknown error"' 2>/dev/null || echo "$create_resp")"
        return 1
    fi

    print_ok "Created inbound: ${remark} (127.0.0.1:${XRAY_INBOUND_PORT})"
}

# Create a systemd drop-in override to redirect the DNSTT tunnel upstream
# from microsocks to the Xray inbound port.
# Usage: create_xray_service_override <tag> <xray_port> <domain>
create_xray_service_override() {
    local tag="$1"
    local xray_port="$2"
    local domain="$3"
    local service="dnstm-${tag}.service"
    local dropin_dir="/etc/systemd/system/${service}.d"
    local dropin_file="${dropin_dir}/10-xray-upstream.conf"

    # Parse original ExecStart to get the tunnel's listening port and key path
    # Use 'systemctl show' for the resolved ExecStart (avoids drop-in merging issues)
    local orig_exec
    orig_exec=$(systemctl cat "$service" 2>/dev/null | grep '^ExecStart=/' | head -1 || true)
    # Fallback: if drop-in already exists, grep for the binary path line
    if [[ -z "$orig_exec" ]]; then
        orig_exec=$(systemctl cat "$service" 2>/dev/null | grep '^ExecStart=.*dnstt-server' | tail -1 || true)
    fi

    if [[ -z "$orig_exec" ]]; then
        print_fail "Could not read ExecStart from ${service}"
        return 1
    fi

    # Extract the listening port (-udp :PORT part) — no Perl regex needed
    local tunnel_port
    tunnel_port=$(echo "$orig_exec" | grep -oE '\-udp[[:space:]]+:?[0-9]+' | grep -oE '[0-9]+' || true)
    if [[ -z "$tunnel_port" ]]; then
        print_fail "Could not detect tunnel listening port from service"
        return 1
    fi

    # Extract the privkey path
    local privkey_path
    privkey_path=$(echo "$orig_exec" | sed -n 's/.*-privkey-file[[:space:]]\+\([^[:space:]]\+\).*/\1/p' || true)
    if [[ -z "$privkey_path" ]]; then
        privkey_path="/etc/dnstm/tunnels/${tag}/server.key"
    fi

    # Extract MTU flag if present (e.g., -mtu 1100)
    local mtu_arg=""
    local orig_mtu
    orig_mtu=$(echo "$orig_exec" | grep -oE '\-mtu[[:space:]]+[0-9]+' || true)
    if [[ -n "$orig_mtu" ]]; then
        mtu_arg=" ${orig_mtu}"
    fi

    # Extract the dnstt-server binary path (first token after ExecStart=)
    local dnstt_bin
    dnstt_bin=$(echo "$orig_exec" | sed 's/^ExecStart=[-+!@]*//;s/[[:space:]].*//' || true)
    if [[ -z "$dnstt_bin" || ! -f "$dnstt_bin" ]]; then
        # Fallback to common locations
        for bin_path in /usr/local/bin/dnstt-server /usr/bin/dnstt-server; do
            if [[ -f "$bin_path" ]]; then
                dnstt_bin="$bin_path"
                break
            fi
        done
    fi

    if [[ -z "$dnstt_bin" ]]; then
        print_fail "Could not find dnstt-server binary"
        return 1
    fi

    if ! mkdir -p "$dropin_dir" 2>/dev/null; then
        print_fail "Could not create drop-in directory: ${dropin_dir}"
        return 1
    fi
    cat > "$dropin_file" <<EOF || { print_fail "Could not write service override: ${dropin_file}"; return 1; }
[Service]
ExecStart=
ExecStart=${dnstt_bin} -udp :${tunnel_port}${mtu_arg} -privkey-file ${privkey_path} ${domain} 127.0.0.1:${xray_port}
EOF

    print_ok "Created service override: ${service} → 127.0.0.1:${xray_port}"
}

# Generate a client share URI for the Xray tunnel.
# Usage: generate_xray_client_uri <protocol> <server_ip> <port> <uuid_or_pass> [remark]
# Returns the URI string
generate_xray_client_uri() {
    local protocol="$1"
    local server_ip="$2"
    local port="$3"
    local credential="$4"
    local remark="${5:-DNSTT-Xray}"

    # URL-encode the remark (pure bash, no python dependency)
    local encoded_remark=""
    local i c
    for (( i=0; i<${#remark}; i++ )); do
        c="${remark:$i:1}"
        case "$c" in
            [a-zA-Z0-9._~-]) encoded_remark+="$c" ;;
            *) encoded_remark+=$(printf '%%%02X' "'$c") ;;
        esac
    done

    # Handle IPv6 addresses — wrap in brackets for URIs
    local host="$server_ip"
    if [[ "$server_ip" == *:* ]]; then
        host="[${server_ip}]"
    fi

    case "$protocol" in
        vless)
            echo "vless://${credential}@${host}:${port}?encryption=none&type=tcp&security=none#${encoded_remark}"
            ;;
        shadowsocks)
            local method="chacha20-ietf-poly1305"
            # SIP002 requires URL-safe base64 (RFC 4648 section 5): +/ → -_, no padding
            local encoded
            encoded=$(echo -n "${method}:${credential}" | base64 -w0 | tr '+/' '-_' | tr -d '=')
            echo "ss://${encoded}@${host}:${port}#${encoded_remark}"
            ;;
        vmess)
            local vmess_json
            vmess_json=$(jq -nc \
                --arg ip "$server_ip" \
                --arg port "$port" \
                --arg uuid "$credential" \
                --arg remark "$remark" \
                '{
                    "v": "2",
                    "ps": $remark,
                    "add": $ip,
                    "port": $port,
                    "id": $uuid,
                    "aid": "0",
                    "net": "tcp",
                    "type": "none",
                    "host": "",
                    "path": "",
                    "tls": "",
                    "scy": "auto"
                }')
            echo "vmess://$(echo -n "$vmess_json" | base64 -w0)"
            ;;
        trojan)
            echo "trojan://${credential}@${host}:${port}?type=tcp&security=none#${encoded_remark}"
            ;;
    esac
}

# Save Xray tunnel config to /etc/dnstm/xray/
# Usage: save_xray_config <tag>
save_xray_config() {
    local tag="$1"
    local config_dir="/etc/dnstm/xray"
    local config_file="${config_dir}/${tag}.conf"

    if ! mkdir -p "$config_dir" 2>/dev/null; then
        print_warn "Could not create config directory: ${config_dir}"
        return 1
    fi
    chmod 700 "$config_dir" 2>/dev/null || true
    # Create file with restrictive permissions before writing any secrets
    # Use subshell umask to ensure touch fallback is also restrictive
    install -m 600 /dev/null "$config_file" 2>/dev/null || (umask 077; touch "$config_file")
    chmod 600 "$config_file" 2>/dev/null || true
    # Use printf %q to safely quote all values (handles special chars)
    {
        printf 'XRAY_TAG=%q\n' "$tag"
        printf 'XRAY_PORT=%q\n' "$XRAY_INBOUND_PORT"
        printf 'XRAY_PROTOCOL=%q\n' "$XRAY_PROTOCOL"
        printf 'XRAY_UUID=%q\n' "$XRAY_UUID"
        printf 'XRAY_PASSWORD=%q\n' "$XRAY_PASSWORD"
        printf 'XRAY_PANEL=%q\n' "$XRAY_PANEL_TYPE"
        printf 'XRAY_DOMAIN=%q\n' "x.${DOMAIN}"
    } > "$config_file" || { print_warn "Could not write config: ${config_file}"; return 1; }
    print_ok "Saved config: ${config_file}"
}

# ─── NoizDNS Service Override ─────────────────────────────────────────────────

# Override a DNSTT tunnel's systemd service to use the NoizDNS binary instead.
# Only swaps the binary path, keeps the same upstream/flags/keys.
# Usage: create_noizdns_service_override <tag>
create_noizdns_service_override() {
    local tag="$1"
    local service="dnstm-${tag}.service"
    local dropin_dir="/etc/systemd/system/${service}.d"
    local dropin_file="${dropin_dir}/10-noizdns-binary.conf"

    # Read original ExecStart
    local orig_exec
    orig_exec=$(systemctl cat "$service" 2>/dev/null | grep '^ExecStart=/' | head -1 || true)
    if [[ -z "$orig_exec" ]]; then
        orig_exec=$(systemctl cat "$service" 2>/dev/null | grep '^ExecStart=.*dnstt-server' | tail -1 || true)
    fi
    if [[ -z "$orig_exec" ]]; then
        print_fail "Could not read ExecStart from ${service}"
        return 1
    fi

    # Replace the dnstt-server binary path with noizdns-server, keep everything else
    local new_exec
    new_exec=$(echo "$orig_exec" | sed 's|ExecStart=[^ ]*/dnstt-server|ExecStart=/usr/local/bin/noizdns-server|')

    if ! mkdir -p "$dropin_dir" 2>/dev/null; then
        print_fail "Could not create drop-in directory: ${dropin_dir}"
        return 1
    fi
    cat > "$dropin_file" <<EOF || { print_fail "Could not write NoizDNS override: ${dropin_file}"; return 1; }
[Service]
ExecStart=
${new_exec}
EOF
    print_ok "NoizDNS binary override: ${service}"
}

# Main Xray backend integration function
do_add_xray() {
    banner

    if [[ $EUID -ne 0 ]]; then
        echo -e "  ${CROSS} Not running as root. Please run with: sudo bash $0 --add-xray"
        exit 1
    fi

    if ! command -v dnstm &>/dev/null; then
        print_fail "dnstm is not installed. Run the full setup first: sudo bash $0"
        exit 1
    fi

    print_header "Xray Backend via DNS Tunnel"

    echo ""
    echo -e "  ${BOLD}How this works:${NC}"
    echo -e "  ${DIM}This connects your existing Xray panel (3x-ui) to a DNSTT tunnel.${NC}"
    echo -e "  ${DIM}A new internal-only Xray inbound is created on 127.0.0.1, then a${NC}"
    echo -e "  ${DIM}DNSTT tunnel is set up to forward DNS traffic to that inbound.${NC}"
    echo ""
    echo -e "  ${DIM}Flow: Phone (SlipNet+Nekobox) → DNS tunnel → Xray inbound → Internet${NC}"
    echo ""

    # Ensure required tools are available
    if ! command -v curl &>/dev/null; then
        print_fail "curl is required but not installed. Install it: apt-get install curl"
        exit 1
    fi
    if ! command -v jq &>/dev/null; then
        print_info "Installing jq..."
        if apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq jq >/dev/null 2>&1; then
            print_ok "Installed jq"
        else
            print_fail "Failed to install jq. Install it manually: apt-get install jq"
            exit 1
        fi
    fi

    # Detect server IP
    SERVER_IP=$(curl -4 -s --max-time 10 https://api.ipify.org 2>/dev/null || true)
    if [[ -n "$SERVER_IP" ]]; then
        print_ok "Server IP: ${SERVER_IP}"
    else
        print_warn "Could not detect server IP"
        SERVER_IP=$(prompt_input "Enter server IP manually" "")
        if [[ -z "$SERVER_IP" ]]; then
            print_fail "Server IP is required."
            exit 1
        fi
    fi

    # Show current tunnels
    echo ""
    print_info "Current tunnels:"
    echo ""
    dnstm tunnel list 2>/dev/null || print_info "(none)"
    echo ""

    # 1. Detect Xray panel
    print_info "Detecting Xray panel..."
    detect_xray_panel

    if [[ "$XRAY_PANEL_TYPE" == "none" ]]; then
        echo ""
        print_warn "No Xray installation detected on this server."
        echo ""
        echo -e "  ${BOLD}How would you like to set up Xray?${NC}"
        echo -e "  ${BOLD}1)${NC}  Full panel (3x-ui)   ${DIM}— web dashboard, user management, traffic stats${NC}"
        echo -e "  ${BOLD}2)${NC}  Headless (Xray only) ${DIM}— no web panel, lightweight, config-based${NC}"
        echo -e "  ${BOLD}0)${NC}  Cancel"
        echo ""
        local install_choice
        install_choice=$(prompt_input "Select (0-2)" "1")

        case "$install_choice" in
            1)
                # Full panel install
                echo ""
                echo -e "  ${BOLD}3x-ui Panel Setup${NC}"
                echo -e "  ${DIM}Choose admin credentials and panel port.${NC}"
                echo ""
                local new_user new_pass new_port
                new_user=$(prompt_input "Panel admin username" "admin")
                echo ""
                new_pass=$(prompt_input "Panel admin password" "password")
                echo ""
                new_port=$(prompt_input "Panel web port" "2053")
                if ! [[ "$new_port" =~ ^[0-9]+$ ]]; then
                    new_port=2053
                fi
                echo ""

                install_3xui "$new_user" "$new_pass" "$new_port" || return 1

                # Use ACTUAL values (may differ from requested if sqlite3 failed)
                XRAY_PANEL_TYPE="3xui"
                XRAY_PANEL_PORT="${INSTALL_3XUI_ACTUAL_PORT}"
                XRAY_PANEL_RUNNING=true
                XRAY_ADMIN_USER="${INSTALL_3XUI_ACTUAL_USER}"
                XRAY_ADMIN_PASS="${INSTALL_3XUI_ACTUAL_PASS}"

                echo ""
                echo -e "  ${BOLD}Panel Access${NC}"
                echo -e "  ${DIM}────────────────────────────────────────${NC}"
                echo -e "  URL:       ${GREEN}http://${SERVER_IP}:${XRAY_PANEL_PORT}${NC}"
                echo -e "  Username:  ${GREEN}${XRAY_ADMIN_USER}${NC}"
                echo -e "  Password:  ${GREEN}${XRAY_ADMIN_PASS}${NC}"
                echo ""
                ;;
            2)
                # Headless install
                echo ""
                install_xray_headless || return 1
                XRAY_PANEL_TYPE="headless"
                XRAY_PANEL_RUNNING=true
                echo ""
                ;;
            0|*)
                echo ""
                print_info "Cancelled."
                return 0
                ;;
        esac
    else
        print_ok "Detected: 3x-ui (port ${XRAY_PANEL_PORT})"
    fi

    # 2. Get panel credentials (skip for headless — no panel API needed)
    if [[ "$XRAY_PANEL_TYPE" == "3xui" && -z "${XRAY_ADMIN_USER:-}" ]]; then
        get_3xui_credentials || return 1
    fi

    # 3. Choose protocol
    pick_xray_protocol || return 1

    # 4. Pick port for internal inbound
    pick_xray_port || return 1

    # 5. Get domain
    echo ""
    echo -e "  ${BOLD}Domain Configuration${NC}"
    echo -e "  ${DIM}The Xray tunnel will use subdomain: x.<your-domain>${NC}"
    echo ""

    # Try to detect domain from existing tunnels
    local detected_domain=""
    detected_domain=$(dnstm tunnel list 2>/dev/null | grep -o 'domain=[^ ]*' | head -1 | sed 's/domain=//' | sed 's/^[^.]*\.//' || true)

    if [[ -n "$detected_domain" ]]; then
        DOMAIN=$(prompt_input "Domain" "$detected_domain")
    else
        DOMAIN=$(prompt_input "Enter your domain (e.g. example.com)" "")
    fi

    if [[ -z "$DOMAIN" ]]; then
        print_fail "Domain is required."
        return 1
    fi
    print_ok "Tunnel domain: x.${DOMAIN}"

    # Check if x.DOMAIN tunnel already exists (prevent duplicates)
    if dnstm tunnel list 2>/dev/null | grep -q "domain=x\.${DOMAIN}"; then
        print_fail "A tunnel for x.${DOMAIN} already exists."
        print_info "Remove it first with: sudo bash $0 --remove-tunnel"
        return 1
    fi

    # 6. Create Xray inbound
    echo ""
    if [[ "$XRAY_PANEL_TYPE" == "headless" ]]; then
        create_headless_xray_inbound || return 1
    else
        create_3xui_inbound || return 1
    fi

    # 7. Create DNSTT tunnel via dnstm
    echo ""

    # Determine tag — check existing xray tags and increment (exact match)
    local xray_num=1
    while dnstm tunnel list 2>/dev/null | grep -o 'tag=[^ ]*' | grep -qxF "tag=xray${xray_num}"; do
        xray_num=$((xray_num + 1))
    done
    local tag="xray${xray_num}"

    print_info "Creating DNSTT tunnel: ${tag} (x.${DOMAIN})..."
    local mtu_flag=""
    if [[ -n "${DNSTT_MTU:-}" ]]; then
        mtu_flag="--mtu ${DNSTT_MTU}"
    fi
    # shellcheck disable=SC2086
    local create_output
    create_output=$(dnstm tunnel add --transport dnstt --backend socks --domain "x.${DOMAIN}" --tag "$tag" $mtu_flag 2>&1) || true
    echo "$create_output"

    if ! dnstm tunnel list 2>/dev/null | grep -o 'tag=[^ ]*' | grep -qxF "tag=${tag}"; then
        print_fail "Tunnel creation failed."
        if [[ "$XRAY_PANEL_TYPE" == "headless" ]]; then
            print_info "Note: Xray inbound on port ${XRAY_INBOUND_PORT} was added to config.json but the tunnel failed."
            print_info "Remove it manually: edit /usr/local/etc/xray/config.json"
        else
            print_info "Note: Xray inbound on port ${XRAY_INBOUND_PORT} was created in 3x-ui but the tunnel failed."
            print_info "Remove it manually from the panel dashboard if needed."
        fi
        return 1
    fi
    print_ok "Created tunnel: ${tag}"

    # 8. Override upstream to point at Xray instead of microsocks
    echo ""
    print_info "Redirecting tunnel upstream to Xray..."
    if ! create_xray_service_override "$tag" "$XRAY_INBOUND_PORT" "x.${DOMAIN}"; then
        # Rollback: remove the tunnel we just created
        print_warn "Service override failed. Rolling back tunnel..."
        dnstm tunnel stop --tag "$tag" 2>/dev/null || true
        dnstm tunnel remove --tag "$tag" 2>/dev/null || true
        if [[ "$XRAY_PANEL_TYPE" == "headless" ]]; then
            print_info "Note: Xray inbound on port ${XRAY_INBOUND_PORT} was added to config.json but not cleaned up."
            print_info "Remove it manually: edit /usr/local/etc/xray/config.json"
        else
            print_info "Note: Xray inbound on port ${XRAY_INBOUND_PORT} was NOT removed from 3x-ui panel."
            print_info "Remove it manually from the panel dashboard if needed."
        fi
        return 1
    fi

    # 9. Reload and start
    if ! systemctl daemon-reload 2>/dev/null; then
        print_warn "systemctl daemon-reload failed — continuing anyway"
    fi
    print_info "Starting tunnel: ${tag}..."
    # Use restart (not start) to ensure the service override takes effect
    # If the tunnel was auto-started by dnstm, 'start' would be a no-op
    if systemctl restart "dnstm-${tag}.service" 2>/dev/null; then
        print_ok "Started: ${tag}"
    elif dnstm tunnel start --tag "$tag" 2>/dev/null; then
        print_ok "Started: ${tag}"
    else
        print_warn "Could not start tunnel. Check: dnstm tunnel logs --tag ${tag}"
    fi

    print_info "Restarting DNS Router..."
    dnstm router stop 2>/dev/null || true
    sleep 1
    if dnstm router start 2>/dev/null; then
        print_ok "DNS Router restarted"
    else
        print_warn "DNS Router restart may have issues. Check: dnstm router logs"
    fi

    # 10. Save config
    save_xray_config "$tag" || print_warn "Could not save Xray config (tunnel is running but config not persisted)"

    # 11. Show DNSTT public key
    local pubkey=""
    if [[ -f "/etc/dnstm/tunnels/${tag}/server.pub" ]]; then
        pubkey=$(cat "/etc/dnstm/tunnels/${tag}/server.pub" 2>/dev/null || true)
    fi

    # 12. Summary
    echo ""
    echo ""
    echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}${BOLD}  XRAY BACKEND TUNNEL CREATED  ${NC}"
    echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BOLD}Server Info${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  Server IP :  ${GREEN}${SERVER_IP}${NC}"
    echo -e "  Domain    :  ${GREEN}x.${DOMAIN}${NC}"
    echo -e "  Tag       :  ${GREEN}${tag}${NC}"
    echo ""
    echo -e "  ${BOLD}Xray Inbound${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  Protocol  :  ${GREEN}${XRAY_PROTOCOL}${NC}"
    echo -e "  Port      :  ${GREEN}${XRAY_INBOUND_PORT}${NC} ${DIM}(127.0.0.1 only)${NC}"
    if [[ -n "$XRAY_UUID" ]]; then
        echo -e "  UUID      :  ${GREEN}${XRAY_UUID}${NC}"
    fi
    if [[ -n "$XRAY_PASSWORD" ]]; then
        echo -e "  Password  :  ${GREEN}${XRAY_PASSWORD}${NC}"
    fi
    echo ""

    if [[ -n "$pubkey" ]]; then
        echo -e "  ${BOLD}DNSTT Public Key${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  ${GREEN}${pubkey}${NC}"
        echo ""
    fi

    # Generate client URI
    local credential
    if [[ -n "$XRAY_UUID" ]]; then
        credential="$XRAY_UUID"
    else
        credential="$XRAY_PASSWORD"
    fi
    # Use 127.0.0.1 as address — client connects through DNSTT tunnel (SlipNet),
    # so traffic exits on the server side where Xray listens on localhost only
    local client_uri
    client_uri=$(generate_xray_client_uri "$XRAY_PROTOCOL" "127.0.0.1" "$XRAY_INBOUND_PORT" "$credential" "DNSTT-${XRAY_PROTOCOL}")

    echo -e "  ${BOLD}Client URI (for Nekobox)${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}${client_uri}${NC}"
    echo ""

    # Generate slipnet:// URL for this tunnel (include SOCKS auth if configured)
    if [[ -n "$pubkey" ]]; then
        local s_user="" s_pass=""
        detect_socks_auth 2>/dev/null || true
        if [[ "${SOCKS_AUTH:-}" == true ]]; then
            s_user="${SOCKS_USER:-}"
            s_pass="${SOCKS_PASS:-}"
        fi
        local slipnet_url
        slipnet_url=$(generate_slipnet_url "dnstt" "x" "$pubkey" "" "" "$s_user" "$s_pass")
        echo -e "  ${BOLD}SlipNet URL (for DNSTT tunnel)${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  ${GREEN}${slipnet_url}${NC}"
        echo ""
    fi

    echo -e "  ${BOLD}Required DNS Record (Cloudflare)${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  Type: ${YELLOW}NS${NC}  │  Name: ${YELLOW}x${NC}  │  Value: ${YELLOW}ns.${DOMAIN}${NC}"
    echo -e "  ${DIM}Proxy: OFF (grey cloud)${NC}"
    echo ""

    echo -e "  ${BOLD}Client Setup (Nekobox + SlipNet)${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  ${DIM}1. Import SlipNet URL above into SlipNet app${NC}"
    echo -e "  ${DIM}2. Enable 'Proxy Only Mode' in SlipNet (SOCKS on 127.0.0.1:1080)${NC}"
    echo -e "  ${DIM}3. In Nekobox, add new proxy using the Client URI above${NC}"
    echo -e "  ${DIM}4. In Nekobox, chain it through SlipNet's SOCKS proxy${NC}"
    echo -e "  ${DIM}5. Enable 'UDP over TCP' in both configs${NC}"
    echo -e "  ${DIM}6. Bypass SlipNet from Nekobox routing to avoid loops${NC}"
    echo ""
    echo -e "  ${DIM}Management: sudo bash $0 --manage${NC}"
    echo -e "  ${DIM}Status:     sudo bash $0 --status${NC}"
    echo ""
}

# ─── --manage ────────────────────────────────────────────────────────────────────

do_manage() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "  ${CROSS} Not running as root. Please run with: sudo bash $0 --manage"
        exit 1
    fi

    if ! command -v dnstm &>/dev/null; then
        print_fail "dnstm is not installed. Run the full setup first: sudo bash $0"
        exit 1
    fi

    # Trap SIGINT in the parent so Ctrl+C only kills the subshell,
    # not the entire manage menu. Restore default trap on exit.
    trap '' INT

    while true; do
        banner
        print_header "Management Menu"
        echo ""

        echo -e "  ${BOLD}1)${NC}  Show status          ${DIM}(tunnels, credentials, share URLs)${NC}"
        echo -e "  ${BOLD}2)${NC}  Add tunnel            ${DIM}(single tunnel — pick transport & backend)${NC}"
        echo -e "  ${BOLD}3)${NC}  Remove tunnel         ${DIM}(pick one to remove)${NC}"
        echo -e "  ${BOLD}4)${NC}  Add backup domain     ${DIM}(new domain → 4 more tunnels)${NC}"
        echo -e "  ${BOLD}5)${NC}  Manage SSH users      ${DIM}(add, list, update, delete)${NC}"
        echo -e "  ${BOLD}6)${NC}  Configure SOCKS auth  ${DIM}(enable, disable, or change credentials)${NC}"
        echo -e "  ${BOLD}7)${NC}  Apply hardening       ${DIM}(systemd security for all services)${NC}"
        echo -e "  ${BOLD}8)${NC}  Xray backend          ${DIM}(connect 3x-ui panel via DNS tunnel)${NC}"
        echo ""
        echo -e "  ${DIM}──────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}${RED}9)${NC}  ${RED}Uninstall everything${NC}"
        echo ""
        echo -e "  ${BOLD}0)${NC}  Exit"
        echo ""

        local choice=""
        read -rp "  Select [0-9]: " choice || break

        case "$choice" in
            1)
                ( trap - INT; do_status )  || true
                ;;
            2)
                ( trap - INT; do_add_tunnel ) || true
                ;;
            3)
                ( trap - INT; do_remove_tunnel "" ) || true
                ;;
            4)
                ( trap - INT; do_add_domain ) || true
                ;;
            5)
                ( trap - INT; do_manage_users ) || true
                ;;
            6)
                ( trap - INT; do_configure_socks_auth ) || true
                ;;
            7)
                ( trap - INT; do_harden ) || true
                ;;
            8)
                ( trap - INT; do_add_xray ) || true
                ;;
            9)
                ( trap - INT; do_uninstall ) || true
                # If uninstall succeeded, dnstm is gone — exit menu
                hash -d dnstm 2>/dev/null || true
                if ! command -v dnstm &>/dev/null; then
                    echo ""
                    print_info "dnstm has been uninstalled. Exiting menu."
                    break
                fi
                ;;
            0|q|Q)
                echo ""
                break
                ;;
            "")
                # Just Enter — redraw menu
                continue
                ;;
            *)
                print_warn "Invalid choice. Enter 0-9."
                sleep 1
                continue
                ;;
        esac

        # Pause so user can read output before menu redraws
        echo ""
        echo -e "  ${DIM}Press Enter to return to menu...${NC}"
        read -r || break
    done

    # Restore default SIGINT handling
    trap - INT
}

# ─── Global Variables (must be set before arg parser since --status/--manage use them) ───

DOMAIN=""
SERVER_IP=""
DNSTT_PUBKEY=""
NOIZDNS_PUBKEY=""
SSH_USER=""
SSH_PASS=""
SOCKS_USER=""
SOCKS_PASS=""
SOCKS_AUTH=false
TUNNELS_CHANGED=false

# ─── Variables (populated during setup) ─────────────────────────────────────────

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
        elif [[ "$DOMAIN" =~ \.\. ]]; then
            print_fail "Invalid domain (consecutive dots not allowed). Please try again."
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
        "Record 2:  Type: NS  | Name: t   | Value: ns.${DOMAIN}" \
        "Record 3:  Type: NS  | Name: d   | Value: ns.${DOMAIN}" \
        "Record 4:  Type: NS  | Name: s   | Value: ns.${DOMAIN}" \
        "Record 5:  Type: NS  | Name: ds  | Value: ns.${DOMAIN}" \
        "Record 6:  Type: NS  | Name: n   | Value: ns.${DOMAIN}" \
        "Record 7:  Type: NS  | Name: z   | Value: ns.${DOMAIN}"

    echo ""
    print_warn "IMPORTANT: The A record MUST be DNS Only (grey cloud, NOT orange)"
    print_warn "IMPORTANT: The A record name must be \"ns\" (not \"tns\")"
    echo ""
    echo "  Subdomain purposes:"
    echo "    t   = Slipstream + SOCKS tunnel"
    echo "    d   = DNSTT + SOCKS tunnel"
    echo "    n   = NoizDNS + SOCKS tunnel (DPI-resistant)"
    echo "    s   = Slipstream + SSH tunnel"
    echo "    ds  = DNSTT + SSH tunnel"
    echo "    z   = NoizDNS + SSH tunnel (DPI-resistant)"
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
    local arch
    arch=$(detect_architecture)
    if curl -fsSL -o /usr/local/bin/dnstm "https://github.com/net2share/dnstm/releases/latest/download/dnstm-linux-${arch}"; then
        chmod +x /usr/local/bin/dnstm
        print_ok "Downloaded dnstm binary for ${arch}"
    else
        print_fail "Failed to download dnstm for ${arch} architecture"
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

    # Download NoizDNS server binary (DPI-resistant DNSTT fork)
    echo ""
    print_info "Downloading NoizDNS server (DPI-resistant tunnel)..."
    # NoizDNS uses "arm" not "armv7" for ARM builds
    local noizdns_arch="$arch"
    [[ "$noizdns_arch" == "armv7" ]] && noizdns_arch="arm"
    local noizdns_url="https://raw.githubusercontent.com/anonvector/noizdns-deploy/main/bin/dnstt-server-linux-${noizdns_arch}"
    if curl -fsSL -o /usr/local/bin/noizdns-server "$noizdns_url" 2>/dev/null; then
        chmod +x /usr/local/bin/noizdns-server
        print_ok "NoizDNS server installed"
    else
        print_warn "Could not download NoizDNS server (NoizDNS tunnels will be skipped)"
    fi
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
    local _tunnel_count=4
    [[ -x /usr/local/bin/noizdns-server ]] && _tunnel_count=6
    print_info "Creating ${_tunnel_count} tunnels for domain: ${BOLD}${DOMAIN}${NC}"
    echo ""

    # Ask for DNSTT MTU (use CLI value as default if provided via --mtu)
    local mtu_input
    mtu_input=$(prompt_input "DNSTT MTU size (512-1400, affects packet size)" "$DNSTT_MTU")
    if [[ "$mtu_input" =~ ^[0-9]+$ ]] && [[ "$mtu_input" -ge 512 ]] && [[ "$mtu_input" -le 1400 ]]; then
        DNSTT_MTU="$mtu_input"
    else
        print_warn "Invalid MTU value; using default ${DNSTT_MTU}"
    fi
    print_ok "DNSTT MTU: ${DNSTT_MTU}"
    echo ""

    # Tunnel 1: Slipstream + SOCKS
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel 1: Slipstream + SOCKS${NC}"
    echo ""
    if dnstm tunnel add --transport slipstream --backend socks --domain "t.${DOMAIN}" --tag slip1 2>&1; then
        print_ok "Created: slip1 (Slipstream + SOCKS) on t.${DOMAIN}"
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
    dnstt_output=$(dnstm tunnel add --transport dnstt --backend socks --domain "d.${DOMAIN}" --tag dnstt1 --mtu "$DNSTT_MTU" 2>&1) || true
    echo "$dnstt_output"

    # Try to extract DNSTT public key
    DNSTT_PUBKEY=""
    if [[ -f /etc/dnstm/tunnels/dnstt1/server.pub ]]; then
        DNSTT_PUBKEY=$(cat /etc/dnstm/tunnels/dnstt1/server.pub 2>/dev/null || true)
    fi

    if [[ -n "$DNSTT_PUBKEY" ]]; then
        print_ok "Created: dnstt1 (DNSTT + SOCKS) on d.${DOMAIN}"
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
    if dnstm tunnel add --transport slipstream --backend ssh --domain "s.${DOMAIN}" --tag slip-ssh 2>&1; then
        print_ok "Created: slip-ssh (Slipstream + SSH) on s.${DOMAIN}"
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
    if dnstm tunnel add --transport dnstt --backend ssh --domain "ds.${DOMAIN}" --tag dnstt-ssh --mtu "$DNSTT_MTU" 2>&1; then
        print_ok "Created: dnstt-ssh (DNSTT + SSH) on ds.${DOMAIN}"
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

    # ─── NoizDNS tunnels (5 & 6) ───
    if [[ -x /usr/local/bin/noizdns-server ]]; then
        echo ""
        echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}Tunnel 5: NoizDNS + SOCKS (DPI-resistant)${NC}"
        echo ""
        if dnstm tunnel add --transport dnstt --backend socks --domain "n.${DOMAIN}" --tag noiz1 --mtu "$DNSTT_MTU" 2>&1; then
            print_ok "Created: noiz1 (NoizDNS + SOCKS) on n.${DOMAIN}"
            any_created=true
        else
            print_warn "Tunnel noiz1 may already exist or creation failed"
        fi
        # Override binary to use noizdns-server
        create_noizdns_service_override "noiz1" || print_warn "Could not set NoizDNS binary for noiz1"
        echo ""

        # Extract NoizDNS pubkey
        if [[ -f /etc/dnstm/tunnels/noiz1/server.pub ]]; then
            NOIZDNS_PUBKEY=$(cat /etc/dnstm/tunnels/noiz1/server.pub 2>/dev/null || true)
            if [[ -n "$NOIZDNS_PUBKEY" ]]; then
                echo -e "  ${BOLD}${YELLOW}NoizDNS Public Key:${NC}"
                echo -e "  ${GREEN}${NOIZDNS_PUBKEY}${NC}"
            fi
        fi

        echo ""
        echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}Tunnel 6: NoizDNS + SSH (DPI-resistant)${NC}"
        echo ""
        if dnstm tunnel add --transport dnstt --backend ssh --domain "z.${DOMAIN}" --tag noiz-ssh --mtu "$DNSTT_MTU" 2>&1; then
            print_ok "Created: noiz-ssh (NoizDNS + SSH) on z.${DOMAIN}"
            any_created=true
        else
            print_warn "Tunnel noiz-ssh may already exist or creation failed"
        fi
        # Override binary to use noizdns-server
        create_noizdns_service_override "noiz-ssh" || print_warn "Could not set NoizDNS binary for noiz-ssh"
        echo ""
    else
        echo ""
        print_warn "NoizDNS binary not available — skipping NoizDNS tunnels (n, z subdomains)"
    fi

    # Re-read NoizDNS key if not captured (e.g., tunnel already existed)
    if [[ -z "$NOIZDNS_PUBKEY" && -f /etc/dnstm/tunnels/noiz1/server.pub ]]; then
        NOIZDNS_PUBKEY=$(cat /etc/dnstm/tunnels/noiz1/server.pub 2>/dev/null || true)
    fi

    if [[ "$any_created" == true ]]; then
        TUNNELS_CHANGED=true
    fi
    print_ok "All tunnels created"
}

# ─── STEP 8: Start Services ────────────────────────────────────────────────────

step_start_services() {
    print_step 8 "Start Services"

    # Reload systemd to pick up any service overrides (e.g., NoizDNS binary swap)
    systemctl daemon-reload 2>/dev/null || true

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
        [[ -x /usr/local/bin/noizdns-server ]] && all_tags+=" noiz1 noiz-ssh"
    fi
    for tag in $all_tags; do
        print_info "Starting tunnel: ${tag}..."
        if dnstm tunnel start --tag "$tag" 2>/dev/null; then
            print_ok "Started: ${tag}"
        else
            if dnstm tunnel list 2>/dev/null | awk -v t="tag=${tag}" '{for(i=1;i<=NF;i++) if($i==t){print;next}}' | grep -qi "running"; then
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

    # Ask about SOCKS authentication
    echo ""
    print_info "SOCKS tunnels (t/d) currently have no authentication."
    print_info "Adding authentication makes the proxy secure — only clients with"
    print_info "the correct username and password can connect."
    echo ""
    if prompt_yn "Enable SOCKS5 authentication for the proxy?" "y"; then
        echo ""
        SOCKS_USER=$(prompt_input "Enter SOCKS proxy username" "proxy")
        SOCKS_USER=$(echo "$SOCKS_USER" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -z "$SOCKS_USER" ]]; then
            print_fail "Username cannot be empty"
            SOCKS_USER="proxy"
        fi
        # Reject pipe and colon in username (breaks slipnet URL format and curl --proxy-user)
        if [[ "$SOCKS_USER" == *"|"* || "$SOCKS_USER" == *":"* ]]; then
            print_warn "Username cannot contain | or : characters — using default 'proxy'"
            SOCKS_USER="proxy"
        fi
        SOCKS_PASS=$(prompt_input "Enter SOCKS proxy password")
        SOCKS_PASS=$(echo "$SOCKS_PASS" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -z "$SOCKS_PASS" ]]; then
            print_fail "Password cannot be empty — disabling SOCKS auth"
            SOCKS_USER=""
            SOCKS_PASS=""
        # Reject pipe in password (breaks slipnet URL pipe-delimited format)
        elif [[ "$SOCKS_PASS" == *"|"* ]]; then
            print_fail "Password cannot contain the | character — disabling SOCKS auth"
            SOCKS_USER=""
            SOCKS_PASS=""
        else
            SOCKS_AUTH=true
            print_ok "SOCKS authentication enabled (user: ${SOCKS_USER})"
        fi
    else
        print_warn "SOCKS proxy will run without authentication (open to anyone who knows the domain)"
    fi
    echo ""

    # Check if microsocks is running (dnstm manages the binary and service)
    local microsocks_running=false
    if pgrep -x microsocks &>/dev/null || systemctl is-active --quiet microsocks 2>/dev/null; then
        print_ok "microsocks is running"
        microsocks_running=true
    else
        print_warn "microsocks is not running"
        print_info "Starting microsocks..."

        systemctl enable microsocks 2>/dev/null || true
        if systemctl start microsocks 2>/dev/null; then
            sleep 1
            if pgrep -x microsocks &>/dev/null; then
                print_ok "microsocks started"
                microsocks_running=true
            else
                # May have crashed immediately — check for GLIBC issue
                if ! microsocks_binary_works; then
                    print_warn "microsocks crashed (GLIBC incompatibility detected)"
                    if compile_microsocks_from_source; then
                        microsocks_running=true
                    fi
                else
                    print_fail "Failed to start microsocks"
                    print_info "Check: systemctl status microsocks"
                fi
            fi
        else
            # systemctl start failed — check for GLIBC issue
            if ! microsocks_binary_works; then
                print_warn "microsocks binary incompatible — compiling from source..."
                if compile_microsocks_from_source; then
                    microsocks_running=true
                fi
            else
                print_fail "Failed to start microsocks"
                print_info "Check: systemctl status microsocks"
            fi
        fi
    fi

    # Apply SOCKS authentication via dnstm (v0.6.8+) — only if microsocks is running
    if [[ "$microsocks_running" == true && "$SOCKS_AUTH" == true && -n "$SOCKS_USER" && -n "$SOCKS_PASS" ]]; then
        print_info "Configuring SOCKS5 authentication via dnstm..."
        if dnstm backend auth -t socks -u "$SOCKS_USER" -p "$SOCKS_PASS"; then
            print_ok "SOCKS5 authentication enabled (user: ${SOCKS_USER})"
            # dnstm backend auth rewrites ExecStart and restarts microsocks;
            # give it a moment to come back up
            sleep 2
            if pgrep -x microsocks &>/dev/null || systemctl is-active --quiet microsocks 2>/dev/null; then
                print_ok "microsocks restarted with authentication"
            else
                print_warn "microsocks may not have restarted — check: systemctl status microsocks"
            fi
        else
            print_warn "Failed to configure SOCKS5 authentication via dnstm"
            print_info "Try manually: dnstm backend auth -t socks -u ${SOCKS_USER} -p <password>"
            SOCKS_AUTH=false
        fi
    fi

    if [[ "$microsocks_running" != true ]]; then
        print_warn "Skipping SOCKS proxy test — microsocks is not running"
        return
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
    if [[ "$SOCKS_AUTH" == true ]]; then
        test_ip=$(curl -s --max-time 10 --socks5-basic --proxy "socks5://127.0.0.1:${socks_port}" --proxy-user "${SOCKS_USER}:${SOCKS_PASS}" https://api.ipify.org 2>/dev/null || true)
    else
        test_ip=$(curl -s --max-time 10 --socks5 "127.0.0.1:${socks_port}" https://api.ipify.org 2>/dev/null || true)
    fi

    if [[ -n "$test_ip" ]]; then
        print_ok "SOCKS proxy works! Response: ${test_ip}"
    else
        print_warn "SOCKS proxy test failed (this may be OK if internet is restricted)"
        print_info "The proxy may still work for DNS tunnel clients"
    fi

    # Negative test: verify unauthenticated access is rejected when auth is enabled
    if [[ "$SOCKS_AUTH" == true && -n "$test_ip" ]]; then
        local noauth_ip
        noauth_ip=$(curl -s --max-time 5 --socks5 "127.0.0.1:${socks_port}" https://api.ipify.org 2>/dev/null || true)
        if [[ -z "$noauth_ip" ]]; then
            print_ok "Auth enforced: unauthenticated connections are rejected"
        else
            print_warn "Auth NOT enforced: proxy works without credentials!"
            print_info "Try: dnstm backend auth -t socks -u ${SOCKS_USER} -p <password>"
        fi
    fi
}

# ─── STEP 10: SSH User (Optional) ──────────────────────────────────────────────

step_ssh_user() {
    print_step 10 "SSH Tunnel User"

    print_info "An SSH tunnel user allows clients to connect via Slipstream + SSH or DNSTT + SSH."
    print_info "This user can only create tunnels and has no shell access."
    print_warn "Without an SSH tunnel user, the SSH tunnels (s/ds) will NOT work."
    echo ""

    if ! prompt_yn "Create an SSH tunnel user? (required for SSH tunnels to work)" "y"; then
        print_warn "Skipping SSH user setup — SSH tunnels (s.${DOMAIN}, ds.${DOMAIN}) will not work"
        print_info "You can create one later with: sshtun-user create <username> --insecure-password <pass>"
        return
    fi

    echo ""

    # Install sshtun-user if not present
    if ! command -v sshtun-user &>/dev/null; then
        print_info "Downloading sshtun-user..."
        local arch
        arch=$(detect_architecture)
        if curl -fsSL -o /usr/local/bin/sshtun-user "https://github.com/net2share/sshtun-user/releases/latest/download/sshtun-user-linux-${arch}"; then
            chmod +x /usr/local/bin/sshtun-user
            print_ok "Downloaded sshtun-user for ${arch}"
        else
            print_fail "Failed to download sshtun-user for ${arch} architecture"
            return
        fi
    else
        print_ok "sshtun-user already installed"
    fi

    # Configure SSH (only needed once)
    print_info "Applying SSH security configuration..."
    mkdir -p /run/sshd 2>/dev/null || true
    local configure_output
    configure_output=$(timeout 30 sshtun-user configure </dev/null 2>&1) || true
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
    SSH_USER=$(echo "$SSH_USER" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -z "$SSH_USER" ]]; then
        print_fail "Username cannot be empty"
        return
    fi
    if [[ "$SSH_USER" == *"|"* ]]; then
        print_fail "Username cannot contain the | character"
        return
    fi

    # Get password
    SSH_PASS=$(prompt_input "Enter password for SSH tunnel user")
    SSH_PASS=$(echo "$SSH_PASS" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -z "$SSH_PASS" ]]; then
        print_fail "Password cannot be empty"
        return
    fi
    if [[ "$SSH_PASS" == *"|"* ]]; then
        print_fail "Password cannot contain the | character"
        return
    fi

    echo ""

    # Create user
    print_info "Creating SSH tunnel user: ${SSH_USER}..."
    if timeout 30 sshtun-user create "$SSH_USER" --insecure-password "$SSH_PASS" </dev/null 2>&1; then
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
    if [[ "$SOCKS_AUTH" == true ]]; then
        socks_result=$(curl -s --max-time 10 --socks5-basic --proxy "socks5://127.0.0.1:${socks_port}" --proxy-user "${SOCKS_USER}:${SOCKS_PASS}" https://api.ipify.org 2>/dev/null || true)
    else
        socks_result=$(curl -s --max-time 10 --socks5 "127.0.0.1:${socks_port}" https://api.ipify.org 2>/dev/null || true)
    fi
    if [[ -n "$socks_result" ]]; then
        print_ok "SOCKS proxy: PASS (IP: ${socks_result}) on port ${socks_port}"
        pass=$((pass + 1))
        # Verify auth enforcement
        if [[ "$SOCKS_AUTH" == true ]]; then
            local noauth_result
            noauth_result=$(curl -s --max-time 5 --socks5 "127.0.0.1:${socks_port}" https://api.ipify.org 2>/dev/null || true)
            if [[ -z "$noauth_result" ]]; then
                print_ok "SOCKS auth enforcement: PASS (unauthenticated rejected)"
                pass=$((pass + 1))
            else
                print_fail "SOCKS auth enforcement: FAIL (works without credentials!)"
                fail=$((fail + 1))
            fi
        fi
    elif ss -tlnp 2>/dev/null | grep -q "microsocks"; then
        print_warn "SOCKS proxy: LISTENING on port ${socks_port} but connectivity test failed"
        print_info "microsocks is running but outbound may be blocked or tunnels not ready"
        fail=$((fail + 1))
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
        local expected_tunnels=4
        [[ -x /usr/local/bin/noizdns-server ]] && expected_tunnels=6
        if [[ "$running_count" -ge "$expected_tunnels" ]]; then
            print_ok "All tunnels running: PASS (${running_count} running)"
            pass=$((pass + 1))
        elif [[ "$running_count" -ge 1 ]]; then
            print_warn "Some tunnels running: ${running_count}/${expected_tunnels}"
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
        dig_result=$(dig +short +timeout=5 +tries=1 "dnstm-test.t.${DOMAIN}" @8.8.8.8 2>/dev/null || true)
        if [[ -n "$dig_result" ]]; then
            print_ok "DNS delegation: PASS (query reached server via 8.8.8.8)"
            pass=$((pass + 1))
        else
            # Try Cloudflare resolver as fallback
            dig_result=$(dig +short +timeout=5 +tries=1 "dnstm-test.t.${DOMAIN}" @1.1.1.1 2>/dev/null || true)
            if [[ -n "$dig_result" ]]; then
                print_ok "DNS delegation: PASS (query reached server via 1.1.1.1)"
                pass=$((pass + 1))
            else
                print_warn "DNS delegation: No response from public resolvers"
                print_info "This may mean DNS records are not set up correctly in Cloudflare,"
                print_info "or it may take a few minutes for DNS to propagate."
                print_info "Test manually: dig t.${DOMAIN} @8.8.8.8"
                fail=$((fail + 1))
            fi
        fi
    else
        print_info "DNS delegation: SKIPPED (dig not installed — install with: apt install dnsutils)"
        print_info "Test manually: nslookup t.${DOMAIN} 8.8.8.8"
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
            print_warn "SSH: sshd running but no tunnel user created — SSH tunnels (s/ds) will not work"
            print_info "Create one with: sshtun-user create <username> --insecure-password <pass>"
            fail=$((fail + 1))
        fi
    else
        print_warn "SSH: sshd not detected on port 22 — SSH tunnels (s/ds) will not work"
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
    echo -e "  Slipstream + SOCKS:  ${GREEN}t.${DOMAIN}${NC}"
    echo -e "  DNSTT + SOCKS:       ${GREEN}d.${DOMAIN}${NC}"
    if [[ -x /usr/local/bin/noizdns-server ]]; then
        echo -e "  NoizDNS + SOCKS:     ${GREEN}n.${DOMAIN}${NC}  ${DIM}(DPI-resistant)${NC}"
    fi
    echo -e "  Slipstream + SSH:    ${GREEN}s.${DOMAIN}${NC}"
    echo -e "  DNSTT + SSH:         ${GREEN}ds.${DOMAIN}${NC}"
    if [[ -x /usr/local/bin/noizdns-server ]]; then
        echo -e "  NoizDNS + SSH:       ${GREEN}z.${DOMAIN}${NC}  ${DIM}(DPI-resistant)${NC}"
    fi
    echo ""

    if [[ -n "$DNSTT_PUBKEY" ]]; then
        echo -e "  ${BOLD}DNSTT Public Keys${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  ${GREEN}dnstt1 (SOCKS):${NC}  ${DNSTT_PUBKEY}"
        local _dnstt_ssh_pk=""
        if [[ -f /etc/dnstm/tunnels/dnstt-ssh/server.pub ]]; then
            _dnstt_ssh_pk=$(cat /etc/dnstm/tunnels/dnstt-ssh/server.pub 2>/dev/null || true)
        fi
        if [[ -n "$_dnstt_ssh_pk" ]]; then
            echo -e "  ${GREEN}dnstt-ssh (SSH):${NC} ${_dnstt_ssh_pk}"
        fi
        echo ""
    fi

    if [[ -n "$NOIZDNS_PUBKEY" ]]; then
        echo -e "  ${BOLD}NoizDNS Public Keys${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  ${GREEN}noiz1 (SOCKS):${NC}   ${NOIZDNS_PUBKEY}"
        local _noiz_ssh_pk=""
        if [[ -f /etc/dnstm/tunnels/noiz-ssh/server.pub ]]; then
            _noiz_ssh_pk=$(cat /etc/dnstm/tunnels/noiz-ssh/server.pub 2>/dev/null || true)
        fi
        if [[ -n "$_noiz_ssh_pk" ]]; then
            echo -e "  ${GREEN}noiz-ssh (SSH):${NC}  ${_noiz_ssh_pk}"
        fi
        echo ""
    fi

    # Generate share URLs (dnst:// for dnstc CLI)
    echo -e "  ${BOLD}Share URLs — dnst:// (for dnstc CLI)${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    local share_url
    for tag in slip1 dnstt1 noiz1; do
        share_url=$(dnstm tunnel share -t "$tag" 2>/dev/null || true)
        if [[ -n "$share_url" ]]; then
            echo -e "  ${GREEN}${tag}:${NC} ${share_url}"
        fi
    done
    if [[ "$SSH_SETUP_DONE" == true && -n "$SSH_USER" && -n "$SSH_PASS" ]]; then
        for tag in slip-ssh dnstt-ssh noiz-ssh; do
            share_url=$(dnstm tunnel share -t "$tag" --user "$SSH_USER" --password "$SSH_PASS" 2>/dev/null || true)
            if [[ -n "$share_url" ]]; then
                echo -e "  ${GREEN}${tag}:${NC} ${share_url}"
            fi
        done
    fi
    echo ""

    # Generate SlipNet deep-link URLs (slipnet:// for SlipNet Android app)
    echo -e "  ${BOLD}Share URLs — slipnet:// (for SlipNet app)${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    local slipnet_url
    local s_user="" s_pass=""
    if [[ "$SOCKS_AUTH" == true ]]; then
        s_user="$SOCKS_USER"
        s_pass="$SOCKS_PASS"
    fi
    # Slipstream + SOCKS
    slipnet_url=$(generate_slipnet_url "ss" "t" "" "" "" "$s_user" "$s_pass")
    echo -e "  ${GREEN}slip1:${NC}    ${slipnet_url}"
    # DNSTT + SOCKS
    if [[ -n "$DNSTT_PUBKEY" ]]; then
        slipnet_url=$(generate_slipnet_url "dnstt" "d" "$DNSTT_PUBKEY" "" "" "$s_user" "$s_pass")
        echo -e "  ${GREEN}dnstt1:${NC}    ${slipnet_url}"
    fi
    # NoizDNS + SOCKS
    if [[ -n "$NOIZDNS_PUBKEY" ]]; then
        slipnet_url=$(generate_slipnet_url "sayedns" "n" "$NOIZDNS_PUBKEY" "" "" "$s_user" "$s_pass")
        echo -e "  ${GREEN}noiz1:${NC}     ${slipnet_url}"
    fi
    # SSH tunnels
    if [[ "$SSH_SETUP_DONE" == true && -n "$SSH_USER" && -n "$SSH_PASS" ]]; then
        slipnet_url=$(generate_slipnet_url "slipstream_ssh" "s" "" "$SSH_USER" "$SSH_PASS" "$s_user" "$s_pass")
        echo -e "  ${GREEN}slip-ssh:${NC}  ${slipnet_url}"
        # dnstt-ssh has its own keypair
        local dnstt_ssh_pubkey=""
        if [[ -f /etc/dnstm/tunnels/dnstt-ssh/server.pub ]]; then
            dnstt_ssh_pubkey=$(cat /etc/dnstm/tunnels/dnstt-ssh/server.pub 2>/dev/null || true)
        fi
        if [[ -n "$dnstt_ssh_pubkey" ]]; then
            slipnet_url=$(generate_slipnet_url "dnstt_ssh" "ds" "$dnstt_ssh_pubkey" "$SSH_USER" "$SSH_PASS" "$s_user" "$s_pass")
            echo -e "  ${GREEN}dnstt-ssh:${NC} ${slipnet_url}"
        fi
        # NoizDNS + SSH
        local noiz_ssh_pubkey=""
        if [[ -f /etc/dnstm/tunnels/noiz-ssh/server.pub ]]; then
            noiz_ssh_pubkey=$(cat /etc/dnstm/tunnels/noiz-ssh/server.pub 2>/dev/null || true)
        fi
        if [[ -n "$noiz_ssh_pubkey" ]]; then
            slipnet_url=$(generate_slipnet_url "sayedns_ssh" "z" "$noiz_ssh_pubkey" "$SSH_USER" "$SSH_PASS" "$s_user" "$s_pass")
            echo -e "  ${GREEN}noiz-ssh:${NC}  ${slipnet_url}"
        fi
    fi
    echo ""

    if [[ "$SOCKS_AUTH" == true ]]; then
        echo -e "  ${BOLD}SOCKS Proxy Authentication${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  Username:  ${GREEN}${SOCKS_USER}${NC}"
        echo -e "  Password:  ${GREEN}${SOCKS_PASS}${NC}"
        echo ""
    else
        echo -e "  ${BOLD}SOCKS Proxy Authentication${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  ${YELLOW}⚠ No authentication — SOCKS tunnels (t/d) are open${NC}"
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
        echo -e "  ${YELLOW}⚠ Not configured — SSH tunnels (s/ds) will not work${NC}"
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
    echo "  dnstm tunnel share -t <tag>     Generate share URL"
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

    # Use domain from argument if provided, otherwise prompt
    if [[ -n "$ADD_DOMAIN_ARG" ]]; then
        DOMAIN="$ADD_DOMAIN_ARG"
        DOMAIN=$(echo "$DOMAIN" | sed 's|^[[:space:]]*||;s|[[:space:]]*$||;s|^https\?://||;s|/.*$||')
        if [[ -z "$DOMAIN" ]] || [[ ! "$DOMAIN" =~ \. ]]; then
            print_fail "Invalid domain: ${ADD_DOMAIN_ARG}"
            exit 1
        fi
        if [[ -n "$existing_domains" ]] && echo "$existing_domains" | grep -qx "$DOMAIN"; then
            print_fail "Domain '${DOMAIN}' is already in use by an existing tunnel."
            exit 1
        fi
    else
        # Interactive prompt — reopen /dev/tty in case stdin is a pipe
        while true; do
            echo -ne "  ${BOLD}Enter the new backup domain (e.g. backup.com)${NC} ${DIM}(h=help)${NC}: " >&2
            read -r DOMAIN </dev/tty || { print_fail "Cannot read input (stdin is a pipe). Pass domain as argument: --add-domain example.com"; exit 1; }
            DOMAIN=$(echo "$DOMAIN" | sed 's|^[[:space:]]*||;s|[[:space:]]*$||;s|^https\?://||;s|/.*$||')
            if [[ -z "$DOMAIN" ]]; then
                print_fail "Domain cannot be empty. Please try again."
            elif [[ ! "$DOMAIN" =~ \. ]]; then
                print_fail "Invalid domain (must contain a dot). Please try again."
            elif [[ "$DOMAIN" =~ \.\. ]]; then
                print_fail "Invalid domain (consecutive dots not allowed). Please try again."
            elif [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
                print_fail "Invalid domain (use only letters, numbers, dots, hyphens). Please try again."
            elif [[ -n "$existing_domains" ]] && echo "$existing_domains" | grep -qx "$DOMAIN"; then
                print_fail "Domain '${DOMAIN}' is already in use by an existing tunnel. Please enter a different domain."
            else
                break
            fi
        done
    fi

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
        "Record 2:  Type: NS  | Name: t   | Value: ns.${DOMAIN}" \
        "Record 3:  Type: NS  | Name: d   | Value: ns.${DOMAIN}" \
        "Record 4:  Type: NS  | Name: s   | Value: ns.${DOMAIN}" \
        "Record 5:  Type: NS  | Name: ds  | Value: ns.${DOMAIN}" \
        "Record 6:  Type: NS  | Name: n   | Value: ns.${DOMAIN}" \
        "Record 7:  Type: NS  | Name: z   | Value: ns.${DOMAIN}"

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

    # Detect existing SOCKS authentication via dnstm
    if detect_socks_auth; then
        print_ok "Detected existing SOCKS authentication (user: ${SOCKS_USER})"
    else
        print_info "SOCKS proxy has no authentication configured"
    fi
    echo ""

    # Ask for DNSTT MTU (use CLI value as default if provided via --mtu)
    local mtu_input
    mtu_input=$(prompt_input "DNSTT MTU size (512-1400, affects packet size)" "$DNSTT_MTU")
    if [[ "$mtu_input" =~ ^[0-9]+$ ]] && [[ "$mtu_input" -ge 512 ]] && [[ "$mtu_input" -le 1400 ]]; then
        DNSTT_MTU="$mtu_input"
    else
        print_warn "Invalid MTU value; using default ${DNSTT_MTU}"
    fi
    print_ok "DNSTT MTU: ${DNSTT_MTU}"
    echo ""

    # Tunnel 1: Slipstream + SOCKS
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel: Slipstream + SOCKS${NC}"
    echo ""
    if dnstm tunnel add --transport slipstream --backend socks --domain "t.${DOMAIN}" --tag "$slip_tag" 2>&1; then
        print_ok "Created: ${slip_tag} (Slipstream + SOCKS) on t.${DOMAIN}"
    else
        print_warn "Tunnel ${slip_tag} may already exist or creation failed"
    fi
    echo ""

    # Tunnel 2: DNSTT + SOCKS
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel: DNSTT + SOCKS${NC}"
    echo ""
    local dnstt_output
    dnstt_output=$(dnstm tunnel add --transport dnstt --backend socks --domain "d.${DOMAIN}" --tag "$dnstt_tag" --mtu "$DNSTT_MTU" 2>&1) || true
    echo "$dnstt_output"

    DNSTT_PUBKEY=""
    if [[ -f "/etc/dnstm/tunnels/${dnstt_tag}/server.pub" ]]; then
        DNSTT_PUBKEY=$(cat "/etc/dnstm/tunnels/${dnstt_tag}/server.pub" 2>/dev/null || true)
    fi

    if [[ -n "$DNSTT_PUBKEY" ]]; then
        print_ok "Created: ${dnstt_tag} (DNSTT + SOCKS) on d.${DOMAIN}"
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
    if dnstm tunnel add --transport slipstream --backend ssh --domain "s.${DOMAIN}" --tag "$slip_ssh_tag" 2>&1; then
        print_ok "Created: ${slip_ssh_tag} (Slipstream + SSH) on s.${DOMAIN}"
    else
        print_warn "Tunnel ${slip_ssh_tag} may already exist or creation failed"
    fi
    echo ""

    # Tunnel 4: DNSTT + SSH
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel: DNSTT + SSH${NC}"
    echo ""
    if dnstm tunnel add --transport dnstt --backend ssh --domain "ds.${DOMAIN}" --tag "$dnstt_ssh_tag" --mtu "$DNSTT_MTU" 2>&1; then
        print_ok "Created: ${dnstt_ssh_tag} (DNSTT + SSH) on ds.${DOMAIN}"
    else
        print_warn "Tunnel ${dnstt_ssh_tag} may already exist or creation failed"
    fi
    echo ""

    # Re-read DNSTT key if not captured
    if [[ -z "$DNSTT_PUBKEY" && -f "/etc/dnstm/tunnels/${dnstt_tag}/server.pub" ]]; then
        DNSTT_PUBKEY=$(cat "/etc/dnstm/tunnels/${dnstt_tag}/server.pub" 2>/dev/null || true)
    fi

    # NoizDNS tunnels (if binary available)
    if [[ -x /usr/local/bin/noizdns-server ]]; then
        local noiz_tag="noiz${num}"
        local noiz_ssh_tag="noiz-ssh${num}"

        echo ""
        echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}Tunnel: NoizDNS + SOCKS (DPI-resistant)${NC}"
        echo ""
        if dnstm tunnel add --transport dnstt --backend socks --domain "n.${DOMAIN}" --tag "$noiz_tag" --mtu "$DNSTT_MTU" 2>&1; then
            print_ok "Created: ${noiz_tag} (NoizDNS + SOCKS) on n.${DOMAIN}"
        else
            print_warn "Tunnel ${noiz_tag} may already exist or creation failed"
        fi
        create_noizdns_service_override "$noiz_tag" || print_warn "Could not set NoizDNS binary for ${noiz_tag}"

        # Extract NoizDNS pubkey
        if [[ -f "/etc/dnstm/tunnels/${noiz_tag}/server.pub" ]]; then
            NOIZDNS_PUBKEY=$(cat "/etc/dnstm/tunnels/${noiz_tag}/server.pub" 2>/dev/null || true)
        fi
        echo ""

        echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}Tunnel: NoizDNS + SSH (DPI-resistant)${NC}"
        echo ""
        if dnstm tunnel add --transport dnstt --backend ssh --domain "z.${DOMAIN}" --tag "$noiz_ssh_tag" --mtu "$DNSTT_MTU" 2>&1; then
            print_ok "Created: ${noiz_ssh_tag} (NoizDNS + SSH) on z.${DOMAIN}"
        else
            print_warn "Tunnel ${noiz_ssh_tag} may already exist or creation failed"
        fi
        create_noizdns_service_override "$noiz_ssh_tag" || print_warn "Could not set NoizDNS binary for ${noiz_ssh_tag}"
        echo ""
    fi

    print_ok "All tunnels created"
    echo ""

    # Reload systemd to pick up any service overrides (NoizDNS binary swap)
    # Must happen BEFORE router restart to ensure overrides are active
    systemctl daemon-reload 2>/dev/null || true

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

    # Start new tunnels (include NoizDNS if available)
    local _start_tags="$slip_tag $dnstt_tag $slip_ssh_tag $dnstt_ssh_tag"
    if [[ -x /usr/local/bin/noizdns-server ]]; then
        _start_tags+=" ${noiz_tag:-} ${noiz_ssh_tag:-}"
    fi
    print_info "Starting new tunnels..."
    for tag in $_start_tags; do
        [[ -z "$tag" ]] && continue
        if dnstm tunnel start --tag "$tag" 2>/dev/null; then
            print_ok "Started: ${tag}"
        else
            if dnstm tunnel list 2>/dev/null | awk -v t="tag=${tag}" '{for(i=1;i<=NF;i++) if($i==t){print;next}}' | grep -qi "running"; then
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
    echo -e "  Slipstream + SOCKS:  ${GREEN}t.${DOMAIN}${NC}  (${slip_tag})"
    echo -e "  DNSTT + SOCKS:       ${GREEN}d.${DOMAIN}${NC}  (${dnstt_tag})"
    if [[ -n "${noiz_tag:-}" ]]; then
        echo -e "  NoizDNS + SOCKS:     ${GREEN}n.${DOMAIN}${NC}  (${noiz_tag})  ${DIM}(DPI-resistant)${NC}"
    fi
    echo -e "  Slipstream + SSH:    ${GREEN}s.${DOMAIN}${NC}  (${slip_ssh_tag})"
    echo -e "  DNSTT + SSH:         ${GREEN}ds.${DOMAIN}${NC}  (${dnstt_ssh_tag})"
    if [[ -n "${noiz_ssh_tag:-}" ]]; then
        echo -e "  NoizDNS + SSH:       ${GREEN}z.${DOMAIN}${NC}  (${noiz_ssh_tag})  ${DIM}(DPI-resistant)${NC}"
    fi
    echo ""

    if [[ -n "$DNSTT_PUBKEY" ]]; then
        echo -e "  ${BOLD}DNSTT Public Keys${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  ${GREEN}${dnstt_tag} (SOCKS):${NC}  ${DNSTT_PUBKEY}"
        local _dnstt_ssh_pk=""
        if [[ -f "/etc/dnstm/tunnels/${dnstt_ssh_tag}/server.pub" ]]; then
            _dnstt_ssh_pk=$(cat "/etc/dnstm/tunnels/${dnstt_ssh_tag}/server.pub" 2>/dev/null || true)
        fi
        if [[ -n "$_dnstt_ssh_pk" ]]; then
            echo -e "  ${GREEN}${dnstt_ssh_tag} (SSH):${NC} ${_dnstt_ssh_pk}"
        fi
        echo ""
    fi

    if [[ -n "${NOIZDNS_PUBKEY:-}" ]]; then
        echo -e "  ${BOLD}NoizDNS Public Keys${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  ${GREEN}${noiz_tag} (SOCKS):${NC}   ${NOIZDNS_PUBKEY}"
        local _noiz_ssh_pk=""
        if [[ -n "${noiz_ssh_tag:-}" && -f "/etc/dnstm/tunnels/${noiz_ssh_tag}/server.pub" ]]; then
            _noiz_ssh_pk=$(cat "/etc/dnstm/tunnels/${noiz_ssh_tag}/server.pub" 2>/dev/null || true)
        fi
        if [[ -n "$_noiz_ssh_pk" ]]; then
            echo -e "  ${GREEN}${noiz_ssh_tag} (SSH):${NC}  ${_noiz_ssh_pk}"
        fi
        echo ""
    fi

    # Generate share URLs for new tunnels (dnst:// for dnstc CLI)
    echo -e "  ${BOLD}Share URLs — dnst:// (for dnstc CLI)${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    local share_url
    local _socks_tags="$slip_tag $dnstt_tag"
    [[ -n "${noiz_tag:-}" ]] && _socks_tags+=" $noiz_tag"
    for tag in $_socks_tags; do
        share_url=$(dnstm tunnel share -t "$tag" 2>/dev/null || true)
        if [[ -n "$share_url" ]]; then
            echo -e "  ${GREEN}${tag}:${NC} ${share_url}"
        fi
    done
    echo ""
    echo -e "  ${DIM}Note: SSH tunnel share URLs require credentials. Generate them with:${NC}"
    echo -e "  ${DIM}  dnstm tunnel share -t ${slip_ssh_tag} --user <username> --password <pass>${NC}"
    echo -e "  ${DIM}  dnstm tunnel share -t ${dnstt_ssh_tag} --user <username> --password <pass>${NC}"
    if [[ -n "${noiz_ssh_tag:-}" ]]; then
        echo -e "  ${DIM}  dnstm tunnel share -t ${noiz_ssh_tag} --user <username> --password <pass>${NC}"
    fi
    echo ""

    # Generate SlipNet deep-link URLs for new tunnels (slipnet:// for SlipNet app)
    echo -e "  ${BOLD}Share URLs — slipnet:// (for SlipNet app)${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    local slipnet_url
    local s_user="" s_pass=""
    if [[ "$SOCKS_AUTH" == true ]]; then
        s_user="$SOCKS_USER"
        s_pass="$SOCKS_PASS"
    fi
    slipnet_url=$(generate_slipnet_url "ss" "t" "" "" "" "$s_user" "$s_pass")
    echo -e "  ${GREEN}${slip_tag}:${NC}      ${slipnet_url}"
    if [[ -n "$DNSTT_PUBKEY" ]]; then
        slipnet_url=$(generate_slipnet_url "dnstt" "d" "$DNSTT_PUBKEY" "" "" "$s_user" "$s_pass")
        echo -e "  ${GREEN}${dnstt_tag}:${NC}     ${slipnet_url}"
    fi
    if [[ -n "${NOIZDNS_PUBKEY:-}" ]]; then
        slipnet_url=$(generate_slipnet_url "sayedns" "n" "$NOIZDNS_PUBKEY" "" "" "$s_user" "$s_pass")
        echo -e "  ${GREEN}${noiz_tag}:${NC}      ${slipnet_url}"
    fi

    # Ask user for SSH credentials to generate SSH tunnel URLs
    echo ""
    if prompt_yn "Generate SSH tunnel slipnet:// URLs?" "y"; then
        local ssh_tun_user ssh_tun_pass
        ssh_tun_user=$(prompt_input "SSH tunnel username")
        ssh_tun_pass=$(prompt_input "SSH tunnel password")
        if [[ "$ssh_tun_user" == *"|"* || "$ssh_tun_pass" == *"|"* ]]; then
            print_fail "Username/password cannot contain the | character"
        elif [[ -n "$ssh_tun_user" && -n "$ssh_tun_pass" ]]; then
            slipnet_url=$(generate_slipnet_url "slipstream_ssh" "s" "" "$ssh_tun_user" "$ssh_tun_pass" "$s_user" "$s_pass")
            echo -e "  ${GREEN}${slip_ssh_tag}:${NC}  ${slipnet_url}"
            # dnstt-ssh has its own keypair — read from its own tunnel dir
            local _dnstt_ssh_pk=""
            if [[ -f "/etc/dnstm/tunnels/${dnstt_ssh_tag}/server.pub" ]]; then
                _dnstt_ssh_pk=$(cat "/etc/dnstm/tunnels/${dnstt_ssh_tag}/server.pub" 2>/dev/null || true)
            fi
            if [[ -n "$_dnstt_ssh_pk" ]]; then
                slipnet_url=$(generate_slipnet_url "dnstt_ssh" "ds" "$_dnstt_ssh_pk" "$ssh_tun_user" "$ssh_tun_pass" "$s_user" "$s_pass")
                echo -e "  ${GREEN}${dnstt_ssh_tag}:${NC} ${slipnet_url}"
            fi
            if [[ -n "${NOIZDNS_PUBKEY:-}" && -n "${noiz_ssh_tag:-}" ]]; then
                local _noiz_ssh_pk2=""
                if [[ -f "/etc/dnstm/tunnels/${noiz_ssh_tag}/server.pub" ]]; then
                    _noiz_ssh_pk2=$(cat "/etc/dnstm/tunnels/${noiz_ssh_tag}/server.pub" 2>/dev/null || true)
                fi
                if [[ -n "$_noiz_ssh_pk2" ]]; then
                    slipnet_url=$(generate_slipnet_url "sayedns_ssh" "z" "$_noiz_ssh_pk2" "$ssh_tun_user" "$ssh_tun_pass" "$s_user" "$s_pass")
                    echo -e "  ${GREEN}${noiz_ssh_tag}:${NC} ${slipnet_url}"
                fi
            fi
        else
            echo -e "  ${DIM}Skipped — username or password was empty.${NC}"
        fi
    fi
    echo ""

    echo -e "  ${DIM}To add more domains, run again: sudo bash $0 --add-domain${NC}"
    echo ""
}

# ─── Parse Arguments ────────────────────────────────────────────────────────────

ADD_DOMAIN_MODE=false
ADD_DOMAIN_ARG=""
ADD_XRAY_MODE=false
HARDEN_ONLY_MODE=false
MANAGE_USERS_MODE=false
DNSTT_MTU=1232

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --about)
            show_about
            exit 0
            ;;
        --status)
            do_status
            exit 0
            ;;
        --manage)
            do_manage
            exit 0
            ;;
        --uninstall)
            do_uninstall
            exit 0
            ;;
        --remove-tunnel)
            # If $2 looks like another flag (starts with --), treat as no tag given
            if [[ -n "${2:-}" ]] && [[ "${2:0:2}" != "--" ]]; then
                do_remove_tunnel "$2"
            else
                do_remove_tunnel ""
            fi
            exit 0
            ;;
        --add-tunnel)
            do_add_tunnel
            exit 0
            ;;
        --add-xray)
            ADD_XRAY_MODE=true
            shift
            ;;
        --add-domain)
            ADD_DOMAIN_MODE=true
            # Accept optional domain argument: --add-domain example.com
            if [[ -n "${2:-}" ]] && [[ ! "$2" =~ ^-- ]]; then
                ADD_DOMAIN_ARG="$2"
                shift 2
            else
                shift
            fi
            ;;
        --users)
            MANAGE_USERS_MODE=true
            shift
            ;;
        --harden)
            HARDEN_ONLY_MODE=true
            shift
            ;;
        --mtu)
            if [[ -n "${2:-}" ]] && [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -ge 512 ]] && [[ "$2" -le 1400 ]]; then
                DNSTT_MTU="$2"
                shift 2
            else
                echo "Error: --mtu requires a value between 512 and 1400"
                exit 1
            fi
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# ─── Validate conflicting flags ──────────────────────────────────────────────────

mode_count=0
[[ "$ADD_DOMAIN_MODE" == true ]] && ((mode_count++)) || true
[[ "$ADD_XRAY_MODE" == true ]] && ((mode_count++)) || true
[[ "$HARDEN_ONLY_MODE" == true ]] && ((mode_count++)) || true
[[ "$MANAGE_USERS_MODE" == true ]] && ((mode_count++)) || true
if [[ $mode_count -gt 1 ]]; then
    echo "Error: --add-domain, --add-xray, --harden, and --users cannot be combined."
    exit 1
fi

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
elif [[ "$ADD_XRAY_MODE" == true ]]; then
    do_add_xray
elif [[ "$MANAGE_USERS_MODE" == true ]]; then
    do_manage_users
else
    main
fi
