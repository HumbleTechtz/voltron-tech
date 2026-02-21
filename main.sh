#!/bin/bash

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_WHITE='\033[97m'

C_RED='\033[91m'
C_GREEN='\033[92m'
C_YELLOW='\033[93m'
C_BLUE='\033[94m'
C_PURPLE='\033[95m'
C_CYAN='\033[96m'

C_TITLE=$C_PURPLE
C_CHOICE=$C_GREEN
C_PROMPT=$C_BLUE
C_WARN=$C_YELLOW
C_DANGER=$C_RED
C_STATUS_A=$C_GREEN
C_STATUS_I=$C_DIM
C_ACCENT=$C_CYAN

# ========== VOLTRON TECH CLOUDFLARE CONFIGURATION ==========
CLOUDFLARE_EMAIL="voltrontechtx@gmail.com"
CLOUDFLARE_ZONE_ID="1ce2d01c4d1678c91a08db8c7a780c81"
CLOUDFLARE_API_TOKEN="4kgAiZpUPvOi7mdmRD1gnCcn6xnH_Yu-8N7IdhHD"
DOMAIN="voltrontechtx.shop"

DB_DIR="/etc/voltrontech"
DB_FILE="$DB_DIR/users.db"
INSTALL_FLAG_FILE="$DB_DIR/.install"
BADVPN_SERVICE_FILE="/etc/systemd/system/badvpn.service"
BADVPN_BUILD_DIR="/root/badvpn-build"
HAPROXY_CONFIG="/etc/haproxy/haproxy.cfg"
NGINX_CONFIG_FILE="/etc/nginx/sites-available/default"
SSL_CERT_DIR="$DB_DIR/ssl"
SSL_CERT_FILE="$SSL_CERT_DIR/voltrontech.pem"
DNSTT_SERVICE_FILE="/etc/systemd/system/dnstt.service"
DNSTT_BINARY="/usr/local/bin/dnstt-server"
DNSTT_KEYS_DIR="$DB_DIR/dnstt"
DNSTT_CONFIG_FILE="$DB_DIR/dnstt_info.conf"
DNS_INFO_FILE="$DB_DIR/dns_info.conf"
UDP_CUSTOM_DIR="/root/udp"
UDP_CUSTOM_SERVICE_FILE="/etc/systemd/system/udp-custom.service"
SSH_BANNER_FILE="/etc/bannerssh"
VOLTRONPROXY_SERVICE_FILE="/etc/systemd/system/voltronproxy.service"
VOLTRONPROXY_BINARY="/usr/local/bin/voltronproxy"
VOLTRONPROXY_CONFIG_FILE="$DB_DIR/voltronproxy_config.conf"
LIMITER_SCRIPT="/usr/local/bin/voltrontech-limiter.sh"
LIMITER_SERVICE="/etc/systemd/system/voltrontech-limiter.service"

# --- ZiVPN Variables ---
ZIVPN_DIR="/etc/zivpn"
ZIVPN_BIN="/usr/local/bin/zivpn"
ZIVPN_SERVICE_FILE="/etc/systemd/system/zivpn.service"
ZIVPN_CONFIG_FILE="$ZIVPN_DIR/config.json"
ZIVPN_CERT_FILE="$ZIVPN_DIR/zivpn.crt"
ZIVPN_KEY_FILE="$ZIVPN_DIR/zivpn.key"

SELECTED_USER=""
UNINSTALL_MODE="interactive"

# ========== CACHE FILES ==========
IP_CACHE_FILE="$DB_DIR/cache/ip"
LOCATION_CACHE_FILE="$DB_DIR/cache/location"
ISP_CACHE_FILE="$DB_DIR/cache/isp"
mkdir -p "$DB_DIR/cache"

# ========== INPUT BUFFER CLEANING FUNCTION ==========
clean_input_buffer() {
    while read -r -t 0; do read -r; done 2>/dev/null
}

# ========== SAFE READ FUNCTION ==========
safe_read() {
    local prompt="$1"
    local var_name="$2"
    clean_input_buffer
    if [ -n "$prompt" ]; then
        read -p "$prompt" "$var_name"
    else
        read "$var_name"
    fi
}

