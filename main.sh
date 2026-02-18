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

# ========== VOLTRON TECH CONFIGURATION ==========
DESEC_TOKEN="c2e8c4545e8a4838c2fabc376fc6c88fbc1b"
DESEC_DOMAIN="voltrontechtx.shop"

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

# ========== INPUT BUFFER CLEANING FUNCTION ==========
clean_input_buffer() {
    # Safisha input buffer kabla ya kusoma
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

# ========== VOLTRON TECH BOOSTER FUNCTIONS ==========
install_voltron_booster() {
    echo -e "\n${C_BLUE}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_BLUE}           🚀 VOLTRON TECH BOOSTER INSTALLATION${C_RESET}"
    echo -e "${C_BLUE}═══════════════════════════════════════════════════════════════${C_RESET}"

    # Enable BBR
    echo -e "\n${C_GREEN}🔧 Enabling BBR Congestion Control...${C_RESET}"
    if ! lsmod | grep -q bbr; then
        modprobe tcp_bbr
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    fi

    # Add BBR to sysctl
    cat >> /etc/sysctl.conf <<EOF
# VOLTRON TECH BOOSTER - BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
    sysctl -p
    echo -e "${C_GREEN}✅ BBR enabled successfully${C_RESET}"

    # TCP Buffer Optimization
    echo -e "\n${C_GREEN}📊 Optimizing TCP Buffers...${C_RESET}"
    cat >> /etc/sysctl.conf <<EOF
# VOLTRON TECH BOOSTER - TCP Buffers
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
EOF
    sysctl -p
    echo -e "${C_GREEN}✅ TCP Buffers optimized${C_RESET}"

    # MTU Optimization
    echo -e "\n${C_GREEN}🔧 Configuring MTU Optimization (512-1800 Support)...${C_RESET}"
    cat >> /etc/sysctl.conf <<EOF
# VOLTRON TECH BOOSTER - MTU
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_base_mss = 512
net.ipv4.tcp_mtu_probe_floor = 48
EOF
    sysctl -p
    echo -e "${C_GREEN}✅ MTU Optimization enabled${C_RESET}"

    # Loss Protection Daemon
    echo -e "\n${C_GREEN}🛡️ Setting up Loss Protection (FEC)...${C_RESET}"
    mkdir -p "$DB_DIR/fec"

    cat > /usr/local/bin/voltron-loss-protect <<'EOF'
#!/bin/bash
# VOLTRON TECH Loss Protection Daemon

FEC_DIR="/etc/voltrontech/fec"
mkdir -p "$FEC_DIR"

calculate_fec_ratio() {
    local loss=$1
    local mtu=$2

    if [ $mtu -le 512 ]; then
        if [ $loss -lt 2 ]; then echo "1.1"
        elif [ $loss -lt 5 ]; then echo "1.3"
        else echo "1.5"; fi
    elif [ $mtu -le 800 ]; then
        if [ $loss -lt 2 ]; then echo "1.2"
        elif [ $loss -lt 5 ]; then echo "1.4"
        else echo "1.7"; fi
    elif [ $mtu -le 1200 ]; then
        if [ $loss -lt 2 ]; then echo "1.3"
        elif [ $loss -lt 5 ]; then echo "1.6"
        else echo "2.0"; fi
    elif [ $mtu -le 1500 ]; then
        if [ $loss -lt 2 ]; then echo "1.4"
        elif [ $loss -lt 5 ]; then echo "1.8"
        else echo "2.2"; fi
    else
        if [ $loss -lt 2 ]; then echo "1.5"
        elif [ $loss -lt 5 ]; then echo "2.0"
        else echo "2.5"; fi
    fi
}

while true; do
    LOSS=$(ping -c 10 -W 1 8.8.8.8 | grep -oP '\d+(?=% packet loss)' || echo "0")
    MTU=$(ip link | grep mtu | head -1 | grep -oP 'mtu \K\d+' || echo "1500")
    FEC_RATIO=$(calculate_fec_ratio $LOSS $MTU)

    echo "$LOSS $MTU $FEC_RATIO" > "$FEC_DIR/current"

    # Apply packet duplication for high loss
    if [ $LOSS -gt 8 ]; then
        iptables -t mangle -A OUTPUT -p tcp --tcp-flags SYN SYN -j MARK --set-mark 3 2>/dev/null
        iptables -t mangle -A OUTPUT -p udp --dport 53 -j MARK --set-mark 3 2>/dev/null
    elif [ $LOSS -gt 3 ]; then
        iptables -t mangle -A OUTPUT -p tcp --tcp-flags SYN SYN -j MARK --set-mark 2 2>/dev/null
        iptables -t mangle -A OUTPUT -p udp --dport 53 -j MARK --set-mark 2 2>/dev/null
    fi

    sleep 30
done
EOF

    chmod +x /usr/local/bin/voltron-loss-protect

    cat > /etc/systemd/system/voltron-loss-protect.service <<EOF
[Unit]
Description=VOLTRON TECH Loss Protection
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
    echo -e "${C_GREEN}✅ Loss Protection enabled${C_RESET}"

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
    echo -e "${C_GREEN}           ✅ VOLTRON TECH BOOSTER INSTALLED!${C_RESET}"
    echo -e "${C_GREEN}═══════════════════════════════════════════════════════════════${C_RESET}"
}

# ========== MTU SELECTION MENU ==========
mtu_optimization_menu() {
    clear
    echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}           📡 VOLTRON TECH MTU OPTIMIZATION${C_RESET}"
    echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo ""
    echo -e "${C_GREEN}Current MTU:${C_RESET} $(ip link | grep mtu | head -1 | grep -oP 'mtu \K\d+')"
    echo -e "${C_GREEN}Current BBR:${C_RESET} $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')"
    echo ""
    echo -e "${C_YELLOW}Select MTU optimization level:${C_RESET}"
    echo ""
    echo -e "  ${C_GREEN}1)${C_RESET} MTU 512   - Best for high loss networks (>10%)"
    echo -e "  ${C_GREEN}2)${C_RESET} MTU 800   - Optimized for mobile networks"
    echo -e "  ${C_GREEN}3)${C_RESET} MTU 1000  - Balanced performance"
    echo -e "  ${C_GREEN}4)${C_RESET} MTU 1200  - Good for stable connections"
    echo -e "  ${C_GREEN}5)${C_RESET} MTU 1500  - Standard Ethernet"
    echo -e "  ${C_GREEN}6)${C_RESET} MTU 1600  - Jumbo Frame Lite"
    echo -e "  ${C_GREEN}7)${C_RESET} MTU 1700  - Jumbo Frame Medium"
    echo -e "  ${C_GREEN}8)${C_RESET} MTU 1800  - Max DNS Tunnel MTU"
    echo -e "  ${C_GREEN}9)${C_RESET} Auto-detect optimal MTU"
    echo -e "  ${C_GREEN}10)${C_RESET} View Current MTU Settings"
    echo -e "  ${C_RED}0)${C_RESET} Return"
    echo ""

    local choice
    safe_read "👉 Select option: " choice

    case $choice in
        1) apply_mtu_optimization 512 ;;
        2) apply_mtu_optimization 800 ;;
        3) apply_mtu_optimization 1000 ;;
        4) apply_mtu_optimization 1200 ;;
        5) apply_mtu_optimization 1500 ;;
        6) apply_mtu_optimization 1600 ;;
        7) apply_mtu_optimization 1700 ;;
        8) apply_mtu_optimization 1800 ;;
        9) auto_detect_mtu ;;
        10) show_mtu_settings ;;
        0) return ;;
        *) echo -e "${C_RED}❌ Invalid option!${C_RESET}" && sleep 2 ;;
    esac
}

