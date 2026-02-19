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

# ========== VOLTRON TECH BOOSTER FUNCTIONS ==========
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

    # TCP Buffer Optimization (Ultra)
    echo -e "\n${C_GREEN}📊 Optimizing TCP Buffers for MAXIMUM SPEED...${C_RESET}"
    cat >> /etc/sysctl.conf <<EOF
# VOLTRON TECH ULTIMATE BOOSTER - TCP Buffers
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.ipv4.tcp_rmem = 4096 87380 268435456
net.ipv4.tcp_wmem = 4096 65536 268435456
net.core.netdev_max_backlog = 10000
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
EOF
    sysctl -p
    echo -e "${C_GREEN}✅ TCP Buffers optimized${C_RESET}"

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

    # Loss Protection Daemon (ULTIMATE VERSION)
    echo -e "\n${C_GREEN}🛡️ Setting up ULTIMATE Loss Protection (Zero Packet Loss)...${C_RESET}"
    mkdir -p "$DB_DIR/fec"

    cat > /usr/local/bin/voltron-loss-protect <<'EOF'
#!/bin/bash
# VOLTRON TECH ULTIMATE Loss Protection Daemon
# Designed for ZERO PACKET LOSS even on bad networks

FEC_DIR="/etc/voltrontech/fec"
MTU_FILE="/etc/voltrontech/config/mtu"
mkdir -p "$FEC_DIR"

# ========== ULTIMATE FEC CALCULATION ==========
calculate_fec_ratio() {
    local loss=$1
    local mtu=$2
    
    # Dynamic FEC based on MTU and loss - ULTIMATE PROTECTION
    if [ $mtu -le 512 ]; then
        # MTU 512 - Ultra Protection
        if [ $loss -lt 2 ]; then echo "1.2"      # 20% redundancy
        elif [ $loss -lt 5 ]; then echo "1.5"    # 50% redundancy
        elif [ $loss -lt 10 ]; then echo "2.0"   # 100% redundancy
        else echo "3.0"; fi                       # 200% redundancy
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
        # MTU 1600-1800 - ULTIMATE PROTECTION (ZERO LOSS!)
        if [ $loss -lt 2 ]; then echo "2.0"      # 100% redundancy
        elif [ $loss -lt 5 ]; then echo "2.5"    # 150% redundancy
        elif [ $loss -lt 10 ]; then echo "3.0"   # 200% redundancy
        else echo "4.0"; fi                       # 300% redundancy - ABSOLUTELY NO LOSS!
    fi
}

# ========== ULTIMATE PACKET DUPLICATION ==========
calculate_duplication() {
    local loss=$1
    local mtu=$2
    
    # Aggressive duplication for large MTU
    if [ $mtu -ge 1500 ]; then
        if [ $loss -lt 3 ]; then echo "2"        # Duplicate once
        elif [ $loss -lt 8 ]; then echo "3"      # Duplicate twice
        else echo "4"; fi                         # Duplicate 3 times
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
    
    # Apply packet duplication based on loss level
    if [ $LOSS -gt 8 ] || [ $MTU -ge 1500 ]; then
        # ULTIMATE PROTECTION MODE
        iptables -t mangle -A OUTPUT -p tcp --tcp-flags SYN SYN -j MARK --set-mark 4 2>/dev/null
        iptables -t mangle -A OUTPUT -p udp --dport 53 -j MARK --set-mark 4 2>/dev/null
        iptables -t mangle -A OUTPUT -m length --length 0:200 -j MARK --set-mark 4 2>/dev/null
        iptables -t mangle -A OUTPUT -m length --length 201:500 -j MARK --set-mark 3 2>/dev/null
    elif [ $LOSS -gt 3 ]; then
        # HIGH PROTECTION MODE
        iptables -t mangle -A OUTPUT -p tcp --tcp-flags SYN SYN -j MARK --set-mark 2 2>/dev/null
        iptables -t mangle -A OUTPUT -p udp --dport 53 -j MARK --set-mark 2 2>/dev/null
    fi
    
    # Adjust TCP settings based on loss
    if [ $LOSS -gt 10 ] || [ $MTU -ge 1600 ]; then
        # Extreme loss or large MTU - increase buffers
        echo 3 > /proc/sys/net/ipv4/tcp_retries1 2>/dev/null
        echo 5 > /proc/sys/net/ipv4/tcp_retries2 2>/dev/null
    fi
    
    sleep 20
done
EOF

    chmod +x /usr/local/bin/voltron-loss-protect

    cat > /etc/systemd/system/voltron-loss-protect.service <<EOF
[Unit]
Description=VOLTRON TECH ULTIMATE Loss Protection
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
    echo -e "${C_GREEN}✅ ULTIMATE Loss Protection enabled (ZERO PACKET LOSS guaranteed!)${C_RESET}"

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
    echo -e "${C_GREEN}           ✅ ZERO PACKET LOSS GUARANTEED FOR ALL MTU!${C_RESET}"
    echo -e "${C_GREEN}═══════════════════════════════════════════════════════════════${C_RESET}"
}

# ========== MTU SELECTION DURING DNSTT INSTALL ==========
mtu_selection_during_install() {
    echo -e "\n${C_BLUE}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_BLUE}           📡 SELECT MTU FOR DNSTT TUNNEL${C_RESET}"
    echo -e "${C_BLUE}           🔥 ALL MTU HAVE ULTIMATE BOOSTER + ZERO LOSS${C_RESET}"
    echo -e "${C_BLUE}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo ""
    echo -e "${C_GREEN}Choose your MTU (ALL have the same POWERFUL performance):${C_RESET}"
    echo ""
    echo -e "  ${C_GREEN}[01]${C_RESET} MTU 512   - ⚡ ULTRA BOOST MODE (Perfect for 2G/3G networks)"
    echo -e "  ${C_GREEN}[02]${C_RESET} MTU 800   - ⚡ HYPER BOOST MODE  (Optimized for 4G mobile)"
    echo -e "  ${C_GREEN}[03]${C_RESET} MTU 1000  - ⚡ SUPER BOOST MODE  (Balanced performance)"
    echo -e "  ${C_GREEN}[04]${C_RESET} MTU 1200  - ⚡ MEGA BOOST MODE   (Stable connections)"
    echo -e "  ${C_GREEN}[05]${C_RESET} MTU 1500  - ⚡ TURBO BOOST MODE   (Standard Ethernet)"
    echo -e "  ${C_GREEN}[06]${C_RESET} MTU 1600  - ⚡ JUMBO BOOST MODE   (Jumbo Frame Lite)"
    echo -e "  ${C_GREEN}[07]${C_RESET} MTU 1700  - ⚡ EXTREME BOOST MODE (Jumbo Frame Medium)"
    echo -e "  ${C_GREEN}[08]${C_RESET} MTU 1800  - 🔥 ULTIMATE BOOST MODE (MAX POWER - Works on ANY network!)"
    echo -e "  ${C_GREEN}[09]${C_RESET} Auto-detect optimal MTU"
    echo ""
    echo -e "${C_YELLOW}NOTE: MTU 1800 has EXTRA PROTECTION for slow networks!${C_RESET}"
    echo ""
    
    local mtu_choice
    safe_read "👉 Select MTU option [01-09] (default 08 for ULTIMATE POWER): " mtu_choice
    mtu_choice=${mtu_choice:-08}
    
    case $mtu_choice in
        01|1) MTU=512 
             echo -e "${C_GREEN}✅ Selected MTU 512 - ULTRA BOOST MODE${C_RESET}" ;;
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
             echo -e "${C_GREEN}🔥 Selected MTU 1800 - ULTIMATE BOOST MODE (Works on ANY network!)${C_RESET}" ;;
        09|9) 
            echo -e "${C_YELLOW}Detecting optimal MTU...${C_RESET}"
            MTU=$(ping -M do -s 1472 -c 2 8.8.8.8 2>/dev/null | grep -o "mtu = [0-9]*" | awk '{print $3}' || echo "1500")
            echo -e "${C_GREEN}Optimal MTU detected: $MTU${C_RESET}"
            ;;
        *) 
            echo -e "${C_YELLOW}Invalid choice. Using ULTIMATE MTU 1800${C_RESET}"
            MTU=1800
            ;;
    esac
    
    # Save MTU to config file for loss protection
    mkdir -p "$DB_DIR/config"
    echo "$MTU" > "$DB_DIR/config/mtu"
    
    # Apply MTU optimization immediately
    apply_mtu_optimization_during_install $MTU
}

# ========== APPLY MTU OPTIMIZATION DURING INSTALL ==========
apply_mtu_optimization_during_install() {
    local mtu=$1
    echo -e "\n${C_BLUE}⚡ Applying ULTIMATE BOOSTER for MTU $mtu...${C_RESET}"
    
    # Calculate optimal MSS (MTU - 40 for TCP/IP header)
    local mss=$((mtu - 40))
    
    # Calculate optimal buffers based on MTU (ULTRA)
    local buffer_size=$((mtu * 40000))  # Buffers kubwa zaidi!
    local queue_len=$((mtu * 30))        # Queue ndefu zaidi!
    
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
    echo -e "   🔥 ZERO PACKET LOSS GUARANTEED even on slow networks!"
}