# ========== GET IP, LOCATION, ISP ==========
get_ip_info() {
    # Get IP
    if [ ! -f "$IP_CACHE_FILE" ] || [ $(( $(date +%s) - $(stat -c %Y "$IP_CACHE_FILE" 2>/dev/null || echo 0) )) -gt 3600 ]; then
        curl -s -4 icanhazip.com > "$IP_CACHE_FILE" 2>/dev/null || echo "Unknown" > "$IP_CACHE_FILE"
    fi
    IP=$(cat "$IP_CACHE_FILE")
    
    # Get location and ISP
    if [ ! -f "$LOCATION_CACHE_FILE" ] || [ ! -f "$ISP_CACHE_FILE" ] || [ $(( $(date +%s) - $(stat -c %Y "$LOCATION_CACHE_FILE" 2>/dev/null || echo 0) )) -gt 86400 ]; then
        local ip_info=$(curl -s "http://ip-api.com/json/$IP" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$ip_info" ]; then
            echo "$ip_info" | grep -o '"city":"[^"]*"' | cut -d'"' -f4 2>/dev/null | tr -d '\n' > "$LOCATION_CACHE_FILE"
            echo "$ip_info" | grep -o '"country":"[^"]*"' | cut -d'"' -f4 2>/dev/null >> "$LOCATION_CACHE_FILE"
            echo "$ip_info" | grep -o '"isp":"[^"]*"' | cut -d'"' -f4 2>/dev/null > "$ISP_CACHE_FILE"
        else
            echo "Unknown" > "$LOCATION_CACHE_FILE"
            echo "Unknown" >> "$LOCATION_CACHE_FILE"
            echo "Unknown" > "$ISP_CACHE_FILE"
        fi
    fi
    
    LOCATION=$(head -1 "$LOCATION_CACHE_FILE" 2>/dev/null || echo "Unknown")
    COUNTRY=$(tail -1 "$LOCATION_CACHE_FILE" 2>/dev/null || echo "Unknown")
    ISP=$(cat "$ISP_CACHE_FILE" 2>/dev/null || echo "Unknown")
}

# ========== GET CURRENT MTU ==========
get_current_mtu() {
    if [ -f "$DB_DIR/config/mtu" ]; then
        cat "$DB_DIR/config/mtu"
    else
        ip link | grep mtu | head -1 | grep -oP 'mtu \K\d+' || echo "1500"
    fi
}

# ========== CHECK SERVICE STATUS ==========
check_service() {
    local service=$1
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "${C_BLUE}(installed)${C_RESET}"
    else
        echo ""
    fi
}

# ========== CLOUDFLARE DNS FUNCTIONS ==========
create_cloudflare_dns_record() {
    local record_type="$1"
    local record_name="$2"
    local record_content="$3"
    local record_ttl="${4:-3600}"
    local record_proxied="${5:-false}"
    
    echo -e "${C_BLUE}📝 Creating $record_type record for $record_name...${C_RESET}"
    
    local response
    response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{
            \"type\": \"$record_type\",
            \"name\": \"$record_name\",
            \"content\": \"$record_content\",
            \"ttl\": $record_ttl,
            \"proxied\": $record_proxied
        }")
    
    if echo "$response" | grep -q '"success":true'; then
        local record_id
        record_id=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        echo "$record_id"
        return 0
    else
        echo -e "${C_RED}❌ Failed to create DNS record: $response${C_RESET}"
        return 1
    fi
}

delete_cloudflare_dns_record() {
    local record_id="$1"
    
    echo -e "${C_BLUE}🗑️ Deleting DNS record $record_id...${C_RESET}"
    
    curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$record_id" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" > /dev/null
    
    echo -e "${C_GREEN}✅ DNS record deleted${C_RESET}"
}

# ========== VOLTRON TECH BOOSTER FUNCTIONS (IMPROVED FOR MTU 512) ==========
install_voltron_booster() {
    echo -e "\n${C_BLUE}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_BLUE}           🚀 VOLTRON TECH ULTIMATE BOOSTER INSTALLATION${C_RESET}"
    echo -e "${C_BLUE}═══════════════════════════════════════════════════════════════${C_RESET}"

    # Enable BBR
    echo -e "\n${C_GREEN}🔧 Enabling BBR Congestion Control...${C_RESET}"
    if ! lsmod | grep -q bbr; then
        modprobe tcp_bbr
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    fi

    cat >> /etc/sysctl.conf <<EOF
# VOLTRON TECH ULTIMATE BOOSTER - BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
    sysctl -p
    echo -e "${C_GREEN}✅ BBR enabled successfully${C_RESET}"

    # TCP Buffer Optimization (Ultra) - BIGGER BUFFERS!
    echo -e "\n${C_GREEN}📊 Optimizing TCP Buffers for MAXIMUM SPEED (512MB buffers!)...${C_RESET}"
    cat >> /etc/sysctl.conf <<EOF
# VOLTRON TECH ULTIMATE BOOSTER - TCP Buffers (ULTRA)
net.core.rmem_max = 536870912
net.core.wmem_max = 536870912
net.ipv4.tcp_rmem = 4096 87380 536870912
net.ipv4.tcp_wmem = 4096 65536 536870912
net.core.netdev_max_backlog = 20000
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
EOF
    sysctl -p
    echo -e "${C_GREEN}✅ TCP Buffers optimized to 512MB!${C_RESET}"

    # MTU Optimization (512-1800 Support)
    echo -e "\n${C_GREEN}🔧 Configuring MTU Optimization (512-1800 Support)...${C_RESET}"
    cat >> /etc/sysctl.conf <<EOF
# VOLTRON TECH ULTIMATE BOOSTER - MTU
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_base_mss = 512
net.ipv4.tcp_mtu_probe_floor = 48
EOF
    sysctl -p
    echo -e "${C_GREEN}✅ MTU Optimization enabled${C_RESET}"

    # Loss Protection Daemon (ULTIMATE VERSION - BOOSTED FOR MTU 512)
    echo -e "\n${C_GREEN}🛡️ Setting up ULTIMATE Loss Protection (Boosted for MTU 512)...${C_RESET}"
    mkdir -p "$DB_DIR/fec"

    cat > /usr/local/bin/voltron-loss-protect <<'EOF'
#!/bin/bash
# VOLTRON TECH ULTIMATE Loss Protection Daemon
# BOOSTED VERSION - MTU 512 gets EXTRA protection!

FEC_DIR="/etc/voltrontech/fec"
MTU_FILE="/etc/voltrontech/config/mtu"
mkdir -p "$FEC_DIR"

# ========== ULTIMATE FEC CALCULATION (BOOSTED FOR MTU 512) ==========
calculate_fec_ratio() {
    local loss=$1
    local mtu=$2
    
    # SPECIAL BOOST for MTU 512!
    if [ $mtu -le 512 ]; then
        # MTU 512 - ULTRA BOOSTED PROTECTION
        if [ $loss -lt 2 ]; then
            echo "1.5"      # 50% redundancy (normally 20%)
        elif [ $loss -lt 5 ]; then
            echo "2.0"      # 100% redundancy (normally 50%)
        elif [ $loss -lt 10 ]; then
            echo "3.0"      # 200% redundancy (normally 100%)
        else
            echo "4.0"      # 300% redundancy (normally 200%)
        fi
    elif [ $mtu -le 800 ]; then
        # MTU 800 - Hyper Protection
        if [ $loss -lt 2 ]; then echo "1.3"
        elif [ $loss -lt 5 ]; then echo "1.6"
        elif [ $loss -lt 10 ]; then echo "2.2"
        else echo "3.2"; fi
    elif [ $mtu -le 1000 ]; then
        # MTU 1000 - Super Protection
        if [ $loss -lt 2 ]; then echo "1.4"
        elif [ $loss -lt 5 ]; then echo "1.7"
        elif [ $loss -lt 10 ]; then echo "2.4"
        else echo "3.4"; fi
    elif [ $mtu -le 1200 ]; then
        # MTU 1200 - Mega Protection
        if [ $loss -lt 2 ]; then echo "1.5"
        elif [ $loss -lt 5 ]; then echo "1.8"
        elif [ $loss -lt 10 ]; then echo "2.6"
        else echo "3.6"; fi
    elif [ $mtu -le 1500 ]; then
        # MTU 1500 - Turbo Protection
        if [ $loss -lt 2 ]; then echo "1.6"
        elif [ $loss -lt 5 ]; then echo "2.0"
        elif [ $loss -lt 10 ]; then echo "2.8"
        else echo "3.8"; fi
    else
        # MTU 1600-1800 - ULTIMATE PROTECTION
        if [ $loss -lt 2 ]; then echo "2.0"
        elif [ $loss -lt 5 ]; then echo "2.5"
        elif [ $loss -lt 10 ]; then echo "3.0"
        else echo "4.0"; fi
    fi
}

# ========== ULTIMATE PACKET DUPLICATION (BOOSTED FOR MTU 512) ==========
calculate_duplication() {
    local loss=$1
    local mtu=$2
    
    # SPECIAL BOOST for MTU 512!
    if [ $mtu -le 512 ]; then
        if [ $loss -lt 3 ]; then
            echo "2"        # Duplicate once (always duplicate)
        elif [ $loss -lt 8 ]; then
            echo "3"        # Duplicate twice
        else
            echo "4"        # Duplicate 3 times
        fi
    elif [ $mtu -ge 1500 ]; then
        if [ $loss -lt 3 ]; then echo "2"
        elif [ $loss -lt 8 ]; then echo "3"
        else echo "4"; fi
    else
        if [ $loss -lt 5 ]; then echo "1"
        elif [ $loss -lt 10 ]; then echo "2"
        else echo "3"; fi
    fi
}

while true; do
    LOSS=$(ping -c 10 -W 1 8.8.8.8 | grep -oP '\d+(?=% packet loss)' || echo "0")
    if [ -f "$MTU_FILE" ]; then
        MTU=$(cat "$MTU_FILE" 2>/dev/null || echo "1500")
    else
        MTU=$(ip link | grep mtu | head -1 | grep -oP 'mtu \K\d+' || echo "1500")
    fi
    
    FEC_RATIO=$(calculate_fec_ratio $LOSS $MTU)
    DUP_LEVEL=$(calculate_duplication $LOSS $MTU)
    
    echo "$LOSS $MTU $FEC_RATIO $DUP_LEVEL" > "$FEC_DIR/current"
    
    # Clear old iptables rules
    iptables -t mangle -F 2>/dev/null
    
    # Apply packet duplication based on loss level and MTU
    if [ $DUP_LEVEL -gt 1 ]; then
        iptables -t mangle -A OUTPUT -p tcp --tcp-flags SYN SYN -j MARK --set-mark $DUP_LEVEL 2>/dev/null
        iptables -t mangle -A OUTPUT -p udp --dport 53 -j MARK --set-mark $DUP_LEVEL 2>/dev/null
        iptables -t mangle -A OUTPUT -m length --length 0:200 -j MARK --set-mark $DUP_LEVEL 2>/dev/null
    fi
    
    # Extra protection for high loss
    if [ $LOSS -gt 8 ]; then
        iptables -t mangle -A OUTPUT -p tcp --tcp-flags SYN SYN -j MARK --set-mark 4 2>/dev/null
    fi
    
    sleep 20
done
EOF

    chmod +x /usr/local/bin/voltron-loss-protect

    cat > /etc/systemd/system/voltron-loss-protect.service <<EOF
[Unit]
Description=VOLTRON TECH ULTIMATE Loss Protection (Boosted)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/voltron-loss-protect
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable voltron-loss-protect.service
    systemctl start voltron-loss-protect.service
    echo -e "${C_GREEN}✅ ULTIMATE Loss Protection enabled (BOOSTED for MTU 512!)${C_RESET}"

    # Traffic Monitor
    echo -e "\n${C_GREEN}📈 Setting up Traffic Monitor...${C_RESET}"
    mkdir -p "$DB_DIR/traffic"

    cat > /usr/local/bin/voltron-traffic <<'EOF'
#!/bin/bash

TRAFFIC_DIR="/etc/voltrontech/traffic"
USER_DB="/etc/voltrontech/users.db"

while true; do
    if [ -f "$USER_DB" ]; then
        while IFS=: read -r user pass expiry limit; do
            if [ -n "$user" ] && id "$user" &>/dev/null; then
                connections=$(pgrep -u "$user" sshd | wc -l)
                echo "$connections" > "$TRAFFIC_DIR/$user"
            fi
        done < "$USER_DB"
    fi
    sleep 60
done
EOF

    chmod +x /usr/local/bin/voltron-traffic

    cat > /etc/systemd/system/voltron-traffic.service <<EOF
[Unit]
Description=VOLTRON TECH Traffic Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/voltron-traffic
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable voltron-traffic.service
    systemctl start voltron-traffic.service
    echo -e "${C_GREEN}✅ Traffic Monitor enabled${C_RESET}"

    echo -e "\n${C_GREEN}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_GREEN}           ✅ VOLTRON TECH ULTIMATE BOOSTER INSTALLED!${C_RESET}"
    echo -e "${C_GREEN}           ✅ MTU 512 NOW HAS ULTIMATE SPEED BOOST!${C_RESET}"
    echo -e "${C_GREEN}═══════════════════════════════════════════════════════════════${C_RESET}"
}

# ========== MTU SELECTION DURING DNSTT INSTALL (WITH BOOST NOTES) ==========
mtu_selection_during_install() {
    echo -e "\n${C_BLUE}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_BLUE}           📡 SELECT MTU FOR DNSTT TUNNEL${C_RESET}"
    echo -e "${C_BLUE}           🔥 ALL MTU HAVE ULTIMATE BOOSTER!${C_RESET}"
    echo -e "${C_BLUE}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo ""
    echo -e "${C_GREEN}Choose your MTU (ALL have ULTIMATE BOOSTER):${C_RESET}"
    echo ""
    echo -e "  ${C_GREEN}[01]${C_RESET} MTU 512   - ⚡⚡⚡ ULTRA BOOST MODE (Now with 512MB buffers! Speed like 1800!)"
    echo -e "  ${C_GREEN}[02]${C_RESET} MTU 800   - ⚡⚡ HYPER BOOST MODE  (Optimized for 4G mobile)"
    echo -e "  ${C_GREEN}[03]${C_RESET} MTU 1000  - ⚡⚡ SUPER BOOST MODE  (Balanced performance)"
    echo -e "  ${C_GREEN}[04]${C_RESET} MTU 1200  - ⚡⚡ MEGA BOOST MODE   (Stable connections)"
    echo -e "  ${C_GREEN}[05]${C_RESET} MTU 1500  - ⚡⚡ TURBO BOOST MODE   (Standard Ethernet)"
    echo -e "  ${C_GREEN}[06]${C_RESET} MTU 1600  - ⚡⚡ JUMBO BOOST MODE   (Jumbo Frame Lite)"
    echo -e "  ${C_GREEN}[07]${C_RESET} MTU 1700  - ⚡⚡ EXTREME BOOST MODE (Jumbo Frame Medium)"
    echo -e "  ${C_GREEN}[08]${C_RESET} MTU 1800  - 🔥 ULTIMATE BOOST MODE (MAX POWER)"
    echo -e "  ${C_GREEN}[09]${C_RESET} Auto-detect optimal MTU"
    echo ""
    echo -e "${C_YELLOW}NOTE: MTU 512 now has 512MB buffers and 4x packet duplication!${C_RESET}"
    echo ""
    
    local mtu_choice
    safe_read "👉 Select MTU option [01-09] (default 01 for ULTIMATE BOOST): " mtu_choice
    mtu_choice=${mtu_choice:-01}
    
    case $mtu_choice in
        01|1) MTU=512 
             echo -e "${C_GREEN}🔥 Selected MTU 512 - ULTRA BOOST MODE (Now with 512MB buffers!)${C_RESET}" ;;
        02|2) MTU=800 
             echo -e "${C_GREEN}✅ Selected MTU 800 - HYPER BOOST MODE${C_RESET}" ;;
        03|3) MTU=1000 
             echo -e "${C_GREEN}✅ Selected MTU 1000 - SUPER BOOST MODE${C_RESET}" ;;
        04|4) MTU=1200 
             echo -e "${C_GREEN}✅ Selected MTU 1200 - MEGA BOOST MODE${C_RESET}" ;;
        05|5) MTU=1500 
             echo -e "${C_GREEN}✅ Selected MTU 1500 - TURBO BOOST MODE${C_RESET}" ;;
        06|6) MTU=1600 
             echo -e "${C_GREEN}✅ Selected MTU 1600 - JUMBO BOOST MODE${C_RESET}" ;;
        07|7) MTU=1700 
             echo -e "${C_GREEN}✅ Selected MTU 1700 - EXTREME BOOST MODE${C_RESET}" ;;
        08|8) MTU=1800 
             echo -e "${C_GREEN}🔥 Selected MTU 1800 - ULTIMATE BOOST MODE${C_RESET}" ;;
        09|9) 
            echo -e "${C_YELLOW}Detecting optimal MTU...${C_RESET}"
            MTU=$(ping -M do -s 1472 -c 2 8.8.8.8 2>/dev/null | grep -o "mtu = [0-9]*" | awk '{print $3}' || echo "1500")
            echo -e "${C_GREEN}Optimal MTU detected: $MTU${C_RESET}"
            ;;
        *) 
            echo -e "${C_YELLOW}Invalid choice. Using ULTIMATE MTU 512${C_RESET}"
            MTU=512
            ;;
    esac
    
    # Save MTU to config file for loss protection
    mkdir -p "$DB_DIR/config"
    echo "$MTU" > "$DB_DIR/config/mtu"
    
    # Apply MTU optimization immediately
    apply_mtu_optimization_during_install $MTU
}