apply_mtu_optimization() {
    local mtu=$1
    echo -e "\n${C_BLUE}⚡ Applying MTU $mtu optimization...${C_RESET}"

    local iface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$iface" ]; then
        ip link set dev $iface mtu $mtu 2>/dev/null
        echo -e "${C_GREEN}✅ Interface $iface MTU set to $mtu${C_RESET}"
    fi

    # Update sysctl for this MTU
    local mss=$((mtu - 40))
    sysctl -w net.ipv4.tcp_base_mss=$mss >/dev/null 2>&1

    echo -e "${C_GREEN}✅ MTU optimization complete for $mtu${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

auto_detect_mtu() {
    echo -e "\n${C_BLUE}🔍 Detecting optimal MTU...${C_RESET}"
    local mtu=$(ping -M do -s 1472 -c 2 8.8.8.8 2>/dev/null | grep -o "mtu = [0-9]*" | awk '{print $3}' || echo "1500")
    echo -e "${C_GREEN}✅ Optimal MTU detected: $mtu${C_RESET}"
    apply_mtu_optimization $mtu
}

show_mtu_settings() {
    echo -e "\n${C_BLUE}📊 Current MTU Settings:${C_RESET}"
    echo -e "  ${C_CYAN}Interface MTU:${C_RESET} $(ip link | grep mtu | head -1 | grep -oP 'mtu \K\d+')"
    echo -e "  ${C_CYAN}TCP Base MSS:${C_RESET} $(sysctl net.ipv4.tcp_base_mss 2>/dev/null | awk '{print $3}')"
    echo -e "  ${C_CYAN}TCP Congestion:${C_RESET} $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')"
    echo -e "  ${C_CYAN}MTU Probing:${C_RESET} $(sysctl net.ipv4.tcp_mtu_probing 2>/dev/null | awk '{print $3}')"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

# ========== ORIGINAL FUNCTIONS (with safe_read) ==========

if [[ $EUID -ne 0 ]]; then
   echo -e "${C_RED}❌ Error: This script requires root privileges to run.${C_RESET}"
   exit 1
fi

if ! command -v bc &> /dev/null; then
    echo -e "${C_YELLOW}⚠️ Warning: 'bc' command not found. Attempting to install it...${C_RESET}"
    apt-get update > /dev/null 2>&1 && apt-get install -y bc || {
        echo -e "${C_RED}❌ Error: Failed to install 'bc'. Please install it manually ('apt-get install bc') and re-run the script.${C_RESET}"
        exit 1
    }
fi

_is_valid_ipv4() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

check_and_open_firewall_port() {
    local port="$1"
    local protocol="${2:-tcp}"
    local firewall_detected=false

    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        firewall_detected=true
        if ! ufw status | grep -qw "$port/$protocol"; then
            echo -e "${C_YELLOW}🔥 UFW firewall is active and port ${port}/${protocol} is closed.${C_RESET}"
            local confirm
            safe_read "👉 Do you want to open this port now? (y/n): " confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                ufw allow "$port/$protocol"
                echo -e "${C_GREEN}✅ Port ${port}/${protocol} has been opened in UFW.${C_RESET}"
            else
                echo -e "${C_RED}❌ Warning: Port ${port}/${protocol} was not opened. The service may not work correctly.${C_RESET}"
                return 1
            fi
        else
             echo -e "${C_GREEN}✅ Port ${port}/${protocol} is already open in UFW.${C_RESET}"
        fi
    fi

    if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        firewall_detected=true
        if ! firewall-cmd --list-ports --permanent | grep -qw "$port/$protocol"; then
            echo -e "${C_YELLOW}🔥 firewalld is active and port ${port}/${protocol} is not open.${C_RESET}"
            local confirm
            safe_read "👉 Do you want to open this port now? (y/n): " confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                firewall-cmd --add-port="$port/$protocol" --permanent
                firewall-cmd --reload
                echo -e "${C_GREEN}✅ Port ${port}/${protocol} has been opened in firewalld.${C_RESET}"
            else
                echo -e "${C_RED}❌ Warning: Port ${port}/${protocol} was not opened. The service may not work correctly.${C_RESET}"
                return 1
            fi
        else
            echo -e "${C_GREEN}✅ Port ${port}/${protocol} is already open in firewalld.${C_RESET}"
        fi
    fi

    if ! $firewall_detected; then
        echo -e "${C_BLUE}ℹ️ No active firewall (UFW or firewalld) detected. Assuming ports are open.${C_RESET}"
    fi
    return 0
}

check_and_free_ports() {
    local ports_to_check=("$@")
    for port in "${ports_to_check[@]}"; do
        echo -e "\n${C_BLUE}🔎 Checking if port $port is available...${C_RESET}"
        local conflicting_process_info
        conflicting_process_info=$(ss -lntp | grep ":$port\s" || ss -lunp | grep ":$port\s")
        
        if [[ -n "$conflicting_process_info" ]]; then
            local conflicting_pid
            conflicting_pid=$(echo "$conflicting_process_info" | grep -oP 'pid=\K[0-9]+' | head -n 1)
            local conflicting_name
            conflicting_name=$(echo "$conflicting_process_info" | grep -oP 'users:\(\("(\K[^"]+)' | head -n 1)
            
            echo -e "${C_YELLOW}⚠️ Warning: Port $port is in use by process '${conflicting_name:-unknown}' (PID: ${conflicting_pid:-N/A}).${C_RESET}"
            local kill_confirm
            safe_read "👉 Do you want to attempt to stop this process? (y/n): " kill_confirm
            if [[ "$kill_confirm" == "y" || "$kill_confirm" == "Y" ]]; then
                echo -e "${C_GREEN}🛑 Stopping process PID $conflicting_pid...${C_RESET}"
                systemctl stop "$(ps -p "$conflicting_pid" -o comm=)" &>/dev/null || kill -9 "$conflicting_pid"
                sleep 2
                
                if ss -lntp | grep -q ":$port\s" || ss -lunp | grep -q ":$port\s"; then
                     echo -e "${C_RED}❌ Failed to free port $port. Please handle it manually. Aborting.${C_RESET}"
                     return 1
                else
                     echo -e "${C_GREEN}✅ Port $port has been successfully freed.${C_RESET}"
                fi
            else
                echo -e "${C_RED}❌ Cannot proceed without freeing port $port. Aborting.${C_RESET}"
                return 1
            fi
        else
            echo -e "${C_GREEN}✅ Port $port is free to use.${C_RESET}"
        fi
    done
    return 0
}

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

initial_setup() {
    mkdir -p "$DB_DIR"
    touch "$DB_FILE"
    mkdir -p "$SSL_CERT_DIR"
    
    # Save DESEC credentials
    cat > "$DB_DIR/desec.conf" <<EOF
DESEC_TOKEN="$DESEC_TOKEN"
DESEC_DOMAIN="$DESEC_DOMAIN"
EOF
    
    setup_limiter_service
    if [ ! -f "$INSTALL_FLAG_FILE" ]; then
        touch "$INSTALL_FLAG_FILE"
    fi
    
    # Install booster automatically
    install_voltron_booster
}

generate_dns_record() {
    echo -e "\n${C_BLUE}⚙️ Generating a random domain...${C_RESET}"
    if ! command -v jq &> /dev/null; then
        echo -e "${C_YELLOW}⚠️ jq not found, attempting to install...${C_RESET}"
        apt-get update > /dev/null 2>&1 && apt-get install -y jq || {
            echo -e "${C_RED}❌ Failed to install jq. Cannot manage DNS records.${C_RESET}"
            return 1
        }
    fi
    
    # Load DESEC credentials
    source "$DB_DIR/desec.conf"
    
    local SERVER_IPV4
    SERVER_IPV4=$(curl -s -4 icanhazip.com)
    if ! _is_valid_ipv4 "$SERVER_IPV4"; then
        echo -e "\n${C_RED}❌ Error: Could not retrieve a valid public IPv4 address from icanhazip.com.${C_RESET}"
        return 1
    fi

    local SERVER_IPV6
    SERVER_IPV6=$(curl -s -6 icanhazip.com --max-time 5)

    local RANDOM_SUBDOMAIN="vps-$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)"
    local FULL_DOMAIN="$RANDOM_SUBDOMAIN.$DESEC_DOMAIN"
    local HAS_IPV6="false"

    local API_DATA
    API_DATA=$(printf '[{"subname": "%s", "type": "A", "ttl": 3600, "records": ["%s"]}]' "$RANDOM_SUBDOMAIN" "$SERVER_IPV4")

    if [[ -n "$SERVER_IPV6" ]]; then
        local aaaa_record
        aaaa_record=$(printf ',{"subname": "%s", "type": "AAAA", "ttl": 3600, "records": ["%s"]}' "$RANDOM_SUBDOMAIN" "$SERVER_IPV6")
        API_DATA="${API_DATA%?}${aaaa_record}]"
        HAS_IPV6="true"
    fi

    local CREATE_RESPONSE
    CREATE_RESPONSE=$(curl -s -w "%{http_code}" -X POST "https://desec.io/api/v1/domains/$DESEC_DOMAIN/rrsets/" \
        -H "Authorization: Token $DESEC_TOKEN" -H "Content-Type: application/json" \
        --data "$API_DATA")
    
    local HTTP_CODE=${CREATE_RESPONSE: -3}
    local RESPONSE_BODY=${CREATE_RESPONSE:0:${#CREATE_RESPONSE}-3}

    if [[ "$HTTP_CODE" -ne 201 ]]; then
        echo -e "${C_RED}❌ Failed to create DNS records. API returned HTTP $HTTP_CODE.${C_RESET}"
        return 1
    fi
    
    cat > "$DNS_INFO_FILE" <<-EOF
SUBDOMAIN="$RANDOM_SUBDOMAIN"
FULL_DOMAIN="$FULL_DOMAIN"
HAS_IPV6="$HAS_IPV6"
EOF
    echo -e "\n${C_GREEN}✅ Successfully created domain: ${C_YELLOW}$FULL_DOMAIN${C_RESET}"
}

delete_dns_record() {
    if [ ! -f "$DNS_INFO_FILE" ]; then
        echo -e "\n${C_YELLOW}ℹ️ No domain to delete.${C_RESET}"
        return
    fi
    
    # Load DESEC credentials
    source "$DB_DIR/desec.conf"
    
    echo -e "\n${C_BLUE}🗑️ Deleting DNS records...${C_RESET}"
    source "$DNS_INFO_FILE"
    if [[ -z "$SUBDOMAIN" ]]; then
        echo -e "${C_RED}❌ Could not read record details from config file. Skipping deletion.${C_RESET}"
        return
    fi

    curl -s -X DELETE "https://desec.io/api/v1/domains/$DESEC_DOMAIN/rrsets/$SUBDOMAIN/A/" \
         -H "Authorization: Token $DESEC_TOKEN" > /dev/null

    if [[ "$HAS_IPV6" == "true" ]]; then
        curl -s -X DELETE "https://desec.io/api/v1/domains/$DESEC_DOMAIN/rrsets/$SUBDOMAIN/AAAA/" \
             -H "Authorization: Token $DESEC_TOKEN" > /dev/null
    fi

    echo -e "\n${C_GREEN}✅ Deleted domain: ${C_YELLOW}$FULL_DOMAIN${C_RESET}"
    rm -f "$DNS_INFO_FILE"
}

dns_menu() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🌐 VOLTRON TECH DNS Domain Management ---${C_RESET}"
    if [ -f "$DNS_INFO_FILE" ]; then
        source "$DNS_INFO_FILE"
        echo -e "\nℹ️ A domain already exists for this server:"
        echo -e "  - ${C_CYAN}Domain:${C_RESET} ${C_YELLOW}$FULL_DOMAIN${C_RESET}"
        echo
        local choice
        safe_read "👉 Do you want to DELETE this domain? (y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            delete_dns_record
        else
            echo -e "\n${C_YELLOW}❌ Action cancelled.${C_RESET}"
        fi
    else
        echo -e "\nℹ️ No domain has been generated for this server yet."
        echo
        local choice
        safe_read "👉 Do you want to generate a new random domain now? (y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            generate_dns_record
        else
            echo -e "\n${C_YELLOW}❌ Action cancelled.${C_RESET}"
        fi
    fi
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
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
    _select_user_interface "--- 🗑️ Delete a User (from DB) ---"
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
    _select_user_interface "--- 🔒 Lock a User (from DB) ---"
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
    _select_user_interface "--- 🔓 Unlock a User (from DB) ---"
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
}

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
    
    # Restore other config files if they exist
    [ -d "$temp_dir/voltrontech/ssl" ] && cp -r "$temp_dir/voltrontech/ssl" "$DB_DIR/"
    [ -d "$temp_dir/voltrontech/dnstt" ] && cp -r "$temp_dir/voltrontech/dnstt" "$DB_DIR/"
    [ -f "$temp_dir/voltrontech/dns_info.conf" ] && cp "$temp_dir/voltrontech/dns_info.conf" "$DB_DIR/"
    [ -f "$temp_dir/voltrontech/dnstt_info.conf" ] && cp "$temp_dir/voltrontech/dnstt_info.conf" "$DB_DIR/"
    [ -f "$temp_dir/voltrontech/voltronproxy_config.conf" ] && cp "$temp_dir/voltrontech/voltronproxy_config.conf" "$DB_DIR/"
    [ -f "$temp_dir/voltrontech/desec.conf" ] && cp "$temp_dir/voltrontech/desec.conf" "$DB_DIR/"
    
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
}

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
        show_banner
        local banner_status
        if grep -q -E "^\s*Banner\s+$SSH_BANNER_FILE" /etc/ssh/sshd_config && [ -f "$SSH_BANNER_FILE" ]; then
            banner_status="${C_STATUS_A}(Active)${C_RESET}"
        else
            banner_status="${C_STATUS_I}(Inactive)${C_RESET}"
        fi
        
        echo -e "\n   ${C_TITLE}═════════════════[ ${C_BOLD}🎨 SSH Banner Management ${banner_status} ${C_RESET}${C_TITLE}]═════════════════${C_RESET}"
        echo -e "     ${C_CHOICE}1)${C_RESET} 📋 Paste or Edit Banner"
        echo -e "     ${C_CHOICE}2)${C_RESET} 👁️ View Current Banner"
        echo -e "     ${C_DANGER}3)${C_RESET} 🗑️ Disable and Remove Banner"
        echo -e "   ${C_DIM}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${C_RESET}"
        echo -e "     ${C_WARN}0)${C_RESET} ↩️ Return to Main Menu"
        echo
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

install_udp_custom() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🚀 Installing udp-custom ---${C_RESET}"
    if [ -f "$UDP_CUSTOM_SERVICE_FILE" ]; then
        echo -e "\n${C_YELLOW}ℹ️ udp-custom is already installed.${C_RESET}"
        return
    fi

    echo -e "\n${C_GREEN}⚙️ Creating directory for udp-custom...${C_RESET}"
    rm -rf "$UDP_CUSTOM_DIR"
    mkdir -p "$UDP_CUSTOM_DIR"

    echo -e "\n${C_GREEN}⚙️ Detecting system architecture...${C_RESET}"
    local arch
    arch=$(uname -m)
    local binary_url=""
    if [[ "$arch" == "x86_64" ]]; then
        binary_url="https://github.com/voltrontech/VOLTRON-Tech-Manager/raw/main/udp/udp-custom-linux-amd64"
        echo -e "${C_BLUE}ℹ️ Detected x86_64 (amd64) architecture.${C_RESET}"
    elif [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
        binary_url="https://github.com/voltrontech/VOLTRON-Tech-Manager/raw/main/udp/udp-custom-linux-arm"
        echo -e "${C_BLUE}ℹ️ Detected ARM64 architecture.${C_RESET}"
    else
        echo -e "\n${C_RED}❌ Unsupported architecture: $arch. Cannot install udp-custom.${C_RESET}"
        rm -rf "$UDP_CUSTOM_DIR"
        return
    fi

    echo -e "\n${C_GREEN}📥 Downloading udp-custom binary...${C_RESET}"
    wget -q --show-progress -O "$UDP_CUSTOM_DIR/udp-custom" "$binary_url"
    if [ $? -ne 0 ]; then
        echo -e "\n${C_RED}❌ Failed to download the udp-custom binary.${C_RESET}"
        rm -rf "$UDP_CUSTOM_DIR"
        return
    fi
    chmod +x "$UDP_CUSTOM_DIR/udp-custom"

    echo -e "\n${C_GREEN}📝 Creating default config.json...${C_RESET}"
    cat > "$UDP_CUSTOM_DIR/config.json" <<EOF
{
  "listen": ":36712",
  "stream_buffer": 33554432,
  "receive_buffer": 83886080,
  "auth": {
    "mode": "passwords"
  }
}
EOF
    chmod 644 "$UDP_CUSTOM_DIR/config.json"

    echo -e "\n${C_GREEN}📝 Creating systemd service file...${C_RESET}"
    cat > "$UDP_CUSTOM_SERVICE_FILE" <<EOF
[Unit]
Description=UDP Custom by VOLTRON TECH
After=network.target

[Service]
User=root
Type=simple
ExecStart=$UDP_CUSTOM_DIR/udp-custom server -exclude 53,5300
WorkingDirectory=$UDP_CUSTOM_DIR/
Restart=always
RestartSec=2s

[Install]
WantedBy=default.target
EOF

    echo -e "\n${C_GREEN}▶️ Enabling and starting udp-custom service...${C_RESET}"
    systemctl daemon-reload
    systemctl enable udp-custom.service
    systemctl start udp-custom.service
    sleep 2
    if systemctl is-active --quiet udp-custom; then
        echo -e "\n${C_GREEN}✅ SUCCESS: udp-custom is installed and active.${C_RESET}"
    else
        echo -e "\n${C_RED}❌ ERROR: udp-custom service failed to start.${C_RESET}"
        journalctl -u udp-custom.service -n 15 --no-pager
    fi
}

uninstall_udp_custom() {
    echo -e "\n${C_BOLD}${C_PURPLE}--- 🗑️ Uninstalling udp-custom ---${C_RESET}"
    if [ ! -f "$UDP_CUSTOM_SERVICE_FILE" ]; then
        echo -e "${C_YELLOW}ℹ️ udp-custom is not installed, skipping.${C_RESET}"
        return
    fi
    echo -e "${C_GREEN}🛑 Stopping and disabling udp-custom service...${C_RESET}"
    systemctl stop udp-custom.service >/dev/null 2>&1
    systemctl disable udp-custom.service >/dev/null 2>&1
    echo -e "${C_GREEN}🗑️ Removing systemd service file...${C_RESET}"
    rm -f "$UDP_CUSTOM_SERVICE_FILE"
    systemctl daemon-reload
    echo -e "${C_GREEN}🗑️ Removing udp-custom directory and files...${C_RESET}"
    rm -rf "$UDP_CUSTOM_DIR"
    echo -e "${C_GREEN}✅ udp-custom has been uninstalled successfully.${C_RESET}"
}

install_badvpn() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🚀 Installing badvpn (udpgw) ---${C_RESET}"
    if [ -f "$BADVPN_SERVICE_FILE" ]; then
        echo -e "\n${C_YELLOW}ℹ️ badvpn is already installed.${C_RESET}"
        return
    fi
    check_and_open_firewall_port 7300 udp || return
    echo -e "\n${C_GREEN}🔄 Updating package lists...${C_RESET}"
    apt-get update
    echo -e "\n${C_GREEN}📦 Installing all required packages...${C_RESET}"
    apt-get install -y cmake g++ make screen git build-essential libssl-dev libnspr4-dev libnss3-dev pkg-config
    echo -e "\n${C_GREEN}📥 Cloning badvpn from github...${C_RESET}"
    git clone https://github.com/ambrop72/badvpn.git "$BADVPN_BUILD_DIR"
    cd "$BADVPN_BUILD_DIR" || { echo -e "${C_RED}❌ Failed to change directory to build folder.${C_RESET}"; return; }
    echo -e "\n${C_GREEN}⚙️ Running CMake...${C_RESET}"
    cmake . || { echo -e "${C_RED}❌ CMake configuration failed.${C_RESET}"; rm -rf "$BADVPN_BUILD_DIR"; return; }
    echo -e "\n${C_GREEN}🛠️ Compiling source...${C_RESET}"
    make || { echo -e "${C_RED}❌ Compilation (make) failed.${C_RESET}"; rm -rf "$BADVPN_BUILD_DIR"; return; }
    local badvpn_binary
    badvpn_binary=$(find "$BADVPN_BUILD_DIR" -name "badvpn-udpgw" -type f | head -n 1)
    if [[ -z "$badvpn_binary" || ! -f "$badvpn_binary" ]]; then
        echo -e "${C_RED}❌ ERROR: Could not find the compiled 'badvpn-udpgw' binary after compilation.${C_RESET}"
        rm -rf "$BADVPN_BUILD_DIR"
        return
    fi
    echo -e "${C_GREEN}ℹ️ Found binary at: $badvpn_binary${C_RESET}"
    chmod +x "$badvpn_binary"
    echo -e "\n${C_GREEN}📝 Creating systemd service file...${C_RESET}"
    cat > "$BADVPN_SERVICE_FILE" <<-EOF
[Unit]
Description=BadVPN UDP Gateway
After=network.target
[Service]
ExecStart=$badvpn_binary --listen-addr 0.0.0.0:7300 --max-clients 1000 --max-connections-for-client 8
User=root
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
    echo -e "\n${C_GREEN}▶️ Enabling and starting badvpn service...${C_RESET}"
    systemctl daemon-reload
    systemctl enable badvpn.service
    systemctl start badvpn.service
    sleep 2
    if systemctl is-active --quiet badvpn; then
        echo -e "\n${C_GREEN}✅ SUCCESS: badvpn (udpgw) is installed and active on port 7300.${C_RESET}"
    else
        echo -e "\n${C_RED}❌ ERROR: badvpn service failed to start.${C_RESET}"
        journalctl -u badvpn.service -n 15 --no-pager
    fi
}

uninstall_badvpn() {
    echo -e "\n${C_BOLD}${C_PURPLE}--- 🗑️ Uninstalling badvpn (udpgw) ---${C_RESET}"
    if [ ! -f "$BADVPN_SERVICE_FILE" ]; then
        echo -e "${C_YELLOW}ℹ️ badvpn is not installed, skipping.${C_RESET}"
        return
    fi
    echo -e "${C_GREEN}🛑 Stopping and disabling badvpn service...${C_RESET}"
    systemctl stop badvpn.service >/dev/null 2>&1
    systemctl disable badvpn.service >/dev/null 2>&1
    echo -e "${C_GREEN}🗑️ Removing systemd service file...${C_RESET}"
    rm -f "$BADVPN_SERVICE_FILE"
    systemctl daemon-reload
    echo -e "${C_GREEN}🗑️ Removing badvpn build directory...${C_RESET}"
    rm -rf "$BADVPN_BUILD_DIR"
    echo -e "${C_GREEN}✅ badvpn has been uninstalled successfully.${C_RESET}"
}

install_ssl_tunnel() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🚀 Installing SSL Tunnel (HAProxy) for SSH ---${C_RESET}"
    if ! command -v haproxy &> /dev/null; then
        echo -e "\n${C_YELLOW}⚠️ HAProxy not found. Installing...${C_RESET}"
        apt-get update && apt-get install -y haproxy || { echo -e "${C_RED}❌ Failed to install HAProxy.${C_RESET}"; return; }
    fi
    
    local ssl_port
    safe_read "👉 Enter the port for the SSL tunnel [444]: " ssl_port
    ssl_port=${ssl_port:-444}
    if ! [[ "$ssl_port" =~ ^[0-9]+$ ]] || [ "$ssl_port" -lt 1 ] || [ "$ssl_port" -gt 65535 ]; then
        echo -e "\n${C_RED}❌ Invalid port number. Aborting.${C_RESET}"
        return
    fi
    
    check_and_free_ports "$ssl_port" || return
    check_and_open_firewall_port "$ssl_port" || return

    if [ -f "$SSL_CERT_FILE" ]; then
        local overwrite_cert
        safe_read "SSL certificate already exists. Overwrite? (y/n): " overwrite_cert
        if [[ "$overwrite_cert" != "y" ]]; then
            echo -e "${C_YELLOW}ℹ️ Using existing certificate.${C_RESET}"
        else
            rm -f "$SSL_CERT_FILE"
        fi
    fi
    if [ ! -f "$SSL_CERT_FILE" ]; then
        echo -e "\n${C_GREEN}🔐 Generating self-signed SSL certificate...${C_RESET}"
        openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
            -keyout "$SSL_CERT_FILE" -out "$SSL_CERT_FILE" \
            -subj "/CN=@VOLTRONTECH" \
            >/dev/null 2>&1 || { echo -e "${C_RED}❌ Failed to generate SSL certificate.${C_RESET}"; return; }
        echo -e "${C_GREEN}✅ Certificate created: ${C_YELLOW}$SSL_CERT_FILE${C_RESET}"
    fi
    echo -e "\n${C_GREEN}📝 Creating HAProxy configuration for port $ssl_port...${C_RESET}"
    cat > "$HAPROXY_CONFIG" <<-EOF
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
frontend ssh_ssl_in
    bind *:$ssl_port ssl crt $SSL_CERT_FILE
    mode tcp
    default_backend ssh_backend
backend ssh_backend
    mode tcp
    server ssh_server 127.0.0.1:22
EOF
    echo -e "\n${C_GREEN}▶️ Reloading and starting HAProxy service...${C_RESET}"
    systemctl daemon-reload
    systemctl restart haproxy
    sleep 2
    if systemctl is-active --quiet haproxy; then
        echo -e "\n${C_GREEN}✅ SUCCESS: SSL Tunnel is active.${C_RESET}"
        echo -e "Clients can now connect to this server's IP on port ${C_YELLOW}${ssl_port}${C_RESET} using an SSL/TLS tunnel."
    else
        echo -e "\n${C_RED}❌ ERROR: HAProxy service failed to start.${C_RESET}"
        systemctl status haproxy --no-pager
    fi
}