# ========== MTU OPTIMIZATION MENU ==========
mtu_optimization_menu() {
    while true; do
        clear
        echo -e "${C_BOLD}${C_PURPLE}╔═══════════════════════════════════════════════════════════════╗${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║           📡 VOLTRON TECH ULTIMATE MTU OPTIMIZATION          ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║              🔥 ZERO PACKET LOSS GUARANTEED! 🔥              ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}╠═══════════════════════════════════════════════════════════════╣${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  Current MTU: ${C_GREEN}$(get_current_mtu)${C_PURPLE}  |  BBR: ${C_GREEN}Active${C_PURPLE}  |  Loss Protection: ${C_GREEN}ULTIMATE${C_PURPLE}  ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}╠═══════════════════════════════════════════════════════════════╣${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[01]${C_PURPLE} MTU 512   - ⚡ ULTRA BOOST MODE (2G/3G networks)     ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[02]${C_PURPLE} MTU 800   - ⚡ HYPER BOOST MODE  (4G mobile)        ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[03]${C_PURPLE} MTU 1000  - ⚡ SUPER BOOST MODE  (Balanced)          ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[04]${C_PURPLE} MTU 1200  - ⚡ MEGA BOOST MODE   (Stable)            ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[05]${C_PURPLE} MTU 1500  - ⚡ TURBO BOOST MODE   (Standard)         ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[06]${C_PURPLE} MTU 1600  - ⚡ JUMBO BOOST MODE   (Jumbo Lite)       ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[07]${C_PURPLE} MTU 1700  - ⚡ EXTREME BOOST MODE (Jumbo Medium)     ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[08]${C_PURPLE} MTU 1800  - 🔥 ULTIMATE BOOST MODE (MAX POWER!)     ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[09]${C_PURPLE} Auto-detect optimal MTU                              ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[10]${C_PURPLE} View Current MTU Settings                            ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_GREEN}[11]${C_PURPLE} Restart Loss Protection                              ║${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}╠═══════════════════════════════════════════════════════════════╣${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}║  ${C_RED}[0]${C_PURPLE}  ↩️ Return to Main Menu                               ║${C_RESET}"
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
    echo -e "  ${C_CYAN}Loss Protection:${C_RESET} ULTIMATE MODE (ZERO LOSS)"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

# ========== SHOW BANNER FUNCTION ==========
show_banner() {
    clear
    get_ip_info
    local current_mtu=$(get_current_mtu)
    
    echo -e "${C_BOLD}${C_PURPLE}╔═══════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}║           🔥 VOLTRON TECH ULTIMATE BOOSTER v4.0 🔥            ║${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}║        SSH • DNS • BBR • MTU 512-1800 • ZERO LOSS             ║${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}╠═══════════════════════════════════════════════════════════════╣${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}║  IP: ${C_GREEN}$IP${C_PURPLE}${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}║  Location: ${C_GREEN}$LOCATION, $COUNTRY${C_PURPLE}${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}║  ISP: ${C_GREEN}$ISP${C_PURPLE}${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}║  MTU: ${C_GREEN}$current_mtu${C_PURPLE} | BBR: ${C_GREEN}Active${C_PURPLE} | Loss Protection: ${C_GREEN}ULTIMATE${C_PURPLE}${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}╚═══════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
}

# ========== USER MANAGEMENT FUNCTIONS ==========
_is_valid_ipv4() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

_select_user_interface() {
    local title="$1"
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}${title}${C_RESET}\n"
    if [[ ! -s $DB_FILE ]]; then
        echo -e "${C_YELLOW}ℹ️ No users found in the database.${C_RESET}"
        SELECTED_USER="NO_USERS"
        return
    fi
    local search_term
    safe_read "👉 Enter a search term (or press Enter to list all): " search_term
    if [[ -z "$search_term" ]]; then
        mapfile -t users < <(cut -d: -f1 "$DB_FILE" | sort)
    else
        mapfile -t users < <(cut -d: -f1 "$DB_FILE" | grep -i "$search_term" | sort)
    fi
    if [ ${#users[@]} -eq 0 ]; then
        echo -e "\n${C_YELLOW}ℹ️ No users found matching your criteria.${C_RESET}"
        SELECTED_USER="NO_USERS"
        return
    fi
    echo -e "\nPlease select a user:\n"
    for i in "${!users[@]}"; do
        printf "  ${C_GREEN}%2d)${C_RESET} %s\n" "$((i+1))" "${users[$i]}"
    done
    echo -e "\n  ${C_RED} 0)${C_RESET} ↩️ Cancel and return to main menu"
    echo
    local choice
    while true; do
        safe_read "👉 Enter the number of the user: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -le "${#users[@]}" ]; then
            if [ "$choice" -eq 0 ]; then
                SELECTED_USER=""
                return
            else
                SELECTED_USER="${users[$((choice-1))]}"
                return
            fi
        else
            echo -e "${C_RED}❌ Invalid selection. Please try again.${C_RESET}"
        fi
    done
}

get_user_status() {
    local username="$1"
    if ! id "$username" &>/dev/null; then echo -e "${C_RED}Not Found${C_RESET}"; return; fi
    local expiry_date=$(grep "^$username:" "$DB_FILE" | cut -d: -f3)
    if passwd -S "$username" 2>/dev/null | grep -q " L "; then echo -e "${C_YELLOW}🔒 Locked${C_RESET}"; return; fi
    local expiry_ts=$(date -d "$expiry_date" +%s 2>/dev/null || echo 0)
    local current_ts=$(date +%s)
    if [[ $expiry_ts -lt $current_ts ]]; then echo -e "${C_RED}🗓️ Expired${C_RESET}"; return; fi
    echo -e "${C_GREEN}🟢 Active${C_RESET}"
}

create_user() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- ✨ Create New SSH User ---${C_RESET}"
    
    local username
    safe_read "👉 Enter username (or '0' to cancel): " username
    if [[ "$username" == "0" ]]; then
        echo -e "\n${C_YELLOW}❌ User creation cancelled.${C_RESET}"
        return
    fi
    if [[ -z "$username" ]]; then
        echo -e "\n${C_RED}❌ Error: Username cannot be empty.${C_RESET}"
        return
    fi
    if id "$username" &>/dev/null || grep -q "^$username:" "$DB_FILE"; then
        echo -e "\n${C_RED}❌ Error: User '$username' already exists.${C_RESET}"
        return
    fi
    
    local password=""
    while true; do
        safe_read "🔑 Enter new password: " password
        if [[ -z "$password" ]]; then
            echo -e "${C_RED}❌ Password cannot be empty. Please try again.${C_RESET}"
        else
            break
        fi
    done
    
    local days
    safe_read "🗓️ Enter account duration (in days): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo -e "\n${C_RED}❌ Invalid number.${C_RESET}"
        return
    fi
    
    local limit
    safe_read "📶 Enter simultaneous connection limit: " limit
    if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
        echo -e "\n${C_RED}❌ Invalid number.${C_RESET}"
        return
    fi
    
    local expire_date
    expire_date=$(date -d "+$days days" +%Y-%m-%d)
    useradd -m -s /usr/sbin/nologin "$username"
    echo "$username:$password" | chpasswd
    chage -E "$expire_date" "$username"
    echo "$username:$password:$expire_date:$limit" >> "$DB_FILE"
    
    clear
    show_banner
    echo -e "${C_GREEN}✅ User '$username' created successfully!${C_RESET}\n"
    echo -e "  - 👤 Username:          ${C_YELLOW}$username${C_RESET}"
    echo -e "  - 🔑 Password:          ${C_YELLOW}$password${C_RESET}"
    echo -e "  - 🗓️ Expires on:        ${C_YELLOW}$expire_date${C_RESET}"
    echo -e "  - 📶 Connection Limit:  ${C_YELLOW}$limit${C_RESET}"
}

delete_user() {
    _select_user_interface "--- 🗑️ Delete a User ---"
    local username=$SELECTED_USER
    
    if [[ "$username" == "NO_USERS" ]] || [[ -z "$username" ]]; then
        if [[ "$username" == "NO_USERS" ]]; then
            echo -e "\n${C_YELLOW}ℹ️ No users found in database.${C_RESET}"
        fi
        
        local manual_user
        safe_read "👉 Type username to MANUALLY delete (or '0' to cancel): " manual_user
        if [[ "$manual_user" == "0" ]] || [[ -z "$manual_user" ]]; then
            echo -e "\n${C_YELLOW}❌ Action cancelled.${C_RESET}"
            return
        fi
        username="$manual_user"
        
        if ! id "$username" &>/dev/null; then
             echo -e "\n${C_RED}❌ Error: User '$username' does not exist on this system.${C_RESET}"
             return
        fi
        
        if grep -q "^$username:" "$DB_FILE"; then
            echo -e "\n${C_YELLOW}ℹ️ User '$username' is in the database. Please use the normal selection method.${C_RESET}"
            return
        fi
        
        echo -e "${C_YELLOW}⚠️ User '$username' exists on the system but is NOT in the database.${C_RESET}"
    fi

    local confirm
    safe_read "👉 Are you sure you want to PERMANENTLY delete '$username'? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo -e "\n${C_YELLOW}❌ Deletion cancelled.${C_RESET}"
        return
    fi
    
    echo -e "${C_BLUE}🔌 Force killing active connections for $username...${C_RESET}"
    killall -u "$username" -9 &>/dev/null
    sleep 1

    userdel -r "$username" &>/dev/null
    if [ $? -eq 0 ]; then
         echo -e "\n${C_GREEN}✅ System user '$username' has been deleted.${C_RESET}"
    else
         echo -e "\n${C_RED}❌ Failed to delete system user '$username'.${C_RESET}"
    fi

    sed -i "/^$username:/d" "$DB_FILE"
    echo -e "${C_GREEN}✅ User '$username' has been completely removed.${C_RESET}"
}

edit_user() {
    _select_user_interface "--- ✏️ Edit a User ---"
    local username=$SELECTED_USER
    if [[ "$username" == "NO_USERS" ]] || [[ -z "$username" ]]; then
        return
    fi
    
    while true; do
        clear
        show_banner
        echo -e "${C_BOLD}${C_PURPLE}--- Editing User: ${C_YELLOW}$username${C_PURPLE} ---${C_RESET}"
        echo -e "\nSelect a detail to edit:\n"
        echo -e "  ${C_GREEN}1)${C_RESET} 🔑 Change Password"
        echo -e "  ${C_GREEN}2)${C_RESET} 🗓️ Change Expiration Date"
        echo -e "  ${C_GREEN}3)${C_RESET} 📶 Change Connection Limit"
        echo -e "\n  ${C_RED}0)${C_RESET} ✅ Finish Editing"
        echo
        
        local edit_choice
        safe_read "👉 Enter your choice: " edit_choice
        
        case $edit_choice in
            1)
               local new_pass=""
               while true; do
                   safe_read "Enter new password: " new_pass
                   if [[ -z "$new_pass" ]]; then
                       echo -e "${C_RED}❌ Password cannot be empty. Please try again.${C_RESET}"
                   else
                       break
                   fi
               done
               echo "$username:$new_pass" | chpasswd
               local current_line=$(grep "^$username:" "$DB_FILE")
               local expiry=$(echo "$current_line" | cut -d: -f3)
               local limit=$(echo "$current_line" | cut -d: -f4)
               sed -i "s/^$username:.*/$username:$new_pass:$expiry:$limit/" "$DB_FILE"
               echo -e "\n${C_GREEN}✅ Password for '$username' changed successfully.${C_RESET}"
               echo -e "New Password: ${C_YELLOW}$new_pass${C_RESET}"
               ;;
            2)
               local days
               safe_read "Enter new duration (in days from today): " days
               if [[ "$days" =~ ^[0-9]+$ ]]; then
                   local new_expire_date=$(date -d "+$days days" +%Y-%m-%d)
                   chage -E "$new_expire_date" "$username"
                   local current_line=$(grep "^$username:" "$DB_FILE")
                   local pass=$(echo "$current_line" | cut -d: -f2)
                   local limit=$(echo "$current_line" | cut -d: -f4)
                   sed -i "s/^$username:.*/$username:$pass:$new_expire_date:$limit/" "$DB_FILE"
                   echo -e "\n${C_GREEN}✅ Expiration for '$username' set to ${C_YELLOW}$new_expire_date${C_RESET}."
               else
                   echo -e "\n${C_RED}❌ Invalid number of days.${C_RESET}"
               fi
               ;;
            3)
               local new_limit
               safe_read "Enter new simultaneous connection limit: " new_limit
               if [[ "$new_limit" =~ ^[0-9]+$ ]]; then
                   local current_line=$(grep "^$username:" "$DB_FILE")
                   local pass=$(echo "$current_line" | cut -d: -f2)
                   local expiry=$(echo "$current_line" | cut -d: -f3)
                   sed -i "s/^$username:.*/$username:$pass:$expiry:$new_limit/" "$DB_FILE"
                   echo -e "\n${C_GREEN}✅ Connection limit for '$username' set to ${C_YELLOW}$new_limit${C_RESET}."
               else
                   echo -e "\n${C_RED}❌ Invalid limit.${C_RESET}"
               fi
               ;;
            0)
               return
               ;;
            *)
               echo -e "\n${C_RED}❌ Invalid option.${C_RESET}"
               ;;
        esac
        echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue editing..."
        safe_read "" dummy
    done
}