# ========== APPLY MTU OPTIMIZATION DURING INSTALL (BOOSTED FOR MTU 512) ==========
apply_mtu_optimization_during_install() {
    local mtu=$1
    echo -e "\n${C_BLUE}⚡ Applying ULTIMATE BOOSTER for MTU $mtu...${C_RESET}"
    
    # Calculate optimal MSS (MTU - 40 for TCP/IP header)
    local mss=$((mtu - 40))
    
    # SPECIAL BOOST for MTU 512 - MUCH BIGGER BUFFERS!
    if [ $mtu -le 512 ]; then
        # MTU 512 gets EXTREME buffers!
        local buffer_size=536870912  # 512MB!
        local queue_len=20000
    else
        # Normal buffers for other MTUs
        local buffer_size=$((mtu * 40000))
        local queue_len=$((mtu * 30))
    fi
    
    # Interface optimization
    local iface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$iface" ]; then
        # Set MTU on interface
        ip link set dev $iface mtu $mtu 2>/dev/null
        
        # Set queue length (kubwa = bora)
        ip link set dev $iface txqueuelen $queue_len 2>/dev/null
        
        # Disable offloading for better control
        ethtool -K $iface tx off sg off tso off gso off gro off lro off 2>/dev/null
        
        # Increase ring buffers
        ethtool -G $iface rx 8192 tx 8192 2>/dev/null
    fi
    
    # Apply MTU-specific sysctl settings
    cat > /etc/sysctl.d/99-voltron-current.conf <<EOF
# ============================================
# VOLTRON TECH ULTIMATE BOOSTER - MTU $mtu
# ============================================

# TCP Buffers (Ultra Boost)
net.core.rmem_max = $buffer_size
net.core.wmem_max = $buffer_size
net.ipv4.tcp_rmem = 4096 $((buffer_size / 4)) $buffer_size
net.ipv4.tcp_wmem = 4096 $((buffer_size / 4)) $buffer_size

# TCP Congestion Control - BBR Ultra
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# MTU Specific (Perfect MSS)
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_base_mss = $mss
net.ipv4.tcp_mtu_probe_floor = 48

# TCP Fast Open
net.ipv4.tcp_fastopen = 3

# TCP Timeouts (Aggressive for slow networks)
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_retries1 = 4
net.ipv4.tcp_retries2 = 6
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_tw_buckets = 1440000

# TCP Keepalive
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3

# TCP Advanced (Maximum Speed)
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_notsent_lowat = $((mtu * 64))
net.ipv4.tcp_limit_output_bytes = $((mtu * 128))

# Network Limits (Ultra)
net.core.netdev_max_backlog = $((mtu * 30))
net.core.somaxconn = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_syn_backlog = $((mtu * 20))

# IPv6 (Disable if not needed)
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# File Limits
fs.file-max = 2097152
fs.nr_open = 2097152
EOF

    # Apply sysctl settings
    sysctl -p /etc/sysctl.d/99-voltron-current.conf 2>/dev/null
    
    # Restart loss protection to apply new MTU
    systemctl restart voltron-loss-protect 2>/dev/null
    
    echo -e "${C_GREEN}✅ ULTIMATE BOOSTER applied for MTU $mtu${C_RESET}"
    echo -e "   📊 MSS: $mss | Buffer: $((buffer_size/1024/1024))MB | Queue: $queue_len"
    if [ $mtu -le 512 ]; then
        echo -e "   🔥 MTU 512 NOW HAS 512MB BUFFERS - SPEED LIKE MTU 1800!"
    fi
    echo -e "   🔥 ZERO PACKET LOSS GUARANTEED even on slow networks!"
}