uninstall_ssl_tunnel() {
    echo -e "\n${C_BOLD}${C_PURPLE}--- 🗑️ Uninstalling SSL Tunnel ---${C_RESET}"
    if ! command -v haproxy &> /dev/null; then
        echo -e "${C_YELLOW}ℹ️ HAProxy not installed, skipping.${C_RESET}"
        return
    fi
    echo -e "${C_GREEN}🛑 Stopping HAProxy service...${C_RESET}"
    systemctl stop haproxy >/dev/null 2>&1
    if [ -f "$HAPROXY_CONFIG" ]; then
        echo -e "${C_GREEN}📝 Restoring default/empty HAProxy config...${C_RESET}"
        cat > "$HAPROXY_CONFIG" <<-EOF
global
    log /dev/log    local0
    log /dev/log    local1 notice
defaults
    log     global
EOF
    fi
    if [ -f "$SSL_CERT_FILE" ]; then
        local delete_cert="y"
        if [[ "$UNINSTALL_MODE" != "silent" ]]; then
            safe_read "👉 Delete the SSL certificate at $SSL_CERT_FILE? (y/n): " delete_cert
        fi
        if [[ "$delete_cert" == "y" ]]; then
            echo -e "${C_GREEN}🗑️ Removing SSL certificate...${C_RESET}"
            rm -f "$SSL_CERT_FILE"
        fi
    fi
    echo -e "${C_GREEN}✅ SSL Tunnel has been uninstalled.${C_RESET}"
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
    echo -e "${C_BOLD}${C_PURPLE}--- 📡 DNSTT (DNS Tunnel) Management ---${C_RESET}"
    if [ -f "$DNSTT_SERVICE_FILE" ]; then
        echo -e "\n${C_YELLOW}ℹ️ DNSTT is already installed.${C_RESET}"
        show_dnstt_details
        return
    fi
    
    # Load DESEC credentials
    source "$DB_DIR/desec.conf"
    
    echo -e "${C_GREEN}⚙️ Forcing release of Port 53 (stopping systemd-resolved)...${C_RESET}"
    systemctl stop systemd-resolved >/dev/null 2>&1
    systemctl disable systemd-resolved >/dev/null 2>&1
    rm -f /etc/resolv.conf
    echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null
    
    echo -e "\n${C_BLUE}🔎 Checking if port 53 (UDP) is available...${C_RESET}"
    if ss -lunp | grep -q ':53\s'; then
        if [[ $(ps -p $(ss -lunp | grep ':53\s' | grep -oP 'pid=\K[0-9]+') -o comm=) == "systemd-resolve" ]]; then
            echo -e "${C_YELLOW}⚠️ Warning: Port 53 is in use by 'systemd-resolved'.${C_RESET}"
            local resolve_confirm
            safe_read "👉 Allow the script to automatically disable it and reconfigure DNS? (y/n): " resolve_confirm
            if [[ "$resolve_confirm" == "y" || "$resolve_confirm" == "Y" ]]; then
                echo -e "${C_GREEN}⚙️ Stopping and disabling systemd-resolved to free port 53...${C_RESET}"
                systemctl stop systemd-resolved
                systemctl disable systemd-resolved
                chattr -i /etc/resolv.conf &>/dev/null
                rm -f /etc/resolv.conf
                echo "nameserver 8.8.8.8" > /etc/resolv.conf
                chattr +i /etc/resolv.conf
                echo -e "${C_GREEN}✅ Port 53 has been freed and DNS set to 8.8.8.8.${C_RESET}"
            else
                echo -e "${C_RED}❌ Cannot proceed without freeing port 53. Aborting.${C_RESET}"
                return
            fi
        else
            check_and_free_ports "53" || return
        fi
    else
        echo -e "${C_GREEN}✅ Port 53 (UDP) is free to use.${C_RESET}"
    fi

    check_and_open_firewall_port 53 udp || return

    local forward_port=""
    local forward_desc=""
    echo -e "\n${C_BLUE}Please choose where DNSTT should forward traffic:${C_RESET}"
    echo -e "  ${C_GREEN}1)${C_RESET} ➡️ Forward to local SSH service (port 22)"
    echo -e "  ${C_GREEN}2)${C_RESET} ➡️ Forward to local V2Ray backend (port 8787)"
    
    local fwd_choice
    safe_read "👉 Enter your choice [2]: " fwd_choice
    fwd_choice=${fwd_choice:-2}
    if [[ "$fwd_choice" == "1" ]]; then
        forward_port="22"
        forward_desc="SSH (port 22)"
        echo -e "${C_GREEN}ℹ️ DNSTT will forward to SSH on 127.0.0.1:22.${C_RESET}"
    elif [[ "$fwd_choice" == "2" ]]; then
        forward_port="8787"
        forward_desc="V2Ray (port 8787)"
        echo -e "${C_GREEN}ℹ️ DNSTT will forward to V2Ray on 127.0.0.1:8787.${C_RESET}"
    else
        echo -e "${C_RED}❌ Invalid choice. Aborting.${C_RESET}"
        return
    fi
    local FORWARD_TARGET="127.0.0.1:$forward_port"
    
    local NS_DOMAIN=""
    local TUNNEL_DOMAIN=""
    local DNSTT_RECORDS_MANAGED="true"
    local NS_SUBDOMAIN=""
    local TUNNEL_SUBDOMAIN=""
    local HAS_IPV6="false"

    local dns_choice
    safe_read "👉 Auto-generate DNS records or use custom ones? (auto/custom) [auto]: " dns_choice
    dns_choice=${dns_choice:-auto}

    if [[ "$dns_choice" == "custom" ]]; then
        DNSTT_RECORDS_MANAGED="false"
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
    else
        echo -e "\n${C_BLUE}⚙️ Configuring DNS records for DNSTT...${C_RESET}"
        local SERVER_IPV4
        SERVER_IPV4=$(curl -s -4 icanhazip.com)
        if ! _is_valid_ipv4 "$SERVER_IPV4"; then
            echo -e "\n${C_RED}❌ Error: Could not retrieve a valid public IPv4 address from icanhazip.com.${C_RESET}"
            return 1
        fi
        
        local SERVER_IPV6
        SERVER_IPV6=$(curl -s -6 icanhazip.com --max-time 5)
        
        local RANDOM_STR
        RANDOM_STR=$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)
        NS_SUBDOMAIN="ns-$RANDOM_STR"
        TUNNEL_SUBDOMAIN="tun-$RANDOM_STR"
        NS_DOMAIN="$NS_SUBDOMAIN.$DESEC_DOMAIN"
        TUNNEL_DOMAIN="$TUNNEL_SUBDOMAIN.$DESEC_DOMAIN"

        local API_DATA
        API_DATA=$(printf '[{"subname": "%s", "type": "A", "ttl": 3600, "records": ["%s"]}, {"subname": "%s", "type": "NS", "ttl": 3600, "records": ["%s."]}]' \
            "$NS_SUBDOMAIN" "$SERVER_IPV4" "$TUNNEL_SUBDOMAIN" "$NS_DOMAIN")

        if [[ -n "$SERVER_IPV6" ]]; then
            local aaaa_record
            aaaa_record=$(printf ',{"subname": "%s", "type": "AAAA", "ttl": 3600, "records": ["%s"]}' "$NS_SUBDOMAIN" "$SERVER_IPV6")
            API_DATA="${API_DATA%?}${aaaa_record}]"
            HAS_IPV6="true"
        fi

        local CREATE_RESPONSE
        CREATE_RESPONSE=$(curl -s -w "%{http_code}" -X POST "https://desec.io/api/v1/domains/$DESEC_DOMAIN/rrsets/" \
            -H "Authorization: Token $DESEC_TOKEN" -H "Content-Type: application/json" \
            --data "$API_DATA")
        
        local HTTP_CODE=${CREATE_RESPONSE: -3}
        local RESPONSE_BODY=${CREATE_RESPONSE:0:${#CREATE_RESPONSE}-3}

        if [[ "$HTTP_CODE" -ne 201 ]]; then
            echo -e "${C_RED}❌ Failed to create DNSTT records. API returned HTTP $HTTP_CODE.${C_RESET}"
            echo "Response: $RESPONSE_BODY" | jq
            return 1
        fi
    fi

    local mtu_value
    safe_read "👉 Enter MTU value (e.g., 512, 1200) or press [Enter] for default: " mtu_value
    local mtu_string=""
    if [[ "$mtu_value" =~ ^[0-9]+$ ]]; then
        mtu_string=" -mtu $mtu_value"
        echo -e "${C_GREEN}ℹ️ Using MTU: $mtu_value${C_RESET}"
    else
        mtu_value=""
        echo -e "${C_YELLOW}ℹ️ Using default MTU.${C_RESET}"
    fi

    echo -e "\n${C_BLUE}📥 Downloading pre-compiled DNSTT server binary...${C_RESET}"
    local arch
    arch=$(uname -m)
    local binary_url=""
    if [[ "$arch" == "x86_64" ]]; then
        binary_url="https://dnstt.network/dnstt-server-linux-amd64"
        echo -e "${C_BLUE}ℹ️ Detected x86_64 (amd64) architecture.${C_RESET}"
    elif [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
        binary_url="https://dnstt.network/dnstt-server-linux-arm64"
        echo -e "${C_BLUE}ℹ️ Detected ARM64 architecture.${C_RESET}"
    else
        echo -e "\n${C_RED}❌ Unsupported architecture: $arch. Cannot install DNSTT.${C_RESET}"
        return
    fi
    
    curl -sL "$binary_url" -o "$DNSTT_BINARY"
    if [ $? -ne 0 ]; then
        echo -e "\n${C_RED}❌ Failed to download the DNSTT binary.${C_RESET}"
        return
    fi
    chmod +x "$DNSTT_BINARY"

    echo -e "${C_BLUE}🔐 Generating cryptographic keys...${C_RESET}"
    mkdir -p "$DNSTT_KEYS_DIR"
    "$DNSTT_BINARY" -gen-key -privkey-file "$DNSTT_KEYS_DIR/server.key" -pubkey-file "$DNSTT_KEYS_DIR/server.pub"
    if [[ ! -f "$DNSTT_KEYS_DIR/server.key" ]]; then
        echo -e "${C_RED}❌ Failed to generate DNSTT keys.${C_RESET}"
        return
    fi
    
    local PUBLIC_KEY
    PUBLIC_KEY=$(cat "$DNSTT_KEYS_DIR/server.pub")
    
    echo -e "\n${C_BLUE}📝 Creating systemd service...${C_RESET}"
    cat > "$DNSTT_SERVICE_FILE" <<-EOF
[Unit]
Description=DNSTT (DNS Tunnel) Server for $forward_desc
After=network.target
[Service]
Type=simple
User=root
ExecStart=$DNSTT_BINARY -udp :53$mtu_string -privkey-file $DNSTT_KEYS_DIR/server.key $TUNNEL_DOMAIN $FORWARD_TARGET
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
    echo -e "\n${C_BLUE}💾 Saving configuration and starting service...${C_RESET}"
    cat > "$DNSTT_CONFIG_FILE" <<-EOF
NS_SUBDOMAIN="$NS_SUBDOMAIN"
TUNNEL_SUBDOMAIN="$TUNNEL_SUBDOMAIN"
NS_DOMAIN="$NS_DOMAIN"
TUNNEL_DOMAIN="$TUNNEL_DOMAIN"
PUBLIC_KEY="$PUBLIC_KEY"
FORWARD_DESC="$forward_desc"
DNSTT_RECORDS_MANAGED="$DNSTT_RECORDS_MANAGED"
HAS_IPV6="$HAS_IPV6"
MTU_VALUE="$mtu_value"
EOF
    systemctl daemon-reload
    systemctl enable dnstt.service
    systemctl start dnstt.service
    sleep 2
    if systemctl is-active --quiet dnstt.service; then
        echo -e "\n${C_GREEN}✅ SUCCESS: DNSTT has been installed and started!${C_RESET}"
        show_dnstt_details
    else
        echo -e "\n${C_RED}❌ ERROR: DNSTT service failed to start.${C_RESET}"
        journalctl -u dnstt.service -n 15 --no-pager
    fi
}

uninstall_dnstt() {
    echo -e "\n${C_BOLD}${C_PURPLE}--- 🗑️ Uninstalling DNSTT ---${C_RESET}"
    if [ ! -f "$DNSTT_SERVICE_FILE" ]; then
        echo -e "${C_YELLOW}ℹ️ DNSTT does not appear to be installed, skipping.${C_RESET}"
        return
    fi
    
    # Load DESEC credentials
    source "$DB_DIR/desec.conf"
    
    local confirm="y"
    if [[ "$UNINSTALL_MODE" != "silent" ]]; then
        safe_read "👉 Are you sure you want to uninstall DNSTT? This will delete DNS records if they were auto-generated. (y/n): " confirm
    fi
    if [[ "$confirm" != "y" ]]; then
        echo -e "\n${C_YELLOW}❌ Uninstallation cancelled.${C_RESET}"
        return
    fi
    echo -e "${C_BLUE}🛑 Stopping and disabling DNSTT service...${C_RESET}"
    systemctl stop dnstt.service > /dev/null 2>&1
    systemctl disable dnstt.service > /dev/null 2>&1
    if [ -f "$DNSTT_CONFIG_FILE" ]; then
        source "$DNSTT_CONFIG_FILE"
        if [[ "$DNSTT_RECORDS_MANAGED" == "true" ]]; then
            echo -e "${C_BLUE}🗑️ Removing auto-generated DNS records...${C_RESET}"
            curl -s -X DELETE "https://desec.io/api/v1/domains/$DESEC_DOMAIN/rrsets/$TUNNEL_SUBDOMAIN/NS/" \
                 -H "Authorization: Token $DESEC_TOKEN" > /dev/null
            curl -s -X DELETE "https://desec.io/api/v1/domains/$DESEC_DOMAIN/rrsets/$NS_SUBDOMAIN/A/" \
                 -H "Authorization: Token $DESEC_TOKEN" > /dev/null
            if [[ "$HAS_IPV6" == "true" ]]; then
                curl -s -X DELETE "https://desec.io/api/v1/domains/$DESEC_DOMAIN/rrsets/$NS_SUBDOMAIN/AAAA/" \
                     -H "Authorization: Token $DESEC_TOKEN" > /dev/null
            fi
            echo -e "${C_GREEN}✅ DNS records have been removed.${C_RESET}"
        else
            echo -e "${C_YELLOW}⚠️ DNS records were manually configured. Please delete them from your DNS provider.${C_RESET}"
        fi
    fi
    echo -e "${C_BLUE}🗑️ Removing service files and binaries...${C_RESET}"
    rm -f "$DNSTT_SERVICE_FILE"
    rm -f "$DNSTT_BINARY"
    rm -rf "$DNSTT_KEYS_DIR"
    rm -f "$DNSTT_CONFIG_FILE"
    systemctl daemon-reload
    
    echo -e "${C_YELLOW}ℹ️ Making /etc/resolv.conf writable again...${C_RESET}"
    chattr -i /etc/resolv.conf &>/dev/null

    echo -e "\n${C_GREEN}✅ DNSTT has been successfully uninstalled.${C_RESET}"
}

install_voltron_proxy() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🦅 Installing VOLTRON TECH Proxy (Websockets/Socks) ---${C_RESET}"
    if [ -f "$VOLTRONPROXY_SERVICE_FILE" ]; then
        echo -e "\n${C_YELLOW}ℹ️ VOLTRON TECH Proxy is already installed.${C_RESET}"
        if [ -f "$VOLTRONPROXY_CONFIG_FILE" ]; then
            source "$VOLTRONPROXY_CONFIG_FILE"
            echo -e "   It is configured to run on port(s): ${C_YELLOW}$PORTS${C_RESET}"
        fi
        return
    fi

    local ports
    safe_read "👉 Enter port(s) for VOLTRON TECH Proxy (e.g., 8080 or 8080 8888) [8080]: " ports
    ports=${ports:-8080}

    local port_array=($ports)
    for port in "${port_array[@]}"; do
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            echo -e "\n${C_RED}❌ Invalid port number: $port. Aborting.${C_RESET}"
            return
        fi
        check_and_free_ports "$port" || return
        check_and_open_firewall_port "$port" tcp || return
    done

    echo -e "\n${C_GREEN}⚙️ Detecting system architecture...${C_RESET}"
    local arch
    arch=$(uname -m)
    local binary_name=""
    if [[ "$arch" == "x86_64" ]]; then
        binary_name="voltronproxy"
        echo -e "${C_BLUE}ℹ️ Detected x86_64 (amd64) architecture.${C_RESET}"
    elif [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
        binary_name="voltronproxyarm"
        echo -e "${C_BLUE}ℹ️ Detected ARM64 architecture.${C_RESET}"
    else
        echo -e "\n${C_RED}❌ Unsupported architecture: $arch. Cannot install VOLTRON TECH Proxy.${C_RESET}"
        return
    fi
    
    local download_url="https://github.com/HumbleTechtz/voltron-tech/releases/latest/download/$binary_name"

    echo -e "\n${C_GREEN}📥 Downloading VOLTRON TECH Proxy binary ($binary_name)...${C_RESET}"
    wget -q --show-progress -O "$VOLTRONPROXY_BINARY" "$download_url"
    if [ $? -ne 0 ]; then
        echo -e "\n${C_RED}❌ Failed to download the VOLTRON TECH Proxy binary.${C_RESET}"
        rm -f "$VOLTRONPROXY_BINARY"
        return
    fi
    chmod +x "$VOLTRONPROXY_BINARY"

    echo -e "\n${C_GREEN}📝 Creating systemd service file...${C_RESET}"
    cat > "$VOLTRONPROXY_SERVICE_FILE" <<EOF
[Unit]
Description=VOLTRON TECH Proxy (Websockets/Socks)
After=network.target

[Service]
User=root
Type=simple
ExecStart=$VOLTRONPROXY_BINARY -p $ports
Restart=always
RestartSec=2s

[Install]
WantedBy=default.target
EOF

    echo -e "\n${C_GREEN}💾 Saving configuration...${C_RESET}"
    echo "PORTS=\"$ports\"" > "$VOLTRONPROXY_CONFIG_FILE"

    echo -e "\n${C_GREEN}▶️ Enabling and starting VOLTRON TECH Proxy service...${C_RESET}"
    systemctl daemon-reload
    systemctl enable voltronproxy.service
    systemctl start voltronproxy.service
    sleep 2
    
    if systemctl is-active --quiet voltronproxy; then
        echo -e "\n${C_GREEN}✅ SUCCESS: VOLTRON TECH Proxy is installed and active.${C_RESET}"
        echo -e "   Listening on port(s): ${C_YELLOW}$ports${C_RESET}"
    else
        echo -e "\n${C_RED}❌ ERROR: VOLTRON TECH Proxy service failed to start.${C_RESET}"
        journalctl -u voltronproxy.service -n 15 --no-pager
    fi
}

uninstall_voltron_proxy() {
    echo -e "\n${C_BOLD}${C_PURPLE}--- 🗑️ Uninstalling VOLTRON TECH Proxy ---${C_RESET}"
    if [ ! -f "$VOLTRONPROXY_SERVICE_FILE" ]; then
        echo -e "${C_YELLOW}ℹ️ VOLTRON TECH Proxy is not installed, skipping.${C_RESET}"
        return
    fi
    echo -e "${C_GREEN}🛑 Stopping and disabling VOLTRON TECH Proxy service...${C_RESET}"
    systemctl stop voltronproxy.service >/dev/null 2>&1
    systemctl disable voltronproxy.service >/dev/null 2>&1
    echo -e "${C_GREEN}🗑️ Removing service file...${C_RESET}"
    rm -f "$VOLTRONPROXY_SERVICE_FILE"
    systemctl daemon-reload
    echo -e "${C_GREEN}🗑️ Removing binary and config files...${C_RESET}"
    rm -f "$VOLTRONPROXY_BINARY"
    rm -f "$VOLTRONPROXY_CONFIG_FILE"
    echo -e "${C_GREEN}✅ VOLTRON TECH Proxy has been uninstalled successfully.${C_RESET}"
}

install_zivpn() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🚀 Installing ZiVPN (UDP/VPN) ---${C_RESET}"
    
    if [ -f "$ZIVPN_SERVICE_FILE" ]; then
        echo -e "\n${C_YELLOW}ℹ️ ZiVPN is already installed.${C_RESET}"
        return
    fi

    echo -e "\n${C_GREEN}⚙️ Checking system architecture...${C_RESET}"
    local arch=$(uname -m)
    local zivpn_url=""
    
    if [[ "$arch" == "x86_64" ]]; then
        zivpn_url="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
        echo -e "${C_BLUE}ℹ️ Detected AMD64/x86_64 architecture.${C_RESET}"
    elif [[ "$arch" == "aarch64" ]]; then
        zivpn_url="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"
        echo -e "${C_BLUE}ℹ️ Detected ARM64 architecture.${C_RESET}"
    elif [[ "$arch" == "armv7l" || "$arch" == "arm" ]]; then
         zivpn_url="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm"
         echo -e "${C_BLUE}ℹ️ Detected ARM architecture.${C_RESET}"
    else
        echo -e "${C_RED}❌ Unsupported architecture: $arch${C_RESET}"
        return
    fi

    echo -e "\n${C_GREEN}📦 Downloading ZiVPN binary...${C_RESET}"
    if ! wget -q --show-progress -O "$ZIVPN_BIN" "$zivpn_url"; then
        echo -e "${C_RED}❌ Download failed. Check internet connection.${C_RESET}"
        return
    fi
    chmod +x "$ZIVPN_BIN"

    echo -e "\n${C_GREEN}⚙️ Configuring ZIVPN...${C_RESET}"
    mkdir -p "$ZIVPN_DIR"
    
    echo -e "${C_BLUE}🔐 Generating self-signed certificates...${C_RESET}"
    if ! command -v openssl &>/dev/null; then apt-get install -y openssl &>/dev/null; fi
    
    openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
        -subj "/C=US/ST=California/L=Los Angeles/O=VOLTRON TECH/OU=IT Department/CN=zivpn" \
        -keyout "$ZIVPN_KEY_FILE" -out "$ZIVPN_CERT_FILE" 2>/dev/null

    if [ ! -f "$ZIVPN_CERT_FILE" ]; then
        echo -e "${C_RED}❌ Failed to generate certificates.${C_RESET}"
        return
    fi

    echo -e "${C_BLUE}🔧 Tuning system network parameters...${C_RESET}"
    sysctl -w net.core.rmem_max=16777216 >/dev/null
    sysctl -w net.core.wmem_max=16777216 >/dev/null

    echo -e "${C_BLUE}📝 Creating systemd service file...${C_RESET}"
    cat <<EOF > "$ZIVPN_SERVICE_FILE"
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$ZIVPN_DIR
ExecStart=$ZIVPN_BIN server -c $ZIVPN_CONFIG_FILE
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

    echo -e "\n${C_YELLOW}🔑 ZiVPN Password Setup${C_RESET}"
    local input_config
    safe_read "👉 Enter passwords separated by commas (e.g., user1,user2) [Default: 'zi']: " input_config
    
    local json_passwords
    if [ -n "$input_config" ]; then
        IFS=',' read -r -a config_array <<< "$input_config"
        json_passwords=$(printf '"%s",' "${config_array[@]}")
        json_passwords="[${json_passwords%,}]"
    else
        json_passwords='["zi"]'
    fi

    cat <<EOF > "$ZIVPN_CONFIG_FILE"
{
  "listen": ":5667",
   "cert": "$ZIVPN_CERT_FILE",
   "key": "$ZIVPN_KEY_FILE",
   "obfs":"zivpn",
   "auth": {
    "mode": "passwords", 
    "config": $json_passwords
  }
}
EOF

    echo -e "\n${C_GREEN}🚀 Starting ZiVPN Service...${C_RESET}"
    systemctl daemon-reload
    systemctl enable zivpn.service
    systemctl start zivpn.service

    echo -e "${C_BLUE}🔥 Configuring Firewall Rules (Redirecting 6000-19999 -> 5667)...${C_RESET}"
    
    local iface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    
    if [ -n "$iface" ]; then
        iptables -t nat -A PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667
    else
        echo -e "${C_YELLOW}⚠️ Could not detect default interface for IPTables redirection.${C_RESET}"
    fi

    if command -v ufw &>/dev/null; then
        ufw allow 6000:19999/udp >/dev/null
        ufw allow 5667/udp >/dev/null
    fi

    rm -f zi.sh zi2.sh 2>/dev/null

    if systemctl is-active --quiet zivpn.service; then
        echo -e "\n${C_GREEN}✅ ZiVPN Installed Successfully!${C_RESET}"
        echo -e "   - UDP Port: 5667 (Direct)"
        echo -e "   - UDP Ports: 6000-19999 (Forwarded)"
    else
        echo -e "\n${C_RED}❌ ZiVPN Service failed to start. Check logs: journalctl -u zivpn.service${C_RESET}"
    fi
}

uninstall_zivpn() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🗑️ Uninstall ZiVPN ---${C_RESET}"
    
    if [ ! -f "$ZIVPN_SERVICE_FILE" ] && [ ! -f "$ZIVPN_BIN" ]; then
        echo -e "\n${C_YELLOW}ℹ️ ZiVPN does not appear to be installed.${C_RESET}"
        return
    fi

    local confirm
    safe_read "👉 Are you sure you want to uninstall ZiVPN? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo -e "${C_YELLOW}Cancelled.${C_RESET}"
        return
    fi

    echo -e "\n${C_BLUE}🛑 Stopping services...${C_RESET}"
    systemctl stop zivpn.service 2>/dev/null
    systemctl disable zivpn.service 2>/dev/null
    
    echo -e "${C_BLUE}🗑️ Removing files...${C_RESET}"
    rm -f "$ZIVPN_SERVICE_FILE"
    rm -rf "$ZIVPN_DIR"
    rm -f "$ZIVPN_BIN"
    
    systemctl daemon-reload
    
    sync
    echo 3 > /proc/sys/vm/drop_caches

    echo -e "\n${C_GREEN}✅ ZiVPN Uninstalled Successfully.${C_RESET}"
}