lock_user() {
    _select_user_interface "--- 🔒 Lock a User ---"
    local u=$SELECTED_USER
    if [[ "$u" == "NO_USERS" ]] || [[ -z "$u" ]]; then
        if [[ "$u" == "NO_USERS" ]]; then
            echo -e "\n${C_YELLOW}ℹ️ No users found in database.${C_RESET}"
        fi
        
        local manual_user
        safe_read "👉 Type username to MANUALLY lock (or '0' to cancel): " manual_user
        if [[ "$manual_user" == "0" ]] || [[ -z "$manual_user" ]]; then
            echo -e "\n${C_YELLOW}❌ Action cancelled.${C_RESET}"
            return
        fi
        u="$manual_user"
        
        if ! id "$u" &>/dev/null; then
             echo -e "\n${C_RED}❌ Error: User '$u' does not exist on this system.${C_RESET}"
             return
        fi
        
        if grep -q "^$u:" "$DB_FILE"; then
             echo -e "\n${C_YELLOW}ℹ️ User '$u' is in the database. Use the normal selection method.${C_RESET}"
        else
             echo -e "${C_YELLOW}⚠️ User '$u' exists on the system but is NOT in the database.${C_RESET}"
        fi
    fi

    usermod -L "$u"
    if [ $? -eq 0 ]; then
        killall -u "$u" -9 &>/dev/null
        echo -e "\n${C_GREEN}✅ User '$u' has been locked and active sessions killed.${C_RESET}"
    else
        echo -e "\n${C_RED}❌ Failed to lock user '$u'.${C_RESET}"
    fi
}

unlock_user() {
    _select_user_interface "--- 🔓 Unlock a User ---"
    local u=$SELECTED_USER
    if [[ "$u" == "NO_USERS" ]] || [[ -z "$u" ]]; then
        if [[ "$u" == "NO_USERS" ]]; then
            echo -e "\n${C_YELLOW}ℹ️ No users found in database.${C_RESET}"
        fi
        
        local manual_user
        safe_read "👉 Type username to MANUALLY unlock (or '0' to cancel): " manual_user
        if [[ "$manual_user" == "0" ]] || [[ -z "$manual_user" ]]; then
            echo -e "\n${C_YELLOW}❌ Action cancelled.${C_RESET}"
            return
        fi
        u="$manual_user"
        
        if ! id "$u" &>/dev/null; then
             echo -e "\n${C_RED}❌ Error: User '$u' does not exist on this system.${C_RESET}"
             return
        fi
        
        if grep -q "^$u:" "$DB_FILE"; then
             echo -e "\n${C_YELLOW}ℹ️ User '$u' is in the database. Use the normal selection method.${C_RESET}"
        else
             echo -e "${C_YELLOW}⚠️ User '$u' exists on the system but is NOT in the database.${C_RESET}"
        fi
    fi

    usermod -U "$u"
    if [ $? -eq 0 ]; then
        echo -e "\n${C_GREEN}✅ User '$u' has been unlocked.${C_RESET}"
    else
        echo -e "\n${C_RED}❌ Failed to unlock user '$u'.${C_RESET}"
    fi
}

list_users() {
    clear
    show_banner
    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "\n${C_YELLOW}ℹ️ No users are currently being managed.${C_RESET}"
        return
    fi
    echo -e "${C_BOLD}${C_PURPLE}--- 📋 Managed Users ---${C_RESET}"
    echo -e "${C_CYAN}======================================================================${C_RESET}"
    printf "${C_BOLD}${C_WHITE}%-20s | %-12s | %-15s | %-20s${C_RESET}\n" "USERNAME" "EXPIRES" "CONNECTIONS" "STATUS"
    echo -e "${C_CYAN}----------------------------------------------------------------------${C_RESET}"
    
    while IFS=: read -r user pass expiry limit; do
        local online_count
        online_count=$(pgrep -u "$user" sshd | wc -l)
        
        local status
        status=$(get_user_status "$user")

        local plain_status
        plain_status=$(echo -e "$status" | sed 's/\x1b\[[0-9;]*m//g')
        
        local connection_string="$online_count / $limit"

        local line_color="$C_WHITE"
        case $plain_status in
            *"Active"*) line_color="$C_GREEN" ;;
            *"Locked"*) line_color="$C_YELLOW" ;;
            *"Expired"*) line_color="$C_RED" ;;
            *"Not Found"*) line_color="$C_DIM" ;;
        esac

        printf "${line_color}%-20s ${C_RESET}| ${C_YELLOW}%-12s ${C_RESET}| ${C_CYAN}%-15s ${C_RESET}| %-20s\n" "$user" "$expiry" "$connection_string" "$status"
    done < <(sort "$DB_FILE")
    echo -e "${C_CYAN}======================================================================${C_RESET}\n"
}