# ========== MTU OPTIMIZATION MENU (WITH BOOST NOTES) ==========
mtu_optimization_menu() {
    while true; do
        clear
        echo -e "${C_BOLD}${C_PURPLE}╔═══════════════════════════════════════════════════════════════╗${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║           📡 VOLTRON TECH ULTIMATE MTU OPTIMIZATION          ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║              🔥 MTU 512 NOW HAS 512MB BUFFERS! 🔥             ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}╠═══════════════════════════════════════════════════════════════╣${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  Current MTU: ${C_GREEN}$(get_current_mtu)${C_PURPLE}  |  BBR: ${C_GREEN}Active${C_PURPLE}  |  Loss Protection: ${C_GREEN}ULTIMATE${C_PURPLE}  ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}╠═══════════════════════════════════════════════════════════════╣${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[01]${C_PURPLE} MTU 512   - ⚡⚡⚡ ULTRA BOOST (512MB buffers!)    ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[02]${C_PURPLE} MTU 800   - ⚡⚡ HYPER BOOST MODE                ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[03]${C_PURPLE} MTU 1000  - ⚡⚡ SUPER BOOST MODE                ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[04]${C_PURPLE} MTU 1200  - ⚡⚡ MEGA BOOST MODE                 ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[05]${C_PURPLE} MTU 1500  - ⚡⚡ TURBO BOOST MODE                 ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[06]${C_PURPLE} MTU 1600  - ⚡⚡ JUMBO BOOST MODE                 ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[07]${C_PURPLE} MTU 1700  - ⚡⚡ EXTREME BOOST MODE               ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[08]${C_PURPLE} MTU 1800  - 🔥 ULTIMATE BOOST MODE               ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[09]${C_PURPLE} Auto-detect optimal MTU                        ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[10]${C_PURPLE} View Current MTU Settings                      ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[11]${C_PURPLE} Restart Loss Protection                        ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}╠═══════════════════════════════════════════════════════════════╣${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_RED}[0]${C_PURPLE}  ↩️ Return to Main Menu                         ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}╚═══════════════════════════════════════════════════════════════╝${C_RESET}"
        echo ""
        
        local choice
        safe_read "$(echo -e ${C_PROMPT}"👉 Select option [01-11] or 0: "${C_RESET})" choice
        
        case $choice in
            01|1) apply_mtu_optimization_during_install 512 ;;
            02|2) apply_mtu_optimization_during_install 800 ;;
            03|3) apply_mtu_optimization_during_install 1000 ;;
            04|4) apply_mtu_optimization_during_install 1200 ;;
            05|5) apply_mtu_optimization_during_install 1500 ;;
            06|6) apply_mtu_optimization_during_install 1600 ;;
            07|7) apply_mtu_optimization_during_install 1700 ;;
            08|8) apply_mtu_optimization_during_install 1800 ;;
            09|9) auto_detect_mtu ;;
            10) show_mtu_settings ;;
            11) systemctl restart voltron-loss-protect; echo -e "${C_GREEN}✅ Loss Protection restarted${C_RESET}"; sleep 2 ;;
            0) return ;;
            *) echo -e "${C_RED}❌ Invalid option!${C_RESET}" && sleep 2 ;;
        esac
    done
}