purge_nginx() {
    local mode="$1"
    if [[ "$mode" != "silent" ]]; then
        clear
        show_banner
        echo -e "${C_BOLD}${C_PURPLE}--- 🔥 Purge Nginx Installation ---${C_RESET}"
        if ! command -v nginx &> /dev/null; then
            echo -e "\n${C_YELLOW}ℹ️ Nginx is not installed. Nothing to do.${C_RESET}"
            return
        fi
        local confirm
        safe_read "👉 This will COMPLETELY REMOVE Nginx and all its configuration files. Are you sure? (y/n): " confirm
        if [[ "$confirm" != "y" ]]; then
            echo -e "\n${C_YELLOW}❌ Uninstallation cancelled.${C_RESET}"
            return
        fi
    fi
    echo -e "\n${C_BLUE}🛑 Stopping Nginx service...${C_RESET}"
    systemctl stop nginx >/dev/null 2>&1
    echo -e "\n${C_BLUE}🗑️ Purging Nginx packages...${C_RESET}"
    apt-get purge -y nginx nginx-common >/dev/null 2>&1
    apt-get autoremove -y >/dev/null 2>&1
    echo -e "\n${C_BLUE}🗑️ Removing leftover files...${C_RESET}"
    rm -f /etc/ssl/certs/nginx-selfsigned.pem
    rm -f /etc/ssl/private/nginx-selfsigned.key
    rm -rf /etc/nginx
    rm -f "${NGINX_CONFIG_FILE}.bak"
    rm -f "${NGINX_CONFIG_FILE}.bak.certbot"
    rm -f "${NGINX_CONFIG_FILE}.bak.selfsigned"
    if [[ "$mode" != "silent" ]]; then
        echo -e "\n${C_GREEN}✅ Nginx has been completely purged from the system.${C_RESET}"
    fi
}