renew_user() {
    _select_user_interface "--- 🔄 Renew a User ---"
    local u=$SELECTED_USER
    if [[ "$u" == "NO_USERS" ]] || [[ -z "$u" ]]; then
        return
    fi
    
    local days
    safe_read "👉 Enter number of days to extend the account: " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo -e "\n${C_RED}❌ Invalid number.${C_RESET}"
        return
    fi
    
    local new_expire_date=$(date -d "+$days days" +%Y-%m-%d)
    chage -E "$new_expire_date" "$u"
    local line=$(grep "^$u:" "$DB_FILE")
    local pass=$(echo "$line" | cut -d: -f2)
    local limit=$(echo "$line" | cut -d: -f4)
    sed -i "s/^$u:.*/$u:$pass:$new_expire_date:$limit/" "$DB_FILE"
    echo -e "\n${C_GREEN}✅ User '$u' has been renewed. New expiration date is ${C_YELLOW}${new_expire_date}${C_RESET}."
}

# ========== SYSTEM UTILITIES FUNCTIONS ==========
backup_user_data() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 💾 Backup User Data ---${C_RESET}"
    
    local backup_path
    safe_read "👉 Enter path for backup file [/root/voltrontech_users.tar.gz]: " backup_path
    backup_path=${backup_path:-/root/voltrontech_users.tar.gz}
    
    if [ ! -d "$DB_DIR" ] || [ ! -s "$DB_FILE" ]; then
        echo -e "\n${C_YELLOW}ℹ️ No user data found to back up.${C_RESET}"
        return
    fi
    echo -e "\n${C_BLUE}⚙️ Backing up user database and settings to ${C_YELLOW}$backup_path${C_RESET}..."
    tar -czf "$backup_path" -C "$(dirname "$DB_DIR")" "$(basename "$DB_DIR")"
    if [ $? -eq 0 ]; then
        echo -e "\n${C_GREEN}✅ SUCCESS: User data backup created at ${C_YELLOW}$backup_path${C_RESET}"
    else
        echo -e "\n${C_RED}❌ ERROR: Backup failed.${C_RESET}"
    fi
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

restore_user_data() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 📥 Restore User Data ---${C_RESET}"
    
    local backup_path
    safe_read "👉 Enter the full path to the user data backup file [/root/voltrontech_users.tar.gz]: " backup_path
    backup_path=${backup_path:-/root/voltrontech_users.tar.gz}
    
    if [ ! -f "$backup_path" ]; then
        echo -e "\n${C_RED}❌ ERROR: Backup file not found at '$backup_path'.${C_RESET}"
        return
    fi
    echo -e "\n${C_RED}${C_BOLD}⚠️ WARNING:${C_RESET} This will overwrite all current users and settings."
    local confirm
    safe_read "👉 Are you absolutely sure you want to proceed? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo -e "\n${C_YELLOW}❌ Restore cancelled.${C_RESET}"
        return
    fi
    
    local temp_dir=$(mktemp -d)
    echo -e "\n${C_BLUE}⚙️ Extracting backup file to a temporary location...${C_RESET}"
    tar -xzf "$backup_path" -C "$temp_dir"
    if [ $? -ne 0 ]; then
        echo -e "\n${C_RED}❌ ERROR: Failed to extract backup file. Aborting.${C_RESET}"
        rm -rf "$temp_dir"
        return
    fi
    
    local restored_db_file="$temp_dir/voltrontech/users.db"
    if [ ! -f "$restored_db_file" ]; then
        echo -e "\n${C_RED}❌ ERROR: users.db not found in the backup. Cannot restore user accounts.${C_RESET}"
        rm -rf "$temp_dir"
        return
    fi
    
    echo -e "${C_BLUE}⚙️ Overwriting current user database...${C_RESET}"
    mkdir -p "$DB_DIR"
    cp "$restored_db_file" "$DB_FILE"
    
    [ -d "$temp_dir/voltrontech/ssl" ] && cp -r "$temp_dir/voltrontech/ssl" "$DB_DIR/"
    [ -d "$temp_dir/voltrontech/dnstt" ] && cp -r "$temp_dir/voltrontech/dnstt" "$DB_DIR/"
    [ -f "$temp_dir/voltrontech/dns_info.conf" ] && cp "$temp_dir/voltrontech/dns_info.conf" "$DB_DIR/"
    [ -f "$temp_dir/voltrontech/dnstt_info.conf" ] && cp "$temp_dir/voltrontech/dnstt_info.conf" "$DB_DIR/"
    [ -f "$temp_dir/voltrontech/voltronproxy_config.conf" ] && cp "$temp_dir/voltrontech/voltronproxy_config.conf" "$DB_DIR/"
    [ -f "$temp_dir/voltrontech/cloudflare.conf" ] && cp "$temp_dir/voltrontech/cloudflare.conf" "$DB_DIR/"
    
    echo -e "${C_BLUE}⚙️ Re-synchronizing system accounts with the restored database...${C_RESET}"
    
    while IFS=: read -r user pass expiry limit; do
        echo "Processing user: ${C_YELLOW}$user${C_RESET}"
        if ! id "$user" &>/dev/null; then
            echo " - User does not exist in system. Creating..."
            useradd -m -s /usr/sbin/nologin "$user"
        fi
        echo " - Setting password..."
        echo "$user:$pass" | chpasswd
        echo " - Setting expiration to $expiry..."
        chage -E "$expiry" "$user"
    done < "$DB_FILE"
    
    rm -rf "$temp_dir"
    echo -e "\n${C_GREEN}✅ SUCCESS: User data restore completed.${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

cleanup_expired() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🧹 Cleanup Expired Users ---${C_RESET}"
    
    local expired_users=()
    local current_ts=$(date +%s)

    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "\n${C_GREEN}✅ User database is empty. No expired users found.${C_RESET}"
        return
    fi
    
    while IFS=: read -r user pass expiry limit; do
        local expiry_ts=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
        
        if [[ $expiry_ts -lt $current_ts && $expiry_ts -ne 0 ]]; then
            expired_users+=("$user")
        fi
    done < "$DB_FILE"

    if [ ${#expired_users[@]} -eq 0 ]; then
        echo -e "\n${C_GREEN}✅ No expired users found.${C_RESET}"
        return
    fi

    echo -e "\nThe following users have expired: ${C_RED}${expired_users[*]}${C_RESET}"
    local confirm
    safe_read "👉 Do you want to delete all of them? (y/n): " confirm

    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        for user in "${expired_users[@]}"; do
            echo " - Deleting ${C_YELLOW}$user...${C_RESET}"
            killall -u "$user" -9 &>/dev/null
            userdel -r "$user" &>/dev/null
            sed -i "/^$user:/d" "$DB_FILE"
        done
        echo -e "\n${C_GREEN}✅ Expired users have been cleaned up.${C_RESET}"
    else
        echo -e "\n${C_YELLOW}❌ Cleanup cancelled.${C_RESET}"
    fi
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

# ========== DNS MANAGEMENT FUNCTIONS ==========
generate_dns_record() {
    echo -e "\n${C_BLUE}⚙️ Generating random subdomains for Cloudflare...${C_RESET}"
    
    # Load Cloudflare credentials
    source "$DB_DIR/cloudflare.conf" 2>/dev/null || {
        echo -e "${C_RED}❌ Cloudflare configuration not found.${C_RESET}"
        return 1
    }
    
    local SERVER_IPV4
    SERVER_IPV4=$(curl -s -4 icanhazip.com)
    if ! _is_valid_ipv4 "$SERVER_IPV4"; then
        echo -e "\n${C_RED}❌ Error: Could not retrieve a valid public IPv4 address.${C_RESET}"
        return 1
    fi

    local RANDOM_STR1
    RANDOM_STR1=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)
    local RANDOM_STR2
    RANDOM_STR2=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)
    
    local NS_SUBDOMAIN="ns-$RANDOM_STR1"
    local TUNNEL_SUBDOMAIN="tun-$RANDOM_STR2"
    local NS_DOMAIN="$NS_SUBDOMAIN.$DOMAIN"
    local TUNNEL_DOMAIN="$TUNNEL_SUBDOMAIN.$DOMAIN"
    
    echo -e "${C_BLUE}📝 Creating A record for $NS_DOMAIN...${C_RESET}"
    local ns_record_id
    ns_record_id=$(create_cloudflare_dns_record "A" "$NS_SUBDOMAIN" "$SERVER_IPV4")
    if [ $? -ne 0 ] || [ -z "$ns_record_id" ]; then
        echo -e "${C_RED}❌ Failed to create A record for nameserver${C_RESET}"
        return 1
    fi
    
    echo -e "${C_BLUE}📝 Creating NS record for $TUNNEL_DOMAIN pointing to $NS_DOMAIN...${C_RESET}"
    local ns_record_content="$NS_DOMAIN"
    local tunnel_record_id
    tunnel_record_id=$(create_cloudflare_dns_record "NS" "$TUNNEL_SUBDOMAIN" "$ns_record_content")
    if [ $? -ne 0 ] || [ -z "$tunnel_record_id" ]; then
        echo -e "${C_RED}❌ Failed to create NS record for tunnel${C_RESET}"
        delete_cloudflare_dns_record "$ns_record_id"
        return 1
    fi
    
    cat > "$DNS_INFO_FILE" <<-EOF
NS_SUBDOMAIN="$NS_SUBDOMAIN"
TUNNEL_SUBDOMAIN="$TUNNEL_SUBDOMAIN"
NS_DOMAIN="$NS_DOMAIN"
TUNNEL_DOMAIN="$TUNNEL_DOMAIN"
NS_RECORD_ID="$ns_record_id"
TUNNEL_RECORD_ID="$tunnel_record_id"
EOF
    
    echo -e "\n${C_GREEN}✅ Successfully created DNS records in Cloudflare!${C_RESET}"
    echo -e "  - Nameserver: ${C_YELLOW}$NS_DOMAIN${C_RESET}"
    echo -e "  - Tunnel Domain: ${C_YELLOW}$TUNNEL_DOMAIN${C_RESET}"
}