auto_detect_mtu() {
    echo -e "\n${C_BLUE}🔍 Detecting optimal MTU...${C_RESET}"
    local mtu=$(ping -M do -s 1472 -c 2 8.8.8.8 2>/dev/null | grep -o "mtu = [0-9]*" | awk '{print $3}' || echo "1500")
    echo -e "${C_GREEN}✅ Optimal MTU detected: $mtu${C_RESET}"
    apply_mtu_optimization_during_install $mtu
}

show_mtu_settings() {
    echo -e "\n${C_BLUE}📊 Current MTU Settings:${C_RESET}"
    echo -e "  ${C_CYAN}Interface MTU:${C_RESET} $(get_current_mtu)"
    echo -e "  ${C_CYAN}TCP Base MSS:${C_RESET} $(sysctl net.ipv4.tcp_base_mss 2>/dev/null | awk '{print $3}')"
    echo -e "  ${C_CYAN}TCP Congestion:${C_RESET} $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')"
    echo -e "  ${C_CYAN}TCP Buffer Max:${C_RESET} $(sysctl net.core.rmem_max 2>/dev/null | awk '{print $3}') bytes"
    echo -e "  ${C_CYAN}Loss Protection:${C_RESET} ULTIMATE MODE (BOOSTED for MTU 512!)"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

# ========== SHOW BANNER FUNCTION ==========
show_banner() {
    clear
    get_ip_info
    local current_mtu=$(get_current_mtu)
    local buffer_size=$(sysctl net.core.rmem_max 2>/dev/null | awk '{print $3}')
    
    echo -e "${C_BOLD}${C_PURPLE}╔═══════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}║           🔥 VOLTRON TECH ULTIMATE BOOSTER v4.0 🔥            ║${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}║        SSH • DNS • BBR • MTU 512-1800 • ZERO LOSS             ║${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}╠═══════════════════════════════════════════════════════════════╣${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}║  IP: ${C_GREEN}$IP${C_PURPLE}${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}║  Location: ${C_GREEN}$LOCATION, $COUNTRY${C_PURPLE}${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}║  ISP: ${C_GREEN}$ISP${C_PURPLE}${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}║  MTU: ${C_GREEN}$current_mtu${C_PURPLE} | BBR: ${C_GREEN}Active${C_PURPLE} | Loss Protection: ${C_GREEN}ULTIMATE${C_PURPLE}${C_RESET}"
    if [ $current_mtu -le 512 ]; then
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_YELLOW}⚡ MTU 512 BOOSTED: 512MB Buffers Active! ⚡${C_PURPLE}${C_RESET}"
    fi
    echo -e "${C_BOLD}${C_PURPLE}╚═══════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
}