install_nginx_proxy() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🚀 Installing Nginx Main Proxy (Ports 80 & 443) ---${C_RESET}"
    if command -v nginx &> /dev/null; then
        echo -e "\n${C_YELLOW}⚠️ An existing Nginx installation was found.${C_RESET}"
        local confirm_purge
        safe_read "👉 To ensure a clean setup, the existing Nginx will be purged. Continue? (y/n): " confirm_purge
        if [[ "$confirm_purge" != "y" ]]; then
            echo -e "\n${C_RED}❌ Installation cancelled.${C_RESET}"
            return
        fi
        purge_nginx "silent"
    fi
    echo -e "\n${C_BLUE}📦 Installing Nginx package...${C_RESET}"
    apt-get update && apt-get install -y nginx || { echo -e "${C_RED}❌ Failed to install Nginx.${C_RESET}"; return; }
    
    check_and_free_ports "80" "443" || return

    echo -e "\n${C_GREEN}🔐 Generating self-signed SSL certificate for Nginx...${C_RESET}"
    local SSL_CERT="/etc/ssl/certs/nginx-selfsigned.pem"
    local SSL_KEY="/etc/ssl/private/nginx-selfsigned.key"
    mkdir -p /etc/ssl/certs /etc/ssl/private
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout "$SSL_KEY" \
        -out "$SSL_CERT" \
        -subj "/CN=voltrontech.proxy" >/dev/null 2>&1 || { echo -e "${C_RED}❌ Failed to generate SSL certificate.${C_RESET}"; return; }
    echo -e "\n${C_GREEN}📝 Applying Nginx reverse proxy configuration...${C_RESET}"
    mv "$NGINX_CONFIG_FILE" "${NGINX_CONFIG_FILE}.bak" 2>/dev/null
    cat > "$NGINX_CONFIG_FILE" <<'EOF'