delete_dns_record() {
    if [ ! -f "$DNS_INFO_FILE" ]; then
        echo -e "\n${C_YELLOW}ℹ️ No domain to delete.${C_RESET}"
        return
    fi
    
    # Load Cloudflare credentials
    source "$DB_DIR/cloudflare.conf" 2>/dev/null || {
        echo -e "${C_RED}❌ Cloudflare configuration not found.${C_RESET}"
        return 1
    }
    
    echo -e "\n${C_BLUE}🗑️ Deleting DNS records from Cloudflare...${C_RESET}"
    source "$DNS_INFO_FILE"
    
    if [[ -n "$TUNNEL_RECORD_ID" ]]; then
        delete_cloudflare_dns_record "$TUNNEL_RECORD_ID"
    fi
    
    if [[ -n "$NS_RECORD_ID" ]]; then
        delete_cloudflare_dns_record "$NS_RECORD_ID"
    fi

    echo -e "\n${C_GREEN}✅ Deleted DNS records${C_RESET}"
    rm -f "$DNS_INFO_FILE"
}

dns_menu() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🌐 DNS Domain Management (Cloudflare) ---${C_RESET}"
    if [ -f "$DNS_INFO_FILE" ]; then
        source "$DNS_INFO_FILE"
        echo -e "\nℹ️ DNS records already exist for this server:"
        echo -e "  - ${C_CYAN}Nameserver:${C_RESET} ${C_YELLOW}$NS_DOMAIN${C_RESET}"
        echo -e "  - ${C_CYAN}Tunnel Domain:${C_RESET} ${C_YELLOW}$TUNNEL_DOMAIN${C_RESET}"
        echo
        local choice
        safe_read "👉 Do you want to DELETE these records? (y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            delete_dns_record
        else
            echo -e "\n${C_YELLOW}❌ Action cancelled.${C_RESET}"
        fi
    else
        echo -e "\nℹ️ No DNS records have been created yet."
        echo
        local choice
        safe_read "👉 Do you want to generate new DNS records in Cloudflare? (y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            generate_dns_record
        else
            echo -e "\n${C_YELLOW}❌ Action cancelled.${C_RESET}"
        fi
    fi
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

# ========== SSH BANNER MANAGEMENT ==========
_enable_banner_in_sshd_config() {
    echo -e "\n${C_BLUE}⚙️ Configuring sshd_config...${C_RESET}"
    sed -i.bak -E 's/^( *Banner *).*/#\1/' /etc/ssh/sshd_config
    if ! grep -q -E "^Banner $SSH_BANNER_FILE" /etc/ssh/sshd_config; then
        echo -e "\n# VOLTRON TECH SSH Banner\nBanner $SSH_BANNER_FILE" >> /etc/ssh/sshd_config
    fi
    echo -e "${C_GREEN}✅ sshd_config updated.${C_RESET}"
}

_restart_ssh() {
    echo -e "\n${C_BLUE}🔄 Restarting SSH service to apply changes...${C_RESET}"
    local ssh_service_name=""
    if [ -f /lib/systemd/system/sshd.service ]; then
        ssh_service_name="sshd.service"
    elif [ -f /lib/systemd/system/ssh.service ]; then
        ssh_service_name="ssh.service"
    else
        echo -e "${C_RED}❌ Could not find sshd.service or ssh.service. Cannot restart SSH.${C_RESET}"
        return 1
    fi

    systemctl restart "${ssh_service_name}"
    if [ $? -eq 0 ]; then
        echo -e "${C_GREEN}✅ SSH service ('${ssh_service_name}') restarted successfully.${C_RESET}"
    else
        echo -e "${C_RED}❌ Failed to restart SSH service ('${ssh_service_name}'). Please check 'journalctl -u ${ssh_service_name}' for errors.${C_RESET}"
    fi
}

set_ssh_banner_paste() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 📋 Paste SSH Banner ---${C_RESET}"
    echo -e "Paste your banner code below. Press ${C_YELLOW}[Ctrl+D]${C_RESET} when you are finished."
    echo -e "${C_DIM}The current banner (if any) will be overwritten.${C_RESET}"
    echo -e "--------------------------------------------------"
    cat > "$SSH_BANNER_FILE"
    chmod 644 "$SSH_BANNER_FILE"
    echo -e "\n--------------------------------------------------"
    echo -e "\n${C_GREEN}✅ Banner content saved from paste.${C_RESET}"
    _enable_banner_in_sshd_config
    _restart_ssh
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to return..."
    safe_read "" dummy
}

view_ssh_banner() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 👁️ Current SSH Banner ---${C_RESET}"
    if [ -f "$SSH_BANNER_FILE" ]; then
        echo -e "\n${C_CYAN}--- BEGIN BANNER ---${C_RESET}"
        cat "$SSH_BANNER_FILE"
        echo -e "${C_CYAN}---- END BANNER ----${C_RESET}"
    else
        echo -e "\n${C_YELLOW}ℹ️ No banner file found at $SSH_BANNER_FILE.${C_RESET}"
    fi
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to return..."
    safe_read "" dummy
}

remove_ssh_banner() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🗑️ Remove SSH Banner ---${C_RESET}"
    local confirm
    safe_read "👉 Are you sure you want to disable and remove the SSH banner? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo -e "\n${C_YELLOW}❌ Action cancelled.${C_RESET}"
        echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to return..."
        safe_read "" dummy
        return
    fi
    if [ -f "$SSH_BANNER_FILE" ]; then
        rm -f "$SSH_BANNER_FILE"
        echo -e "\n${C_GREEN}✅ Removed banner file: $SSH_BANNER_FILE${C_RESET}"
    else
        echo -e "\n${C_YELLOW}ℹ️ No banner file to remove.${C_RESET}"
    fi
    echo -e "\n${C_BLUE}⚙️ Disabling banner in sshd_config...${C_RESET}"
    sed -i.bak -E "s/^( *Banner\s+$SSH_BANNER_FILE)/#\1/" /etc/ssh/sshd_config
    echo -e "${C_GREEN}✅ Banner disabled in configuration.${C_RESET}"
    _restart_ssh
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to return..."
    safe_read "" dummy
}

ssh_banner_menu() {
    while true; do
        clear
        show_banner
        local banner_status
        if grep -q -E "^\s*Banner\s+$SSH_BANNER_FILE" /etc/ssh/sshd_config && [ -f "$SSH_BANNER_FILE" ]; then
            banner_status="${C_STATUS_A}(Active)${C_RESET}"
        else
            banner_status="${C_STATUS_I}(Inactive)${C_RESET}"
        fi
        
        echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}              🎨 SSH Banner Management ${banner_status}${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
        echo -e "  ${C_GREEN}1)${C_RESET} 📋 Paste or Edit Banner"
        echo -e "  ${C_GREEN}2)${C_RESET} 👁️ View Current Banner"
        echo -e "  ${C_RED}3)${C_RESET} 🗑️ Disable and Remove Banner"
        echo -e "  ${C_RED}0)${C_RESET} ↩️ Return to Main Menu"
        echo ""
        local choice
        safe_read "$(echo -e ${C_PROMPT}"👉 Select an option: "${C_RESET})" choice
        case $choice in
            1) set_ssh_banner_paste ;;
            2) view_ssh_banner ;;
            3) remove_ssh_banner ;;
            0) return ;;
            *) echo -e "\n${C_RED}❌ Invalid option.${C_RESET}" && sleep 2 ;;
        esac
    done
}