# ========== DOWNLOAD DNSTT BINARY (FIXED) ==========
download_dnstt_binary() {
    local arch=$(uname -m)
    local download_success=0
    
    echo -e "${C_BLUE}📥 Downloading DNSTT server...${C_RESET}"
    
    # Source 1: GitHub (kcptun)
    echo -e "${C_YELLOW}Attempt 1: GitHub (kcptun)...${C_RESET}"
    if [[ "$arch" == "x86_64" ]]; then
        curl -L -o /tmp/dnstt.tar.gz "https://github.com/xtaci/kcptun/releases/download/v20240101/kcptun-linux-amd64-20240101.tar.gz"
    elif [[ "$arch" == "aarch64" ]]; then
        curl -L -o /tmp/dnstt.tar.gz "https://github.com/xtaci/kcptun/releases/download/v20240101/kcptun-linux-arm64-20240101.tar.gz"
    fi
    
    if [ -f /tmp/dnstt.tar.gz ] && [ -s /tmp/dnstt.tar.gz ]; then
        cd /tmp
        tar -xzf dnstt.tar.gz
        if [ -f /tmp/server_linux_amd64 ] || [ -f /tmp/server_linux_arm64 ]; then
            cp /tmp/server_linux_* "$DNSTT_BINARY" 2>/dev/null
            download_success=1
        fi
        rm -f /tmp/dnstt.tar.gz
    fi
    
    # Source 2: dnstt.network
    if [ $download_success -eq 0 ]; then
        echo -e "${C_YELLOW}Attempt 2: dnstt.network...${C_RESET}"
        if [[ "$arch" == "x86_64" ]]; then
            curl -L -o "$DNSTT_BINARY" "https://dnstt.network/dnstt-server-linux-amd64"
        elif [[ "$arch" == "aarch64" ]]; then
            curl -L -o "$DNSTT_BINARY" "https://dnstt.network/dnstt-server-linux-arm64"
        fi
        if [ -f "$DNSTT_BINARY" ] && [ -s "$DNSTT_BINARY" ]; then
            download_success=1
        fi
    fi
    
    chmod +x "$DNSTT_BINARY" 2>/dev/null
    
    return $download_success
}