server {
    server_tokens off;
    server_name _;
    listen 80;
    listen [::]:80;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    ssl_certificate /etc/ssl/certs/nginx-selfsigned.pem;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!eNULL:!MD5:!DES:!RC4:!ADH!SSLv3:!EXP!PSK!DSS;
    resolver 8.8.8.8;
    location ~ ^/(?<fwdport>\d+)/(?<fwdpath>.*)$ {
        client_max_body_size 0;
        client_body_timeout 1d;
        grpc_read_timeout 1d;
        grpc_socket_keepalive on;
        proxy_read_timeout 1d;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_socket_keepalive on;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        if ($content_type ~* "GRPC") { grpc_pass grpc://127.0.0.1:$fwdport$is_args$args; break; }
        proxy_pass http://127.0.0.1:$fwdport$is_args$args;
        break;
    }
    location / {
        proxy_read_timeout 3600s;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_http_version 1.1;
        proxy_socket_keepalive on;
        tcp_nodelay on;
        tcp_nopush off;
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF
    echo -e "\n${C_GREEN}▶️ Restarting Nginx service...${C_RESET}"
    systemctl restart nginx
    sleep 2
    if systemctl is-active --quiet nginx; then
        echo -e "\n${C_GREEN}✅ SUCCESS: Nginx Reverse Proxy is active on ports 80 & 443.${C_RESET}"
    else
        echo -e "\n${C_RED}❌ ERROR: Nginx service failed to start.${C_RESET}"
        systemctl status nginx --no-pager
        mv "${NGINX_CONFIG_FILE}.bak" "$NGINX_CONFIG_FILE" 2>/dev/null
    fi
}

_install_certbot() {
    if command -v certbot &> /dev/null; then
        echo -e "${C_GREEN}✅ Certbot is already installed.${C_RESET}"
        return 0
    fi
    echo -e "${C_YELLOW}⚠️ Certbot (for SSL) is not found.${C_RESET}"
    local confirm_install
    safe_read "👉 Do you want to install Certbot now? (y/n): " confirm_install
    if [[ "$confirm_install" != "y" ]]; then
        echo -e "${C_RED}❌ Installation skipped. Cannot proceed.${C_RESET}"
        return 1
    fi
    echo -e "${C_BLUE}📦 Installing Certbot...${C_RESET}"
    apt-get update > /dev/null 2>&1
    apt-get install -y certbot || {
        echo -e "${C_RED}❌ Failed to install Certbot.${C_RESET}"
        return 1
    }
    echo -e "${C_GREEN}✅ Certbot installed successfully.${C_RESET}"
    return 0
}

request_certbot_ssl() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🔒 Request Let's Encrypt SSL (Certbot) ---${C_RESET}"
    if ! systemctl is-active --quiet nginx; then
        echo -e "\n${C_RED}❌ Nginx is not running. Please ensure Nginx is installed and active.${C_RESET}"
        return
    fi

    _install_certbot || return
    
    echo
    local domain_name
    safe_read "👉 Enter your domain name (e.g., vps.example.com): " domain_name
    if [[ -z "$domain_name" ]]; then
        echo -e "\n${C_RED}❌ Domain name cannot be empty. Aborting.${C_RESET}"
        return
    fi
    
    local email
    safe_read "👉 Enter your email address (for Let's Encrypt): " email
    if [[ -z "$email" ]]; then
        echo -e "\n${C_RED}❌ Email address cannot be empty. Aborting.${C_RESET}"
        return
    fi
    
    echo -e "\n${C_BLUE}🛑 Stopping Nginx temporarily for validation...${C_RESET}"
    systemctl stop nginx
    sleep 2

    if ss -lntp | grep -q ":80\s"; then
         echo -e "${C_RED}❌ Failed to free port 80, another process might be using it. Aborting.${C_RESET}"
         systemctl start nginx
         return
    fi

    echo -e "\n${C_BLUE}🚀 Requesting certificate for ${C_YELLOW}$domain_name...${C_RESET}"
    certbot certonly --standalone -d "$domain_name" --non-interactive --agree-tos -m "$email"
    
    if [ $? -ne 0 ]; then
        echo -e "\n${C_RED}❌ Certbot failed to obtain a certificate.${C_RESET}"
        echo -e "${C_YELLOW}ℹ️ Please check your domain's DNS 'A' record points to this server's IP.${C_RESET}"
        systemctl start nginx
        return
    fi

    local SSL_CERT_LIVE="/etc/letsencrypt/live/$domain_name/fullchain.pem"
    local SSL_KEY_LIVE="/etc/letsencrypt/live/$domain_name/privkey.pem"

    if [ ! -f "$SSL_CERT_LIVE" ] || [ ! -f "$SSL_KEY_LIVE" ]; then
        echo -e "\n${C_RED}❌ Certbot succeeded, but cert files not found at expected location.${C_RESET}"
        systemctl start nginx
        return
    fi

    echo -e "\n${C_GREEN}✅ Certificate obtained successfully!${C_RESET}"
    echo -e "${C_BLUE}📝 Updating Nginx configuration...${C_RESET}"

    cp "$NGINX_CONFIG_FILE" "${NGINX_CONFIG_FILE}.bak.selfsigned"
    
    sed -i "s|server_name _;|server_name $domain_name;|" "$NGINX_CONFIG_FILE"
    sed -i "s|ssl_certificate /etc/ssl/certs/nginx-selfsigned.pem;|ssl_certificate $SSL_CERT_LIVE;|" "$NGINX_CONFIG_FILE"
    sed -i "s|ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;|ssl_certificate_key $SSL_KEY_LIVE;|" "$NGINX_CONFIG_FILE"

    echo -e "\n${C_BLUE}▶️ Restarting Nginx with new certificate...${C_RESET}"
    systemctl start nginx
    sleep 2
    
    if systemctl is-active --quiet nginx; then
        echo -e "\n${C_GREEN}✅ SUCCESS: Nginx is active with your new Let's Encrypt certificate!${C_RESET}"
    else
        echo -e "\n${C_RED}❌ ERROR: Nginx failed to start with the new certificate.${C_RESET}"
        echo -e "${C_YELLOW}🔄 Restoring self-signed certificate config...${C_RESET}"
        mv "${NGINX_CONFIG_FILE}.bak.selfsigned" "$NGINX_CONFIG_FILE"
        systemctl restart nginx
    fi
}

nginx_proxy_menu() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🌐 Nginx Main Proxy Management ---${C_RESET}"
    if systemctl is-active --quiet nginx; then
        echo -e "\n${C_GREEN}✅ Nginx Main Proxy is currently installed and active.${C_RESET}"
        
        local cert_type
        if grep -q "letsencrypt" "$NGINX_CONFIG_FILE"; then
            cert_type="${C_STATUS_A}(Let's Encrypt)${C_RESET}"
        else
            cert_type="${C_STATUS_I}(Self-Signed)${C_RESET}"
        fi

        echo -e "\nSelect an option:\n"
        echo -e "  ${C_GREEN}1)${C_RESET} 🔒 Request/Renew SSL (Certbot) ${cert_type}"
        echo -e "  ${C_GREEN}2)${C_RESET} 🔥 Purge Nginx Proxy Installation"
        echo -e "\n  ${C_RED}0)${C_RESET} ↩️ Return to previous menu"
        echo
        local choice
        safe_read "👉 Enter your choice: " choice
        case $choice in
            1) request_certbot_ssl; press_enter ;;
            2) purge_nginx ;;
            0) return ;;
            *) echo -e "\n${C_RED}❌ Invalid option.${C_RESET}" ;;
        esac
    else
        echo -e "\n${C_YELLOW}ℹ️ Nginx Main Proxy is not installed or inactive.${C_RESET}"
        echo -e "\nSelect an option:\n"
        echo -e "  ${C_GREEN}1)${C_RESET} 🚀 Install Nginx Main Proxy (80/443)"
        echo -e "\n  ${C_RED}0)${C_RESET} ↩️ Return to previous menu"
        echo
        local choice
        safe_read "👉 Enter your choice: " choice
        case $choice in
            1) install_nginx_proxy ;;
            0) return ;;
            *) echo -e "\n${C_RED}❌ Invalid option.${C_RESET}" ;;
        esac
    fi
}

install_xui_panel() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🚀 Install X-UI Panel ---${C_RESET}"
    echo -e "\nThis will download and run the official installation script for X-UI."
    echo -e "Choose an installation option:\n"
    echo -e "  ${C_GREEN}1)${C_RESET} Install the latest version of X-UI"
    echo -e "  ${C_GREEN}2)${C_RESET} Install a specific version of X-UI"
    echo -e "\n  ${C_RED}0)${C_RESET} ❌ Cancel Installation"
    echo
    local choice
    safe_read "👉 Select an option: " choice
    case $choice in
        1)
            echo -e "\n${C_BLUE}⚙️ Installing the latest version...${C_RESET}"
            bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh)
            ;;
        2)
            local version
            safe_read "👉 Enter the version to install (e.g., 1.8.0): " version
            if [[ -z "$version" ]]; then
                echo -e "\n${C_RED}❌ Version number cannot be empty.${C_RESET}"
                return
            fi
            echo -e "\n${C_BLUE}⚙️ Installing version ${C_YELLOW}$version...${C_RESET}"
            VERSION=$version bash <(curl -Ls "https://raw.githubusercontent.com/alireza0/x-ui/$version/install.sh") "$version"
            ;;
        0)
            echo -e "\n${C_YELLOW}❌ Installation cancelled.${C_RESET}"
            ;;
        *)
            echo -e "\n${C_RED}❌ Invalid option.${C_RESET}"
            ;;
    esac
}