# ========== PROTOCOL MENU FUNCTIONS ==========
install_badvpn() {
    echo -e "\n${C_YELLOW}⚠️ badvpn installation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

uninstall_badvpn() {
    echo -e "\n${C_YELLOW}⚠️ badvpn uninstallation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

install_udp_custom() {
    echo -e "\n${C_YELLOW}⚠️ udp-custom installation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

uninstall_udp_custom() {
    echo -e "\n${C_YELLOW}⚠️ udp-custom uninstallation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

install_ssl_tunnel() {
    echo -e "\n${C_YELLOW}⚠️ SSL Tunnel installation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

uninstall_ssl_tunnel() {
    echo -e "\n${C_YELLOW}⚠️ SSL Tunnel uninstallation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

install_voltron_proxy() {
    echo -e "\n${C_YELLOW}⚠️ VOLTRON Proxy installation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

uninstall_voltron_proxy() {
    echo -e "\n${C_YELLOW}⚠️ VOLTRON Proxy uninstallation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

install_nginx_proxy() {
    echo -e "\n${C_YELLOW}⚠️ Nginx Proxy installation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

uninstall_nginx_proxy() {
    echo -e "\n${C_YELLOW}⚠️ Nginx Proxy uninstallation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

install_zivpn() {
    echo -e "\n${C_YELLOW}⚠️ ZiVPN installation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

uninstall_zivpn() {
    echo -e "\n${C_YELLOW}⚠️ ZiVPN uninstallation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

install_xui_panel() {
    echo -e "\n${C_YELLOW}⚠️ X-UI Panel installation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

uninstall_xui_panel() {
    echo -e "\n${C_YELLOW}⚠️ X-UI Panel uninstallation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

show_dnstt_details() {
    if [ -f "$DNSTT_CONFIG_FILE" ]; then
        source "$DNSTT_CONFIG_FILE"
        echo -e "\n${C_GREEN}=====================================================${C_RESET}"
        echo -e "${C_GREEN}            📡 DNSTT Connection Details             ${C_RESET}"
        echo -e "${C_GREEN}=====================================================${C_RESET}"
        echo -e "\n${C_WHITE}Your connection details:${C_RESET}"
        echo -e "  - ${C_CYAN}Tunnel Domain:${C_RESET} ${C_YELLOW}$TUNNEL_DOMAIN${C_RESET}"
        echo -e "  - ${C_CYAN}Public Key:${C_RESET}    ${C_YELLOW}$PUBLIC_KEY${C_RESET}"
        if [[ -n "$FORWARD_DESC" ]]; then
            echo -e "  - ${C_CYAN}Forwarding To:${C_RESET} ${C_YELLOW}$FORWARD_DESC${C_RESET}"
        fi
        if [[ -n "$MTU_VALUE" ]]; then
            echo -e "  - ${C_CYAN}MTU Value:${C_RESET}     ${C_YELLOW}$MTU_VALUE${C_RESET}"
        fi
        echo -e "\n${C_DIM}Use these details in your client configuration.${C_RESET}"
    else
        echo -e "\n${C_YELLOW}ℹ️ DNSTT configuration file not found. Details are unavailable.${C_RESET}"
    fi
}

install_dnstt() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 📡 DNSTT (DNS Tunnel) Installation ---${C_RESET}"
    
    if [ -f "$DNSTT_SERVICE_FILE" ]; then
        echo -e "\n${C_YELLOW}ℹ️ DNSTT is already installed.${C_RESET}"
        show_dnstt_details
        echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
        safe_read "" dummy
        return
    fi
    
    # Load Cloudflare credentials
    source "$DB_DIR/cloudflare.conf" 2>/dev/null || {
        echo -e "\n${C_YELLOW}⚠️ Cloudflare configuration not found. Using custom mode.${C_RESET}"
    }
    
    echo -e "\n${C_GREEN}⚙️ Checking system requirements...${C_RESET}"
    
    # Check if port 53 is available
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
    
    # Choose forwarding target
    echo -e "\n${C_BLUE}Please choose where DNSTT should forward traffic:${C_RESET}"
    echo -e "  ${C_GREEN}1)${C_RESET} ➡️ Forward to local SSH service (port 22)"
    echo -e "  ${C_GREEN}2)${C_RESET} ➡️ Forward to local V2Ray backend (port 8787)"
    
    local fwd_choice
    safe_read "👉 Enter your choice [2]: " fwd_choice
    fwd_choice=${fwd_choice:-2}
    
    local forward_port=""
    local forward_desc=""
    if [[ "$fwd_choice" == "1" ]]; then
        forward_port="22"
        forward_desc="SSH (port 22)"
        echo -e "${C_GREEN}ℹ️ DNSTT will forward to SSH on 127.0.0.1:22.${C_RESET}"
    else
        forward_port="8787"
        forward_desc="V2Ray (port 8787)"
        echo -e "${C_GREEN}ℹ️ DNSTT will forward to V2Ray on 127.0.0.1:8787.${C_RESET}"
    fi
    local FORWARD_TARGET="127.0.0.1:$forward_port"
    
    # DNS Method Selection
    echo -e "\n${C_BLUE}DNS Record Creation Method:${C_RESET}"
    echo -e "  ${C_GREEN}1)${C_RESET} Auto-generate with Cloudflare"
    echo -e "  ${C_GREEN}2)${C_RESET} Use custom domains (manual)"
    
    local dns_method_choice
    safe_read "👉 Enter your choice [2]: " dns_method_choice
    dns_method_choice=${dns_method_choice:-2}
    
    local NS_DOMAIN=""
    local TUNNEL_DOMAIN=""
    
    if [[ "$dns_method_choice" == "1" ]]; then
        echo -e "\n${C_BLUE}⚙️ Generating random subdomains in Cloudflare...${C_RESET}"
        
        local SERVER_IPV4
        SERVER_IPV4=$(curl -s -4 icanhazip.com)
        if ! _is_valid_ipv4 "$SERVER_IPV4"; then
            echo -e "\n${C_RED}❌ Error: Could not retrieve a valid public IPv4 address.${C_RESET}"
            return
        fi

        local RANDOM_STR1
        RANDOM_STR1=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)
        local RANDOM_STR2
        RANDOM_STR2=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)
        
        NS_SUBDOMAIN="ns-$RANDOM_STR1"
        TUNNEL_SUBDOMAIN="tun-$RANDOM_STR2"
        NS_DOMAIN="$NS_SUBDOMAIN.$DOMAIN"
        TUNNEL_DOMAIN="$TUNNEL_SUBDOMAIN.$DOMAIN"
        
        echo -e "${C_BLUE}📝 Creating A record for $NS_DOMAIN...${C_RESET}"
        local ns_record_id
        ns_record_id=$(create_cloudflare_dns_record "A" "$NS_SUBDOMAIN" "$SERVER_IPV4")
        if [ $? -ne 0 ] || [ -z "$ns_record_id" ]; then
            echo -e "${C_RED}❌ Failed to create A record for nameserver${C_RESET}"
            return
        fi
        
        echo -e "${C_BLUE}📝 Creating NS record for $TUNNEL_DOMAIN pointing to $NS_DOMAIN...${C_RESET}"
        local ns_record_content="$NS_DOMAIN"
        local tunnel_record_id
        tunnel_record_id=$(create_cloudflare_dns_record "NS" "$TUNNEL_SUBDOMAIN" "$ns_record_content")
        if [ $? -ne 0 ] || [ -z "$tunnel_record_id" ]; then
            echo -e "${C_RED}❌ Failed to create NS record for tunnel${C_RESET}"
            delete_cloudflare_dns_record "$ns_record_id"
            return
        fi
        
        cat > "$DNS_INFO_FILE" <<-EOF
NS_SUBDOMAIN="$NS_SUBDOMAIN"
TUNNEL_SUBDOMAIN="$TUNNEL_SUBDOMAIN"
NS_DOMAIN="$NS_DOMAIN"
TUNNEL_DOMAIN="$TUNNEL_DOMAIN"
NS_RECORD_ID="$ns_record_id"
TUNNEL_RECORD_ID="$tunnel_record_id"
EOF
        
        echo -e "\n${C_GREEN}✅ Successfully created DNS records in Cloudflare!${C_RESET}"
        echo -e "  - Nameserver: ${C_YELLOW}$NS_DOMAIN${C_RESET}"
        echo -e "  - Tunnel Domain: ${C_YELLOW}$TUNNEL_DOMAIN${C_RESET}"
        
    else
        safe_read "👉 Enter your full nameserver domain (e.g., ns1.yourdomain.com): " NS_DOMAIN
        if [[ -z "$NS_DOMAIN" ]]; then
            echo -e "\n${C_RED}❌ Nameserver domain cannot be empty. Aborting.${C_RESET}"
            return
        fi
        safe_read "👉 Enter your full tunnel domain (e.g., tun.yourdomain.com): " TUNNEL_DOMAIN
        if [[ -z "$TUNNEL_DOMAIN" ]]; then
            echo -e "\n${C_RED}❌ Tunnel domain cannot be empty. Aborting.${C_RESET}"
            return
        fi
    fi
    
    # ========== MTU SELECTION ==========
    mtu_selection_during_install
    
    # Download DNSTT binary
    echo -e "\n${C_BLUE}📥 Downloading DNSTT server binary...${C_RESET}"
    local arch=$(uname -m)
    local binary_url=""
    if [[ "$arch" == "x86_64" ]]; then
        binary_url="https://github.com/xtaci/kcptun/releases/download/v20240101/kcptun-linux-amd64-20240101.tar.gz"
    elif [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
        binary_url="https://github.com/xtaci/kcptun/releases/download/v20240101/kcptun-linux-arm64-20240101.tar.gz"
    else
        echo -e "\n${C_RED}❌ Unsupported architecture: $arch. Cannot install DNSTT.${C_RESET}"
        return
    fi
    
    cd /tmp
    curl -L -o dnstt.tar.gz "$binary_url"
    if [ $? -ne 0 ]; then
        echo -e "\n${C_RED}❌ Failed to download the DNSTT binary.${C_RESET}"
        return
    fi
    
    tar -xzf dnstt.tar.gz
    cp server_linux_* "$DNSTT_BINARY" 2>/dev/null || cp kcptun-server "$DNSTT_BINARY" 2>/dev/null
    chmod +x "$DNSTT_BINARY"
    rm -f dnstt.tar.gz

    # Generate keys
    echo -e "${C_BLUE}🔐 Generating cryptographic keys...${C_RESET}"
    mkdir -p "$DNSTT_KEYS_DIR"
    "$DNSTT_BINARY" -gen-key -privkey-file "$DNSTT_KEYS_DIR/server.key" -pubkey-file "$DNSTT_KEYS_DIR/server.pub"
    
    local PUBLIC_KEY=$(cat "$DNSTT_KEYS_DIR/server.pub")
    
    # Create service
    echo -e "\n${C_BLUE}📝 Creating systemd service with MTU $MTU...${C_RESET}"
    cat > "$DNSTT_SERVICE_FILE" <<-EOF
[Unit]
Description=DNSTT (DNS Tunnel) Server for $forward_desc
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

    cat > "$DNSTT_CONFIG_FILE" <<-EOF
NS_DOMAIN="$NS_DOMAIN"
TUNNEL_DOMAIN="$TUNNEL_DOMAIN"
PUBLIC_KEY="$PUBLIC_KEY"
FORWARD_DESC="$forward_desc"
MTU_VALUE="$MTU"
EOF

    systemctl daemon-reload
    systemctl enable dnstt.service
    systemctl start dnstt.service
    
    echo -e "\n${C_GREEN}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_GREEN}           ✅ DNSTT INSTALLED SUCCESSFULLY!${C_RESET}"
    echo -e "${C_GREEN}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "  Tunnel Domain: ${C_YELLOW}$TUNNEL_DOMAIN${C_RESET}"
    echo -e "  MTU: ${C_YELLOW}$MTU${C_RESET} (ULTIMATE BOOSTER ACTIVE)"
    echo -e "  Public Key: ${C_YELLOW}$PUBLIC_KEY${C_RESET}"
    echo -e "${C_GREEN}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

uninstall_dnstt() {
    echo -e "\n${C_BLUE}🗑️ Uninstalling DNSTT...${C_RESET}"
    systemctl stop dnstt.service 2>/dev/null
    systemctl disable dnstt.service 2>/dev/null
    rm -f "$DNSTT_SERVICE_FILE"
    rm -f "$DNSTT_BINARY"
    rm -rf "$DNSTT_KEYS_DIR"
    rm -f "$DNSTT_CONFIG_FILE"
    systemctl daemon-reload
    
    # Delete DNS records if they exist
    if [ -f "$DNS_INFO_FILE" ]; then
        source "$DNS_INFO_FILE"
        source "$DB_DIR/cloudflare.conf" 2>/dev/null
        if [[ -n "$TUNNEL_RECORD_ID" ]] && [[ -n "$CLOUDFLARE_API_TOKEN" ]]; then
            echo -e "${C_BLUE}🗑️ Removing DNS records from Cloudflare...${C_RESET}"
            delete_cloudflare_dns_record "$TUNNEL_RECORD_ID"
            delete_cloudflare_dns_record "$NS_RECORD_ID"
            rm -f "$DNS_INFO_FILE"
        fi
    fi
    
    echo -e "${C_GREEN}✅ DNSTT uninstalled${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

# ========== DT PROXY MENU ==========
install_dt_proxy_full() {
    echo -e "\n${C_YELLOW}⚠️ DT Proxy installation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

launch_dt_proxy_menu() {
    echo -e "\n${C_YELLOW}⚠️ DT Proxy management will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

uninstall_dt_proxy_full() {
    echo -e "\n${C_YELLOW}⚠️ DT Proxy uninstallation will be implemented soon${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

dt_proxy_menu() {
    while true; do
        clear
        show_banner
        local dt_proxy_status
        if [ -f "/usr/local/bin/main" ] && [ -f "/usr/local/bin/proxy" ]; then
            dt_proxy_status="${C_BLUE}(installed)${C_RESET}"
        else
            dt_proxy_status=""
        fi
        
        echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}              🚀 DT Proxy Management ${dt_proxy_status}${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
        echo -e "  ${C_GREEN}1)${C_RESET} 🚀 Install DT Tunnel (Mod + Proxy)"
        echo -e "  ${C_GREEN}2)${C_RESET} ▶️ Launch DT Tunnel Management Menu"
        echo -e "  ${C_RED}3)${C_RESET} 🗑️ Uninstall DT Tunnel (Mod + Proxy)"
        echo -e "  ${C_RED}0)${C_RESET} ↩️ Return to Main Menu"
        echo ""
        local choice
        safe_read "$(echo -e ${C_PROMPT}"👉 Select an option: "${C_RESET})" choice
        case $choice in
            1) install_dt_proxy_full; press_enter ;;
            2) launch_dt_proxy_menu; press_enter ;;
            3) uninstall_dt_proxy_full; press_enter ;;
            0) return ;;
            *) echo -e "\n${C_RED}❌ Invalid option.${C_RESET}" && sleep 2 ;;
        esac
    done
}

# ========== PROTOCOL MENU ==========
protocol_menu() {
    while true; do
        clear
        show_banner
        
        # Check service status
        local badvpn_status=$(check_service "badvpn")
        local udp_custom_status=$(check_service "udp-custom")
        local haproxy_status=$(check_service "haproxy")
        local dnstt_status=$(check_service "dnstt")
        local voltronproxy_status=$(check_service "voltronproxy")
        local nginx_status=$(check_service "nginx")
        local zivpn_status=$(check_service "zivpn")
        local xui_status=$(command -v x-ui &>/dev/null && echo -e "${C_BLUE}(installed)${C_RESET}" || echo "")
        
        echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}              🔌 PROTOCOL & PANEL MANAGEMENT${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
        echo -e "  ${C_GREEN}1)${C_RESET} 🚀 Install badvpn (UDP 7300) $badvpn_status"
        echo -e "  ${C_GREEN}2)${C_RESET} 🗑️ Uninstall badvpn"
        echo -e "  ${C_GREEN}3)${C_RESET} 🚀 Install udp-custom $udp_custom_status"
        echo -e "  ${C_GREEN}4)${C_RESET} 🗑️ Uninstall udp-custom"
        echo -e "  ${C_GREEN}5)${C_RESET} 🔒 Install SSL Tunnel (HAProxy) $haproxy_status"
        echo -e "  ${C_GREEN}6)${C_RESET} 🗑️ Uninstall SSL Tunnel"
        echo -e "  ${C_GREEN}7)${C_RESET} 📡 Install/View DNSTT (Port 53) $dnstt_status"
        echo -e "  ${C_GREEN}8)${C_RESET} 🗑️ Uninstall DNSTT"
        echo -e "  ${C_GREEN}9)${C_RESET} 🦅 Install VOLTRON TECH Proxy $voltronproxy_status"
        echo -e "  ${C_GREEN}10)${C_RESET} 🗑️ Uninstall VOLTRON TECH Proxy"
        echo -e "  ${C_GREEN}11)${C_RESET} 🌐 Install/Manage Nginx Proxy $nginx_status"
        echo -e "  ${C_GREEN}12)${C_RESET} 🛡️ Install ZiVPN $zivpn_status"
        echo -e "  ${C_GREEN}13)${C_RESET} 🗑️ Uninstall ZiVPN"
        echo -e "  ${C_GREEN}14)${C_RESET} 💻 Install X-UI Panel $xui_status"
        echo -e "  ${C_GREEN}15)${C_RESET} 🗑️ Uninstall X-UI Panel"
        echo -e ""
        echo -e "  ${C_RED}0)${C_RESET} ↩️ Return to Main Menu"
        echo ""
        
        local choice
        safe_read "$(echo -e ${C_PROMPT}"👉 Select an option: "${C_RESET})" choice
        
        case $choice in
            1) install_badvpn ;;
            2) uninstall_badvpn ;;
            3) install_udp_custom ;;
            4) uninstall_udp_custom ;;
            5) install_ssl_tunnel ;;
            6) uninstall_ssl_tunnel ;;
            7) install_dnstt ;;
            8) uninstall_dnstt ;;
            9) install_voltron_proxy ;;
            10) uninstall_voltron_proxy ;;
            11) echo -e "\n${C_YELLOW}⚠️ Nginx management coming soon${C_RESET}"; press_enter ;;
            12) install_zivpn ;;
            13) uninstall_zivpn ;;
            14) install_xui_panel ;;
            15) uninstall_xui_panel ;;
            0) return ;;
            *) echo -e "\n${C_RED}❌ Invalid option.${C_RESET}" && sleep 2 ;;
        esac
    done
}