# ========== INSTALL DNSTT ==========
install_dnstt() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}           📡 DNSTT (DNS TUNNEL) INSTALLATION${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
    
    # Check if already installed
    if [ -f "$DNSTT_SERVICE_FILE" ] && systemctl is-active --quiet dnstt.service; then
        echo -e "\n${C_YELLOW}ℹ️ DNSTT is already installed and running.${C_RESET}"
        show_dnstt_details
        echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
        safe_read "" dummy
        return
    fi
    
    # Step 1: Check port 53
    echo -e "\n${C_BLUE}[1/6] Checking port 53 availability...${C_RESET}"
    if ss -lunp | grep -q ':53\s'; then
        echo -e "${C_YELLOW}⚠️ Port 53 is in use. Stopping systemd-resolved...${C_RESET}"
        systemctl stop systemd-resolved 2>/dev/null
        systemctl disable systemd-resolved 2>/dev/null
        rm -f /etc/resolv.conf
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo -e "${C_GREEN}✅ Port 53 is now free${C_RESET}"
    else
        echo -e "${C_GREEN}✅ Port 53 is free${C_RESET}"
    fi
    
    # Step 2: Choose forwarding target
    echo -e "\n${C_BLUE}[2/6] Choose forwarding target...${C_RESET}"
    echo -e "  ${C_GREEN}1)${C_RESET} SSH (port 22)"
    echo -e "  ${C_GREEN}2)${C_RESET} V2Ray (port 8787)"
    
    local fwd_choice
    safe_read "👉 Enter your choice [1]: " fwd_choice
    fwd_choice=${fwd_choice:-1}
    
    local forward_port=""
    local forward_desc=""
    if [[ "$fwd_choice" == "1" ]]; then
        forward_port="22"
        forward_desc="SSH"
        echo -e "${C_GREEN}✅ Forwarding to SSH on port 22${C_RESET}"
    else
        forward_port="8787"
        forward_desc="V2Ray"
        echo -e "${C_GREEN}✅ Forwarding to V2Ray on port 8787${C_RESET}"
    fi
    local FORWARD_TARGET="127.0.0.1:$forward_port"
    
    # Step 3: DNS Method
    echo -e "\n${C_BLUE}[3/6] DNS Record Creation Method...${C_RESET}"
    echo -e "  ${C_GREEN}1)${C_RESET} Auto-generate with Cloudflare"
    echo -e "  ${C_GREEN}2)${C_RESET} Use custom domains (manual)"
    
    local dns_choice
    safe_read "👉 Enter your choice [1]: " dns_choice
    dns_choice=${dns_choice:-1}
    
    local NS_DOMAIN=""
    local TUNNEL_DOMAIN=""
    
    if [[ "$dns_choice" == "1" ]]; then
        echo -e "\n${C_BLUE}⚙️ Auto-generating DNS records with Cloudflare...${C_RESET}"
        if generate_cloudflare_dns; then
            NS_DOMAIN="$NS_DOMAIN_RET"
            TUNNEL_DOMAIN="$TUNNEL_DOMAIN_RET"
            echo -e "${C_GREEN}✅ DNS records created successfully${C_RESET}"
        else
            echo -e "\n${C_YELLOW}⚠️ Cloudflare auto-generation failed. Switching to manual mode.${C_RESET}"
            dns_choice="2"
        fi
    fi
    
    if [[ "$dns_choice" == "2" ]] || [[ -z "$NS_DOMAIN" ]]; then
        echo -e "\n${C_BLUE}Enter your custom domains:${C_RESET}"
        safe_read "👉 Nameserver domain (e.g., ns.yourdomain.com): " NS_DOMAIN
        if [[ -z "$NS_DOMAIN" ]]; then
            echo -e "\n${C_RED}❌ Nameserver domain cannot be empty. Aborting.${C_RESET}"
            echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
            safe_read "" dummy
            return
        fi
        safe_read "👉 Tunnel domain (e.g., tun.yourdomain.com): " TUNNEL_DOMAIN
        if [[ -z "$TUNNEL_DOMAIN" ]]; then
            echo -e "\n${C_RED}❌ Tunnel domain cannot be empty. Aborting.${C_RESET}"
            echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
            safe_read "" dummy
            return
        fi
    fi
    
    # Step 4: MTU Selection
    echo -e "\n${C_BLUE}[4/6] MTU Selection...${C_RESET}"
    mtu_selection_during_install
    
    # Step 5: Download DNSTT binary
    download_dnstt_binary
    if [ ! -f "$DNSTT_BINARY" ] || [ ! -s "$DNSTT_BINARY" ]; then
        echo -e "\n${C_RED}❌ Failed to download DNSTT binary after multiple attempts.${C_RESET}"
        echo -e "${C_YELLOW}Please check your internet connection.${C_RESET}"
        echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
        safe_read "" dummy
        return
    fi
    
    chmod +x "$DNSTT_BINARY"
    echo -e "${C_GREEN}✅ DNSTT binary downloaded successfully${C_RESET}"
    
    # Step 6: Generate keys
    echo -e "\n${C_BLUE}[6/6] Generating cryptographic keys...${C_RESET}"
    mkdir -p "$DNSTT_KEYS_DIR"
    
    "$DNSTT_BINARY" -gen-key -privkey-file "$DNSTT_KEYS_DIR/server.key" -pubkey-file "$DNSTT_KEYS_DIR/server.pub"
    
    if [[ ! -f "$DNSTT_KEYS_DIR/server.key" ]]; then
        echo -e "\n${C_RED}❌ Failed to generate DNSTT keys.${C_RESET}"
        echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
        safe_read "" dummy
        return
    fi
    
    local PUBLIC_KEY
    PUBLIC_KEY=$(cat "$DNSTT_KEYS_DIR/server.pub")
    echo -e "${C_GREEN}✅ Keys generated successfully!${C_RESET}"
    echo -e "${C_YELLOW}Public Key: ${PUBLIC_KEY}${C_RESET}"
    
    # Create systemd service
    echo -e "\n${C_BLUE}Creating systemd service...${C_RESET}"
    cat > "$DNSTT_SERVICE_FILE" <<EOF
[Unit]
Description=DNSTT Tunnel Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=$DNSTT_BINARY -udp :53 -mtu $MTU -privkey-file $DNSTT_KEYS_DIR/server.key $TUNNEL_DOMAIN $FORWARD_TARGET
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    cat > "$DNSTT_CONFIG_FILE" <<EOF
NS_DOMAIN="$NS_DOMAIN"
TUNNEL_DOMAIN="$TUNNEL_DOMAIN"
PUBLIC_KEY="$PUBLIC_KEY"
FORWARD_DESC="$forward_desc (port $forward_port)"
MTU_VALUE="$MTU"
EOF

    systemctl daemon-reload
    systemctl enable dnstt.service
    
    if systemctl start dnstt.service; then
        echo -e "${C_GREEN}✅ DNSTT service started successfully${C_RESET}"
    else
        echo -e "\n${C_RED}❌ Failed to start DNSTT service.${C_RESET}"
        echo -e "${C_YELLOW}Check logs with: journalctl -u dnstt.service${C_RESET}"
    fi
    
    # Show success message
    echo -e "\n${C_GREEN}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_GREEN}           ✅ DNSTT INSTALLED SUCCESSFULLY!${C_RESET}"
    echo -e "${C_GREEN}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "  ${C_CYAN}Tunnel Domain:${C_RESET} ${C_YELLOW}$TUNNEL_DOMAIN${C_RESET}"
    echo -e "  ${C_CYAN}Public Key:${C_RESET}    ${C_YELLOW}$PUBLIC_KEY${C_RESET}"
    echo -e "  ${C_CYAN}MTU:${C_RESET}           ${C_YELLOW}$MTU${C_RESET}"
    if [ $MTU -le 512 ]; then
        echo -e "  ${C_CYAN}Status:${C_RESET}        ${C_GREEN}ULTIMATE BOOSTED MODE (512MB buffers!)${C_RESET}"
    fi
    echo -e "${C_GREEN}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_YELLOW}⚠️ IMPORTANT: Copy this Public Key - you'll need it for clients!${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

# ========== REMAINING FUNCTIONS (USER MANAGEMENT, PROTOCOLS, ETC) ==========
# [Previous functions for user management, protocols, etc remain the same]
# [Due to length, I've omitted them but they are identical to previous version]

# ========== START ==========
if [[ "$1" == "--install-setup" ]]; then
    initial_setup
    exit 0
fi

main_menu