uninstall_xui_panel() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🗑️ Uninstall X-UI Panel ---${C_RESET}"
    if ! command -v x-ui &> /dev/null; then
        echo -e "\n${C_YELLOW}ℹ️ X-UI does not appear to be installed.${C_RESET}"
        return
    fi
    local confirm
    safe_read "👉 Are you sure you want to thoroughly uninstall X-UI? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        echo -e "\n${C_BLUE}⚙️ Running the default X-UI uninstaller first...${C_RESET}"
        x-ui uninstall >/dev/null 2>&1
        echo -e "\n${C_BLUE}🧹 Performing a full cleanup to ensure complete removal...${C_RESET}"
        echo " - Stopping and disabling x-ui service..."
        systemctl stop x-ui >/dev/null 2>&1
        systemctl disable x-ui >/dev/null 2>&1
        echo " - Removing x-ui files and directories..."
        rm -f /etc/systemd/system/x-ui.service
        rm -f /usr/local/bin/x-ui
        rm -rf /usr/local/x-ui/
        rm -rf /etc/x-ui/
        echo " - Reloading systemd daemon..."
        systemctl daemon-reload
        echo -e "\n${C_GREEN}✅ X-UI has been thoroughly uninstalled.${C_RESET}"
    else
        echo -e "\n${C_YELLOW}❌ Uninstallation cancelled.${C_RESET}"
    fi
}

show_banner() {
    local os_name=$(grep -oP 'PRETTY_NAME="\K[^"]+' /etc/os-release || echo "Linux")
    local up_time=$(uptime -p | sed 's/up //')
    local ram_usage=$(free -m | awk '/^Mem:/{printf "%.2f", $3*100/$2}')
    local ram_total=$(free -h | awk '/^Mem:/ {print $2}')
    local cpu_cores=$(nproc)

    local cpu_usage
    cpu_usage=$(top -bn1 | grep -i 'cpu(s)' | awk '{print $2 + $4}' | awk '{printf "%.1f", $1}')
    
    local online_users=0
    if [[ -s "$DB_FILE" ]]; then
        while IFS=: read -r user pass expiry limit; do
           local count=$(pgrep -u "$user" sshd | wc -l)
           online_users=$((online_users + count))
        done < "$DB_FILE"
    fi
    
    local total_users=0
    if [[ -s "$DB_FILE" ]]; then total_users=$(grep -c . "$DB_FILE"); fi
    
    local managed_domain="Not Generated"
    if [ -f "$DNS_INFO_FILE" ]; then
        managed_domain=$(grep 'FULL_DOMAIN' "$DNS_INFO_FILE" | cut -d'"' -f2)
    fi

    clear
    echo
    echo -e "${C_TITLE}❖ ── 🦅 ${C_BOLD}VOLTRON TECH v4.0 (Ultimate Booster)${C_RESET}${C_TITLE} 🦅 ── ❖${C_RESET}"
    echo
    echo -e "${C_DIM}    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${C_RESET}"
    printf "    ${C_CYAN}%-12s${C_RESET} %-25s ${C_CYAN}%-12s${C_RESET} %s\n" "OS:" "$os_name" "Online:" "$online_users Sessions"
    printf "    ${C_CYAN}%-12s${C_RESET} %-25s ${C_CYAN}%-12s${C_RESET} %s\n" "Uptime:" "$up_time" "Total Users:" "$total_users"
    printf "    ${C_CYAN}%-12s${C_RESET} %-25s ${C_CYAN}%-12s${C_RESET} %s\n" "Resources:" "CPU(${cpu_cores}): ${cpu_usage}%% | RAM(${ram_total}): ${ram_usage}%%" "Domain:" "$managed_domain"
    echo -e "${C_DIM}    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${C_RESET}"
    echo -e "    ${C_GREEN}⚡ BBR: Active | MTU: $(ip link | grep mtu | head -1 | grep -oP 'mtu \K\d+') | Loss Protection: Enabled${C_RESET}"
    echo -e "${C_DIM}    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${C_RESET}"
}

protocol_menu() {
    while true; do
        show_banner
        local badvpn_status
        if systemctl is-active --quiet badvpn; then
            badvpn_status="${C_STATUS_A}(Active)${C_RESET}"
        else
            badvpn_status="${C_STATUS_I}(Inactive)${C_RESET}"
        fi
        
        local udp_custom_status
        if systemctl is-active --quiet udp-custom; then
            udp_custom_status="${C_STATUS_A}(Active)${C_RESET}"
        else
            udp_custom_status="${C_STATUS_I}(Inactive)${C_RESET}"
        fi
        
        local zivpn_status
        if systemctl is-active --quiet zivpn.service; then
            zivpn_status="${C_STATUS_A}(Active)${C_RESET}"
        else
            zivpn_status="${C_STATUS_I}(Inactive)${C_RESET}"
        fi
        
        local ssl_tunnel_text="SSL Tunnel (Port 444)"
        local ssl_tunnel_status="${C_STATUS_I}(Inactive)${C_RESET}"
        if systemctl is-active --quiet haproxy; then
            local active_port
            active_port=$(grep -oP 'bind \*:(\d+)' "$HAPROXY_CONFIG" 2>/dev/null | awk -F: '{print $2}')
            if [[ -n "$active_port" ]]; then
                ssl_tunnel_text="SSL Tunnel (Port $active_port)"
            fi
            ssl_tunnel_status="${C_STATUS_A}(Active)${C_RESET}"
        fi
        
        local dnstt_status
        if systemctl is-active --quiet dnstt.service; then
            dnstt_status="${C_STATUS_A}(Active)${C_RESET}"
        else
            dnstt_status="${C_STATUS_I}(Inactive)${C_RESET}"
        fi
        
        local voltronproxy_status="${C_STATUS_I}(Inactive)${C_RESET}"
        local voltronproxy_ports=""
        if systemctl is-active --quiet voltronproxy; then
            if [ -f "$VOLTRONPROXY_CONFIG_FILE" ]; then
                source "$VOLTRONPROXY_CONFIG_FILE"
            fi
            voltronproxy_ports=" ($PORTS)"
            voltronproxy_status="${C_STATUS_A}(Active)${C_RESET}"
        fi

        local nginx_status
        if systemctl is-active --quiet nginx; then
            nginx_status="${C_STATUS_A}(Active)${C_RESET}"
        else
            nginx_status="${C_STATUS_I}(Inactive)${C_RESET}"
        fi
        
        local xui_status
        if command -v x-ui &> /dev/null; then
            xui_status="${C_STATUS_A}(Installed)${C_RESET}"
        else
            xui_status="${C_STATUS_I}(Not Installed)${C_RESET}"
        fi
        
        echo -e "\n   ${C_TITLE}══════════════[ ${C_BOLD}🔌 PROTOCOL & PANEL MANAGEMENT ${C_RESET}${C_TITLE}]══════════════${C_RESET}"
        echo -e "     ${C_ACCENT}--- TUNNELLING PROTOCOLS---${C_RESET}"
        echo -e "     ${C_CHOICE}1)${C_RESET} 🚀 Install badvpn (UDP 7300) $badvpn_status"
        echo -e "     ${C_CHOICE}2)${C_RESET} 🗑️ Uninstall badvpn"
        echo -e "     ${C_CHOICE}3)${C_RESET} 🚀 Install udp-custom (Excl. 53,5300) $udp_custom_status"
        echo -e "     ${C_CHOICE}4)${C_RESET} 🗑️ Uninstall udp-custom"
        echo -e "     ${C_CHOICE}5)${C_RESET} 🔒 Install ${ssl_tunnel_text} ${ssl_tunnel_status}"
        echo -e "     ${C_CHOICE}6)${C_RESET} 🗑️ Uninstall SSL Tunnel"
        echo -e "     ${C_CHOICE}7)${C_RESET} 📡 Install/View DNSTT (Port 53) $dnstt_status"
        echo -e "     ${C_CHOICE}8)${C_RESET} 🗑️ Uninstall DNSTT"
        echo -e "     ${C_CHOICE}9)${C_RESET} 🦅 Install VOLTRON TECH Proxy ${voltronproxy_ports} $voltronproxy_status"
        echo -e "     ${C_CHOICE}10)${C_RESET} 🗑️ Uninstall VOLTRON TECH Proxy"
        echo -e "     ${C_CHOICE}11)${C_RESET} 🌐 Install/Manage Nginx Proxy (80/443) $nginx_status"
        echo -e "     ${C_CHOICE}16)${C_RESET} 🛡️ Install ZiVPN (UDP 5667 + Port Share) $zivpn_status"
        echo -e "     ${C_CHOICE}17)${C_RESET} 🗑️ Uninstall ZiVPN"
        echo -e "     ${C_ACCENT}--- 💻 MANAGEMENT PANELS ---${C_RESET}"
        echo -e "     ${C_CHOICE}12)${C_RESET} 💻 Install X-UI Panel $xui_status"
        echo -e "     ${C_CHOICE}13)${C_RESET} 🗑️ Uninstall X-UI Panel"
        echo -e "   ${C_DIM}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${C_RESET}"
        echo -e "     ${C_WARN}0)${C_RESET} ↩️ Return to Main Menu"
        echo
        local choice
        safe_read "$(echo -e ${C_PROMPT}"👉 Select an option: "${C_RESET})" choice
        case $choice in
            1) install_badvpn; press_enter ;;
            2) uninstall_badvpn; press_enter ;;
            3) install_udp_custom; press_enter ;;
            4) uninstall_udp_custom; press_enter ;;
            5) install_ssl_tunnel; press_enter ;;
            6) uninstall_ssl_tunnel; press_enter ;;
            7) install_dnstt; press_enter ;;
            8) uninstall_dnstt; press_enter ;;
            9) install_voltron_proxy; press_enter ;;
            10) uninstall_voltron_proxy; press_enter ;;
            11) nginx_proxy_menu ;;
            12) install_xui_panel; press_enter ;;
            13) uninstall_xui_panel; press_enter ;;
            16) install_zivpn ;;
            17) uninstall_zivpn ;;
            0) return ;;
            *) echo -e "\n${C_RED}❌ Invalid option.${C_RESET}" && sleep 2 ;;
        esac
    done
}

install_dt_proxy_full() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🚀 Full DT Tunnel Installation ---${C_RESET}"
    if [ -f "/usr/local/bin/main" ]; then
        echo -e "\n${C_YELLOW}ℹ️ DT Proxy appears to be already installed.${C_RESET}"
        return
    fi

    echo -e "\n${C_BLUE}--- Step 1 of 2: Installing DT Tunnel Mod ---${C_RESET}"
    local confirm
    safe_read "👉 Press [Enter] to continue or [Ctrl+C] to cancel." confirm

    if curl -sL https://raw.githubusercontent.com/voltrontech/ProxyMods/main/install.sh | bash; then
        echo -e "\n${C_GREEN}✅ DT Tunnel Mod installed successfully.${C_RESET}"
    else
        echo -e "\n${C_RED}❌ ERROR: DT Tunnel Mod installation failed. Aborting.${C_RESET}"
        return
    fi

    echo -e "\n${C_BLUE}--- Step 2 of 2: Installing DT Tunnel Proxy ---${C_RESET}"
    safe_read "👉 Press [Enter] to continue or [Ctrl+C] to cancel." confirm

    if bash <(curl -fsSL https://raw.githubusercontent.com/voltrontech/ProxyDT-Go-Releases/main/install.sh); then
        echo -e "\n${C_GREEN}✅ DT Tunnel Proxy installed successfully.${C_RESET}"
    else
        echo -e "\n${C_RED}❌ ERROR: DT Tunnel Proxy installation failed.${C_RESET}"
    fi
}

launch_dt_proxy_menu() {
    clear
    show_banner
    if [ -f "/usr/local/bin/main" ]; then
        echo -e "\n${C_GREEN}✅ DT Proxy is installed. Launching its management panel...${C_RESET}"
        sleep 2
        /usr/local/bin/main
    else
        echo -e "\n${C_RED}❌ DT Proxy is not installed. Please use the install option first.${C_RESET}"
    fi
}