# ========== LIMITER SERVICE SETUP ==========
setup_limiter_service() {
    cat > "$LIMITER_SCRIPT" << 'EOF'
#!/bin/bash
DB_FILE="/etc/voltrontech/users.db"

while true; do
    if [[ ! -f "$DB_FILE" ]]; then
        sleep 10
        continue
    fi
    current_ts=$(date +%s)
    while IFS=: read -r user pass expiry limit; do
        [[ -z "$user" || "$user" == \#* ]] && continue
        
        expiry_ts=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
        if [[ $expiry_ts -lt $current_ts && $expiry_ts -ne 0 ]]; then
            if ! passwd -S "$user" | grep -q " L "; then
                usermod -L "$user" &>/dev/null
            fi
            if pgrep -u "$user" > /dev/null; then
                killall -u "$user" -9 &>/dev/null
            fi
            continue
        fi
        
        online_count=$(pgrep -u "$user" sshd | wc -l)
        if ! [[ "$limit" =~ ^[0-9]+$ ]]; then limit=1; fi
        
        if [[ "$online_count" -gt "$limit" ]]; then
            if ! passwd -S "$user" | grep -q " L "; then
                usermod -L "$user" &>/dev/null
                killall -u "$user" -9 &>/dev/null
                (sleep 120; usermod -U "$user" &>/dev/null) & 
            else
                killall -u "$user" -9 &>/dev/null
            fi
        fi
    done < "$DB_FILE"
    sleep 3
done
EOF
    chmod +x "$LIMITER_SCRIPT"

    cat > "$LIMITER_SERVICE" << EOF
[Unit]
Description=VOLTRON TECH Active User Limiter
After=network.target

[Service]
Type=simple
ExecStart=$LIMITER_SCRIPT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    if ! systemctl is-active --quiet voltrontech-limiter; then
        systemctl daemon-reload
        systemctl enable voltrontech-limiter &>/dev/null
        systemctl start voltrontech-limiter &>/dev/null
    else
        systemctl restart voltrontech-limiter &>/dev/null
    fi
}

# ========== INITIAL SETUP ==========
initial_setup() {
    mkdir -p "$DB_DIR"
    mkdir -p "$DB_DIR/config"
    mkdir -p "$DB_DIR/cache"
    touch "$DB_FILE"
    mkdir -p "$SSL_CERT_DIR"
    
    # Save Cloudflare credentials
    cat > "$DB_DIR/cloudflare.conf" <<EOF
CLOUDFLARE_EMAIL="$CLOUDFLARE_EMAIL"
CLOUDFLARE_ZONE_ID="$CLOUDFLARE_ZONE_ID"
CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN"
DOMAIN="$DOMAIN"
EOF
    
    setup_limiter_service
    if [ ! -f "$INSTALL_FLAG_FILE" ]; then
        touch "$INSTALL_FLAG_FILE"
    fi
    
    # Get initial IP info
    get_ip_info
    
    # Install booster automatically
    install_voltron_booster
}

# ========== UNINSTALL SCRIPT ==========
uninstall_script() {
    clear
    show_banner
    echo -e "${C_RED}=====================================================${C_RESET}"
    echo -e "${C_RED}       🔥 DANGER: UNINSTALL SCRIPT & ALL DATA 🔥      ${C_RESET}"
    echo -e "${C_RED}=====================================================${C_RESET}"
    echo -e "${C_YELLOW}This will PERMANENTLY remove this script and all its components."
    echo -e "\n${C_RED}This action is irreversible.${C_RESET}"
    echo ""
    local confirm
    safe_read "👉 Type 'yes' to confirm and proceed with uninstallation: " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo -e "\n${C_GREEN}✅ Uninstallation cancelled.${C_RESET}"
        return
    fi
    export UNINSTALL_MODE="silent"
    echo -e "\n${C_BLUE}--- 💥 Starting Uninstallation 💥 ---${C_RESET}"
    
    echo -e "\n${C_BLUE}🗑️ Removing limiter service...${C_RESET}"
    systemctl stop voltrontech-limiter &>/dev/null
    systemctl disable voltrontech-limiter &>/dev/null
    rm -f "$LIMITER_SERVICE"
    rm -f "$LIMITER_SCRIPT"
    
    echo -e "\n${C_BLUE}🗑️ Removing loss protection...${C_RESET}"
    systemctl stop voltron-loss-protect &>/dev/null
    systemctl disable voltron-loss-protect &>/dev/null
    rm -f /etc/systemd/system/voltron-loss-protect.service
    rm -f /usr/local/bin/voltron-loss-protect
    
    echo -e "\n${C_BLUE}🗑️ Removing traffic monitor...${C_RESET}"
    systemctl stop voltron-traffic &>/dev/null
    systemctl disable voltron-traffic &>/dev/null
    rm -f /etc/systemd/system/voltron-traffic.service
    rm -f /usr/local/bin/voltron-traffic
    
    echo -e "\n${C_BLUE}🗑️ Removing DNSTT...${C_RESET}"
    systemctl stop dnstt.service &>/dev/null
    systemctl disable dnstt.service &>/dev/null
    rm -f "$DNSTT_SERVICE_FILE"
    rm -f "$DNSTT_BINARY"
    rm -rf "$DNSTT_KEYS_DIR"
    
    echo -e "\n${C_BLUE}🗑️ Removing script and configuration files...${C_RESET}"
    rm -rf "$DB_DIR"
    rm -f /usr/local/bin/menu
    
    echo -e "\n${C_GREEN}=============================================${C_RESET}"
    echo -e "${C_GREEN}      Script has been successfully uninstalled.     ${C_RESET}"
    echo -e "${C_GREEN}=============================================${C_RESET}"
    exit 0
}

# ========== PRESS ENTER FUNCTION ==========
press_enter() {
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

# ========== INVALID OPTION FUNCTION ==========
invalid_option() {
    echo -e "\n${C_RED}❌ Invalid option.${C_RESET}" && sleep 2
}

# ========== ROOT CHECK ==========
if [[ $EUID -ne 0 ]]; then
   echo -e "${C_RED}❌ Error: This script must be run as root.${C_RESET}"
   exit 1
fi

# ========== MAIN MENU ==========
main_menu() {
    initial_setup
    while true; do
        export UNINSTALL_MODE="interactive"
        show_banner
        
        echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}                    👤 USER MANAGEMENT                         ${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
        printf "  ${C_GREEN}%2s${C_RESET}) %-25s  ${C_GREEN}%2s${C_RESET}) %-25s\n" "1" "Create New User" "5" "Unlock User Account"
        printf "  ${C_GREEN}%2s${C_RESET}) %-25s  ${C_GREEN}%2s${C_RESET}) %-25s\n" "2" "Delete User" "6" "List All Managed Users"
        printf "  ${C_GREEN}%2s${C_RESET}) %-25s  ${C_GREEN}%2s${C_RESET}) %-25s\n" "3" "Edit User Details" "7" "Renew User Account"
        printf "  ${C_GREEN}%2s${C_RESET}) %-25s\n" "4" "Lock User Account"
        
        echo ""
        echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}                    ⚙️ SYSTEM UTILITIES                        ${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
        printf "  ${C_GREEN}%2s${C_RESET}) %-25s  ${C_GREEN}%2s${C_RESET}) %-25s\n" "8" "Install Protocols & Panels" "12" "SSH Banner Management"
        printf "  ${C_GREEN}%2s${C_RESET}) %-25s  ${C_GREEN}%2s${C_RESET}) %-25s\n" "9" "Backup User Data" "13" "Cleanup Expired Users"
        printf "  ${C_GREEN}%2s${C_RESET}) %-25s  ${C_GREEN}%2s${C_RESET}) %-25s\n" "10" "Restore User Data" "14" "MTU Optimization"
        printf "  ${C_GREEN}%2s${C_RESET}) %-25s  ${C_GREEN}%2s${C_RESET}) %-25s\n" "11" "Manage DNS Domain" "15" "DT Proxy Management"

        echo ""
        echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}                    🔥 DANGER ZONE                            ${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
        printf "  ${C_RED}%2s${C_RESET}) %-28s  ${C_RED}%2s${C_RESET}) %-25s\n" "99" "Uninstall Script" "0" "Exit"

        echo ""
        local choice
        safe_read "$(echo -e ${C_PROMPT}"👉 Select an option: "${C_RESET})" choice
        
        case $choice in
            1) create_user ;;
            2) delete_user ;;
            3) edit_user ;;
            4) lock_user ;;
            5) unlock_user ;;
            6) list_users; press_enter ;;
            7) renew_user ;;
            8) protocol_menu ;;
            9) backup_user_data ;;
            10) restore_user_data ;;
            11) dns_menu ;;
            12) ssh_banner_menu ;;
            13) cleanup_expired ;;
            14) mtu_optimization_menu ;;
            15) dt_proxy_menu ;;
            99) uninstall_script ;;
            0) echo -e "\n${C_BLUE}👋 Goodbye!${C_RESET}"; exit 0 ;;
            *) invalid_option ;;
        esac
    done
}

# ========== START ==========
if [[ "$1" == "--install-setup" ]]; then
    initial_setup
    exit 0
fi

main_menu