uninstall_dt_proxy_full() {
    clear
    show_banner
    echo -e "${C_BOLD}${C_PURPLE}--- 🗑️ Uninstall DT Proxy (Mod + Proxy) ---${C_RESET}"
    if [ ! -f "/usr/local/bin/proxy" ] && [ ! -f "/usr/local/bin/main" ]; then
        echo -e "\n${C_YELLOW}ℹ️ DT Proxy is not installed. Nothing to do.${C_RESET}"
        return
    fi
    local confirm
    safe_read "👉 Are you sure you want to PERMANENTLY delete DT Proxy and all its services? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo -e "\n${C_YELLOW}❌ Uninstallation cancelled.${C_RESET}"
        return
    fi

    echo -e "\n${C_BLUE}🛑 Stopping and disabling all DT Proxy services...${C_RESET}"
    systemctl list-units --type=service --state=running | grep 'proxy-' | awk '{print $1}' | xargs -r systemctl stop
    systemctl list-unit-files --type=service | grep 'proxy-' | awk '{print $1}' | xargs -r systemctl disable

    echo -e "\n${C_BLUE}🗑️ Removing files...${C_RESET}"
    rm -f /etc/systemd/system/proxy-*.service
    systemctl daemon-reload
    rm -f /usr/local/bin/proxy
    rm -f /usr/local/bin/main
    rm -f "$HOME/.proxy_token"
    rm -f /var/log/proxy-*.log
    rm -f /usr/local/bin/install_mod

    echo -e "\n${C_GREEN}✅ DT Proxy has been successfully uninstalled.${C_RESET}"
}

dt_proxy_menu() {
     while true; do
        show_banner
        local dt_proxy_status
        if [ -f "/usr/local/bin/main" ] && [ -f "/usr/local/bin/proxy" ]; then
            dt_proxy_status="${C_STATUS_A}(Installed)${C_RESET}"
        else
            dt_proxy_status="${C_STATUS_I}(Not Installed)${C_RESET}"
        fi

        echo -e "\n   ${C_TITLE}═════════════════[ ${C_BOLD}🚀 DT Proxy Management ${dt_proxy_status} ${C_RESET}${C_TITLE}]═════════════════${C_RESET}"
        echo -e "     ${C_CHOICE}1)${C_RESET} 🚀 Install DT Tunnel (Mod + Proxy)"
        echo -e "     ${C_CHOICE}2)${C_RESET} ▶️ Launch DT Tunnel Management Menu"
        echo -e "     ${C_DANGER}3)${C_RESET} 🗑️ Uninstall DT Tunnel (Mod + Proxy)"
        echo -e "   ${C_DIM}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${C_RESET}"
        echo -e "     ${C_WARN}0)${C_RESET} ↩️ Return to Main Menu"
        echo
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

mtu_optimization_menu() {
    while true; do
        clear
        echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}           📡 VOLTRON TECH MTU OPTIMIZATION${C_RESET}"
        echo -e "${C_BOLD}${C_PURPLE}═══════════════════════════════════════════════════════════════${C_RESET}"
        echo ""
        echo -e "${C_GREEN}Current MTU:${C_RESET} $(ip link | grep mtu | head -1 | grep -oP 'mtu \K\d+')"
        echo -e "${C_GREEN}Current BBR:${C_RESET} $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')"
        echo -e "${C_GREEN}Loss Protection:${C_RESET} $(systemctl is-active voltron-loss-protect 2>/dev/null || echo "inactive")"
        echo ""
        echo -e "${C_YELLOW}Select MTU optimization level:${C_RESET}"
        echo ""
        echo -e "  ${C_GREEN}1)${C_RESET} MTU 512   - Best for high loss networks (>10%)"
        echo -e "  ${C_GREEN}2)${C_RESET} MTU 800   - Optimized for mobile networks"
        echo -e "  ${C_GREEN}3)${C_RESET} MTU 1000  - Balanced performance"
        echo -e "  ${C_GREEN}4)${C_RESET} MTU 1200  - Good for stable connections"
        echo -e "  ${C_GREEN}5)${C_RESET} MTU 1500  - Standard Ethernet"
        echo -e "  ${C_GREEN}6)${C_RESET} MTU 1600  - Jumbo Frame Lite"
        echo -e "  ${C_GREEN}7)${C_RESET} MTU 1700  - Jumbo Frame Medium"
        echo -e "  ${C_GREEN}8)${C_RESET} MTU 1800  - Max DNS Tunnel MTU"
        echo -e "  ${C_GREEN}9)${C_RESET} Auto-detect optimal MTU"
        echo -e "  ${C_GREEN}10)${C_RESET} View Current MTU Settings"
        echo -e "  ${C_GREEN}11)${C_RESET} Restart Loss Protection"
        echo -e "  ${C_RED}0)${C_RESET} Return to Main Menu"
        echo ""
        
        local choice
        safe_read "$(echo -e ${C_PROMPT}"👉 Select option: "${C_RESET})" choice
        
        case $choice in
            1) apply_mtu_optimization 512 ;;
            2) apply_mtu_optimization 800 ;;
            3) apply_mtu_optimization 1000 ;;
            4) apply_mtu_optimization 1200 ;;
            5) apply_mtu_optimization 1500 ;;
            6) apply_mtu_optimization 1600 ;;
            7) apply_mtu_optimization 1700 ;;
            8) apply_mtu_optimization 1800 ;;
            9) auto_detect_mtu ;;
            10) show_mtu_settings ;;
            11) systemctl restart voltron-loss-protect; echo -e "${C_GREEN}✅ Loss Protection restarted${C_RESET}"; sleep 2 ;;
            0) return ;;
            *) echo -e "${C_RED}❌ Invalid option!${C_RESET}" && sleep 2 ;;
        esac
    done
}

apply_mtu_optimization() {
    local mtu=$1
    echo -e "\n${C_BLUE}⚡ Applying MTU $mtu optimization...${C_RESET}"
    
    local iface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$iface" ]; then
        ip link set dev $iface mtu $mtu 2>/dev/null
        echo -e "${C_GREEN}✅ Interface $iface MTU set to $mtu${C_RESET}"
    fi
    
    # Update sysctl for this MTU
    local mss=$((mtu - 40))
    sysctl -w net.ipv4.tcp_base_mss=$mss >/dev/null 2>&1
    
    # Update DNSTT service if exists
    if [ -f "$DNSTT_SERVICE_FILE" ]; then
        sed -i "s/-mtu [0-9]*/-mtu $mtu/" "$DNSTT_SERVICE_FILE"
        systemctl daemon-reload
        systemctl restart dnstt.service
        echo -e "${C_GREEN}✅ DNSTT service updated to MTU $mtu${C_RESET}"
    fi
    
    echo -e "${C_GREEN}✅ MTU optimization complete for $mtu${C_RESET}"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

auto_detect_mtu() {
    echo -e "\n${C_BLUE}🔍 Detecting optimal MTU...${C_RESET}"
    local mtu=$(ping -M do -s 1472 -c 2 8.8.8.8 2>/dev/null | grep -o "mtu = [0-9]*" | awk '{print $3}' || echo "1500")
    echo -e "${C_GREEN}✅ Optimal MTU detected: $mtu${C_RESET}"
    apply_mtu_optimization $mtu
}

show_mtu_settings() {
    echo -e "\n${C_BLUE}📊 Current MTU Settings:${C_RESET}"
    echo -e "  ${C_CYAN}Interface MTU:${C_RESET} $(ip link | grep mtu | head -1 | grep -oP 'mtu \K\d+')"
    echo -e "  ${C_CYAN}TCP Base MSS:${C_RESET} $(sysctl net.ipv4.tcp_base_mss 2>/dev/null | awk '{print $3}')"
    echo -e "  ${C_CYAN}TCP Congestion:${C_RESET} $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')"
    echo -e "  ${C_CYAN}MTU Probing:${C_RESET} $(sysctl net.ipv4.tcp_mtu_probing 2>/dev/null | awk '{print $3}')"
    echo -e "  ${C_CYAN}Loss Protection:${C_RESET} $(systemctl is-active voltron-loss-protect 2>/dev/null || echo "inactive")"
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to continue..."
    safe_read "" dummy
}

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
    
    chattr -i /etc/resolv.conf &>/dev/null

    purge_nginx "silent"
    uninstall_dnstt
    uninstall_badvpn
    uninstall_udp_custom
    uninstall_ssl_tunnel
    uninstall_voltron_proxy
    uninstall_zivpn
    delete_dns_record
    
    echo -e "\n${C_BLUE}🔄 Reloading systemd daemon...${C_RESET}"
    systemctl daemon-reload
    
    echo -e "\n${C_BLUE}🗑️ Removing script and configuration files...${C_RESET}"
    rm -rf "$BADVPN_BUILD_DIR"
    rm -rf "$UDP_CUSTOM_DIR"
    rm -rf "$DB_DIR"
    rm -f "$(command -v menu)"
    rm -f "$(command -v voltron)"
    
    echo -e "\n${C_GREEN}=============================================${C_RESET}"
    echo -e "${C_GREEN}      Script has been successfully uninstalled.     ${C_RESET}"
    echo -e "${C_GREEN}=============================================${C_RESET}"
    exit 0
}

press_enter() {
    echo -e "\nPress ${C_YELLOW}[Enter]${C_RESET} to return to the menu..."
    safe_read "" dummy
}

invalid_option() {
    echo -e "\n${C_RED}❌ Invalid option.${C_RESET}" && sleep 1
}

main_menu() {
    initial_setup
    while true; do
        export UNINSTALL_MODE="interactive"
        show_banner
        
        echo
        echo -e "   ${C_TITLE}═══════════════[ ${C_BOLD}👤 USER MANAGEMENT ${C_RESET}${C_TITLE}]═══════════════${C_RESET}"
        printf "     ${C_CHOICE}%2s${C_RESET}) %-25s ${C_CHOICE}%2s${C_RESET}) %-25s\n" "✨ 1" "Create New User" "🔓 5" "Unlock User Account"
        printf "     ${C_CHOICE}%2s${C_RESET}) %-25s ${C_CHOICE}%2s${C_RESET}) %-25s\n" "🗑 2" "Delete User" "📋 6" "List All Managed Users"
        printf "     ${C_CHOICE}%2s${C_RESET}) %-25s ${C_CHOICE}%2s${C_RESET}) %-25s\n" "✏️ 3" "Edit User Details" "🔄 7" "Renew User Account"
        printf "     ${C_CHOICE}%2s${C_RESET}) %-25s\n" "🔒 4" "Lock User Account"
        
        echo
        echo -e "   ${C_TITLE}═══════════════[ ${C_BOLD}⚙️ SYSTEM UTILITIES ${C_RESET}${C_TITLE}]═══════════════${C_RESET}"
        printf "     ${C_CHOICE}%2s${C_RESET}) %-25s ${C_CHOICE}%2s${C_RESET}) %-25s\n" "🔌 8" "Install Protocols & Panels" "🌐 11" "Manage DNS Domain"
        printf "     ${C_CHOICE}%2s${C_RESET}) %-25s ${C_CHOICE}%2s${C_RESET}) %-25s\n" "💾 9" "Backup User Data" "🎨 12" "SSH Banner Management"
        printf "     ${C_CHOICE}%2s${C_RESET}) %-25s ${C_CHOICE}%2s${C_RESET}) %-25s\n" "📥 10" "Restore User Data" "🧹 13" "Cleanup Expired Users"
        printf "     ${C_CHOICE}%2s${C_RESET}) %-25s ${C_CHOICE}%2s${C_RESET}) %-25s\n" "📡 14" "MTU Optimization" "🚀 15" "DT Proxy Management"

        echo
        echo -e "   ${C_DANGER}═══════════════════[ ${C_BOLD}🔥 DANGER ZONE ${C_RESET}${C_DANGER}]═══════════════════${C_RESET}"
        printf "     ${C_DANGER}%2s${C_RESET}) %-28s ${C_DANGER}%2s${C_RESET}) %-25s\n" "💥 99" "Uninstall Script" "🚪 0" "Exit"

        echo
        local choice
        safe_read "$(echo -e ${C_PROMPT}"👉 Select an option: "${C_RESET})" choice
        case $choice in
            1) create_user; press_enter ;;
            2) delete_user; press_enter ;;
            3) edit_user; press_enter ;;
            4) lock_user; press_enter ;;
            5) unlock_user; press_enter ;;
            6) list_users; press_enter ;;
            7) renew_user; press_enter ;;
            8) protocol_menu ;;
            9) backup_user_data; press_enter ;;
            10) restore_user_data; press_enter ;;
            11) dns_menu; press_enter ;;
            12) ssh_banner_menu ;;
            13) cleanup_expired; press_enter ;;
            14) mtu_optimization_menu ;;
            15) dt_proxy_menu ;;
            99) uninstall_script ;;
            0) echo -e "\n${C_BLUE}👋 Goodbye!${C_RESET}"; exit 0 ;;
            *) invalid_option ;;
        esac
    done
}

if [[ "$1" == "--install-setup" ]]; then
    initial_setup
    exit 0
fi

main_menu
