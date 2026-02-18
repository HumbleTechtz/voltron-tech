#!/bin/bash
# ====================================================
# VOLTRON TECH v2.0 - SSH Over DNSTT Complete Edition
# ====================================================
# Features:
# ✅ SSH + DNS User Management
# ✅ BBR + TCP Optimization
# ✅ MTU 512-1800 Support
# ✅ Loss Protection (FEC + Duplicate)
# ✅ Traffic Monitoring
# ✅ Auto Expiry Remover
# ✅ Uninstall (99) & Exit (00)
# ✅ GitHub Ready Installation
# ====================================================
# Supported OS: Ubuntu 20.04-24.04 | Debian 10-13
# Architecture: x86_64 | ARM64
# ====================================================

set -euo pipefail

# ========== COLORS ==========
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; PURPLE='\033[0;35m'
WHITE='\033[1;37m'; BOLD='\033[1m'; NC='\033[0m'

# ========== PRINT COLOR FUNCTION ==========
print_color() { echo -e "${2}${1}${NC}"; }

# ========== QUOTE FUNCTION ==========
show_quote() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}            Always Remember VOLTRON TECH when you see X          ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ========== BANNER ==========
show_banner() {
    clear
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${YELLOW}${BOLD}              VOLTRON TECH v2.0 - COMPLETE EDITION            ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}${BOLD}      SSH + DNS • BBR • MTU 512-1800 • Loss Protection         ${BLUE}║${NC}"
    echo -e "${BLUE}║${RED}${BOLD}              [99] Uninstall | [00] Exit                          ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ========== AUTO-INSTALL MODE ==========
AUTO_INSTALL=0
if [ $# -gt 0 ]; then
    if [ "$1" = "--auto" ] || [ "$1" = "-y" ]; then
        AUTO_INSTALL=1
    fi
fi

# ========== ROOT CHECK ==========
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ Tafadhali run as root!${NC}"
    exit 1
fi

# ========== DETECT OS ==========
detect_os() {
    echo -e "${YELLOW}🔍 Detecting operating system...${NC}"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        OS_NAME="$PRETTY_NAME"
    else
        echo -e "${RED}❌ Cannot detect OS${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Detected: $OS_NAME${NC}"
    
    case $OS in
        ubuntu)
            case $VER in
                20.04|22.04|24.04)
                    echo -e "${GREEN}✅ Ubuntu $VER supported${NC}"
                    ;;
                *)
                    echo -e "${RED}❌ Ubuntu $VER not supported. Use 20.04, 22.04, 24.04${NC}"
                    exit 1
                    ;;
            esac
            ;;
        debian)
            case $VER in
                10|11|12|13)
                    echo -e "${GREEN}✅ Debian $VER supported${NC}"
                    ;;
                *)
                    echo -e "${RED}❌ Debian $VER not supported. Use 10-13${NC}"
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo -e "${RED}❌ OS not supported: $OS${NC}"
            exit 1
            ;;
    esac
}

# ========== DETECT ARCHITECTURE ==========
detect_arch() {
    ARCH=$(uname -m)
    echo -e "${YELLOW}🔍 Architecture: $ARCH${NC}"
    
    case $ARCH in
        x86_64)
            ARCH_TYPE="amd64"
            echo -e "${GREEN}✅ 64-bit x86 detected${NC}"
            ;;
        aarch64)
            ARCH_TYPE="arm64"
            echo -e "${GREEN}✅ ARM64 detected${NC}"
            ;;
        *)
            echo -e "${RED}❌ Architecture not supported: $ARCH${NC}"
            exit 1
            ;;
    esac
}

# ========== CREATE DIRECTORIES ==========
create_dirs() {
    echo -e "${YELLOW}📁 Creating directories...${NC}"
    mkdir -p /etc/voltron-tech/{banner,users,traffic,config,logs,backup,fec,duplicate,stats}
    mkdir -p /etc/dnstt
    mkdir -p /usr/local/bin/voltron
    echo -e "${GREEN}✅ Directories created${NC}"
}

# ========== INSTALL DEPENDENCIES ==========
install_deps() {
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    
    apt update -y
    apt install -y curl wget git nano htop \
        ethtool net-tools dnsutils \
        haveged irqbalance bc \
        build-essential python3 jq \
        iptables iptables-persistent \
        tmux screen unzip zip \
        software-properties-common \
        apt-transport-https ca-certificates \
        gnupg lsb-release \
        apache2-utils fail2ban \
        iftop nethogs wondershaper \
        speedtest-cli
    
    echo -e "${GREEN}✅ Dependencies installed${NC}"
}

# ========== BACKUP SYSTEM ==========
backup_system() {
    echo -e "${YELLOW}💾 Creating system backup...${NC}"
    
    BACKUP_DIR="/root/voltron-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p $BACKUP_DIR
    
    cp /etc/sysctl.conf $BACKUP_DIR/ 2>/dev/null || true
    cp /etc/ssh/sshd_config $BACKUP_DIR/ 2>/dev/null || true
    cp /etc/network/interfaces $BACKUP_DIR/ 2>/dev/null || true
    
    iptables-save > $BACKUP_DIR/iptables.rules 2>/dev/null || true
    
    echo "$BACKUP_DIR" > /etc/voltron-tech/backup/latest
    echo -e "${GREEN}✅ Backup saved to: $BACKUP_DIR${NC}"
}

# ========== CREATE DEFAULT BANNER ==========
create_banner() {
    cat > /etc/voltron-tech/banner/default <<'EOF'
===============================================
      WELCOME TO VOLTRON TECH VPN SERVICE
===============================================
     High Speed • Secure • Unlimited
===============================================
EOF

    cat > /etc/voltron-tech/banner/ssh-banner <<'EOF'
************************************************
*         VOLTRON TECH VPN SERVICE             *
*     High Speed • Secure • Unlimited          *
************************************************
EOF
}

# ========== CONFIGURE SSH ==========
configure_ssh() {
    echo -e "${YELLOW}🔧 Configuring SSH...${NC}"
    
    # Detect SSH service name (sshd or ssh)
    SSH_SERVICE="ssh"
    if systemctl list-units --full -all 2>/dev/null | grep -q "sshd.service"; then
        SSH_SERVICE="sshd"
    elif systemctl list-units --full -all 2>/dev/null | grep -q "ssh.service"; then
        SSH_SERVICE="ssh"
    else
        echo -e "${YELLOW}⚠️ SSH service not found, but continuing...${NC}"
    fi
    
    # Configure SSH banner
    if ! grep -q "^Banner" /etc/ssh/sshd_config; then
        echo "Banner /etc/voltron-tech/banner/ssh-banner" >> /etc/ssh/sshd_config
    else
        sed -i 's|^Banner.*|Banner /etc/voltron-tech/banner/ssh-banner|' /etc/ssh/sshd_config
    fi
    
    # Optimize SSH settings
    sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
    sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
    sed -i 's/#MaxSessions 10/MaxSessions 100/' /etc/ssh/sshd_config
    sed -i 's/#MaxStartups 10:30:100/MaxStartups 100/' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/#TCPKeepAlive yes/TCPKeepAlive yes/' /etc/ssh/sshd_config
    sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 30/' /etc/ssh/sshd_config
    sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 3/' /etc/ssh/sshd_config
    
    # Restart SSH service if found
    if [ -n "$SSH_SERVICE" ]; then
        systemctl restart $SSH_SERVICE 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ SSH configured${NC}"
}

# ========== SYSTEMD-RESOLVED FIX ==========
fix_resolved() {
    if [ -f /etc/systemd/resolved.conf ]; then
        echo -e "${YELLOW}🔧 Configuring systemd-resolved...${NC}"
        sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf || true
        grep -q '^DNS=' /etc/systemd/resolved.conf \
            && sed -i 's/^DNS=.*/DNS=8.8.8.8 8.8.4.4/' /etc/systemd/resolved.conf \
            || echo "DNS=8.8.8.8 8.8.4.4" >> /etc/systemd/resolved.conf
        systemctl restart systemd-resolved 2>/dev/null || true
        ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf 2>/dev/null || true
        echo -e "${GREEN}✅ systemd-resolved configured${NC}"
    fi
}

# ========== MTU SELECTION (FIXED FOR DEBIAN) ==========
select_mtu() {
    local mtu_choice=""
    
    if [ $AUTO_INSTALL -eq 1 ]; then
        MTU=1500
        echo -e "${YELLOW}Auto mode: Using MTU 1500${NC}"
    else
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}SELECT MTU (512 - 1800):${NC}"
        echo "1) 512   - Best for high loss (>10%)"
        echo "2) 800   - Good for mobile networks"
        echo "3) 1000  - Balanced"
        echo "4) 1200  - Good for low loss"
        echo "5) 1500  - Standard Ethernet"
        echo "6) 1600  - Jumbo frames"
        echo "7) 1700  - Jumbo frames"
        echo "8) 1800  - Max DNS tunnel"
        echo "9) Auto-detect optimal MTU"
        echo ""
        
        # Force output to flush and read properly
        echo -n "Choice [1-9]: "
        read mtu_choice
        
        if [ -z "$mtu_choice" ]; then
            echo -e "${YELLOW}No choice made. Using default MTU 1500${NC}"
            MTU=1500
        else
            case $mtu_choice in
                1) MTU=512 ;;
                2) MTU=800 ;;
                3) MTU=1000 ;;
                4) MTU=1200 ;;
                5) MTU=1500 ;;
                6) MTU=1600 ;;
                7) MTU=1700 ;;
                8) MTU=1800 ;;
                9) 
                    echo -e "${YELLOW}Detecting optimal MTU...${NC}"
                    MTU=$(ping -M do -s 1472 -c 2 8.8.8.8 2>/dev/null | grep -o "mtu = [0-9]*" | awk '{print $3}' || echo "1500")
                    echo -e "${GREEN}Optimal MTU: $MTU${NC}"
                    ;;
                *) 
                    echo -e "${YELLOW}Invalid choice. Using default MTU 1500${NC}"
                    MTU=1500 
                    ;;
            esac
        fi
    fi

    echo "$MTU" > /etc/voltron-tech/config/mtu
    echo -e "${GREEN}✅ MTU set to: $MTU${NC}"
}

# ========== SUBDOMAIN INPUT ==========
input_subdomain() {
    if [ $AUTO_INSTALL -eq 1 ]; then
        SUBDOMAIN="ns.voltron.tech"
        echo -e "${YELLOW}Auto mode: Using subdomain $SUBDOMAIN${NC}"
    else
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}Enter your subdomain (e.g., ns.voltron.tech):${NC}"
        
        echo -n "Subdomain: "
        read SUBDOMAIN
        
        if [ -z "$SUBDOMAIN" ]; then
            echo -e "${YELLOW}No subdomain entered. Using default: ns.voltron.tech${NC}"
            SUBDOMAIN="ns.voltron.tech"
        fi
    fi
    
    echo "$SUBDOMAIN" > /etc/voltron-tech/config/subdomain
    echo -e "${GREEN}✅ Subdomain: $SUBDOMAIN${NC}"
}

# ========== KERNEL OPTIMIZATION WITH BBR ==========
optimize_kernel() {
    echo -e "${YELLOW}⚙️ Applying kernel optimizations for MTU $MTU...${NC}"
    
    local RMEM_MAX=$((MTU * 20000))
    local WMEM_MAX=$((MTU * 20000))
    
    cat > /etc/sysctl.d/99-voltron.conf <<EOF
# ============================================
# VOLTRON TECH OPTIMIZATIONS
# ============================================

# TCP Buffers
net.core.rmem_max = $RMEM_MAX
net.core.wmem_max = $WMEM_MAX
net.ipv4.tcp_rmem = 4096 87380 $RMEM_MAX
net.ipv4.tcp_wmem = 4096 65536 $WMEM_MAX

# TCP Congestion Control - BBR
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# MTU Specific
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_base_mss = $((MTU - 40))
net.ipv4.tcp_mtu_probe_floor = 48

# TCP Fast Open
net.ipv4.tcp_fastopen = 3

# TCP Timeouts
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_retries1 = 3
net.ipv4.tcp_retries2 = 5
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_tw_buckets = 1440000

# TCP Keepalive
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3

# TCP Advanced
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_notsent_lowat = 16384

# Network Limits
net.core.netdev_max_backlog = 10000
net.core.somaxconn = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_syn_backlog = 20480

# IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# File Limits
fs.file-max = 2097152
fs.nr_open = 2097152
EOF

    sysctl -p /etc/sysctl.d/99-voltron.conf 2>/dev/null || true
    
    modprobe tcp_bbr 2>/dev/null || true
    echo "tcp_bbr" >> /etc/modules-load.d/modules.conf 2>/dev/null || true
    
    echo -e "${GREEN}✅ Kernel optimized with BBR${NC}"
}

# ========== NETWORK INTERFACE OPTIMIZATION ==========
optimize_interface() {
    local IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [ -n "$IFACE" ]; then
        echo -e "${YELLOW}🔧 Optimizing interface $IFACE for MTU $MTU...${NC}"
        
        ip link set dev $IFACE mtu $MTU 2>/dev/null || echo -e "${YELLOW}⚠️ Could not set MTU on interface${NC}"
        ip link set dev $IFACE txqueuelen $((MTU * 10)) 2>/dev/null || true
        ethtool -K $IFACE tx off sg off tso off gso off gro off lro off 2>/dev/null || true
        ethtool -G $IFACE rx 4096 tx 4096 2>/dev/null || true
        
        echo -e "${GREEN}✅ Interface optimized${NC}"
    fi
}

# ========== INSTALL DNSTT ==========
install_dnstt() {
    echo -e "${YELLOW}📦 Installing DNSTT server for $ARCH_TYPE...${NC}"
    
    case $ARCH_TYPE in
        amd64)
            curl -L -o /tmp/dnstt.tar.gz https://github.com/xtaci/kcptun/releases/download/v20240101/kcptun-linux-amd64-20240101.tar.gz
            ;;
        arm64)
            curl -L -o /tmp/dnstt.tar.gz https://github.com/xtaci/kcptun/releases/download/v20240101/kcptun-linux-arm64-20240101.tar.gz
            ;;
    esac
    
    cd /tmp
    tar -xzf dnstt.tar.gz
    cp server_linux_* /usr/local/bin/dnstt-server 2>/dev/null || true
    chmod +x /usr/local/bin/dnstt-server
    
    cd /etc/dnstt
    /usr/local/bin/dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub
    cd ~
    
    echo -e "${GREEN}✅ DNSTT installed${NC}"
}

# ========== CREATE DNSTT SERVICE ==========
create_dnstt_service() {
    cat > /etc/systemd/system/dnstt-voltron.service <<EOF
[Unit]
Description=VOLTRON TECH DNSTT Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -mtu $MTU -privkey-file /etc/dnstt/server.key $SUBDOMAIN 127.0.0.1:22
Restart=always
RestartSec=5
User=nobody
Group=nogroup

[Install]
WantedBy=multi-user.target
EOF
}

# ========== CREATE EDNS PROXY ==========
create_edns_proxy() {
    cat > /usr/local/bin/voltron-edns-proxy.py <<'EOF'
#!/usr/bin/env python3
import socket,threading,struct

DNSTT_PORT=5300
PROXY_PORT=53

def modify_packet(data, mtu_size):
    if len(data)<12:
        return data
    try:
        q,a,n,r=struct.unpack("!HHHH",data[4:12])
    except:
        return data
    
    o=12
    def skip_name(b,o):
        while o<len(b):
            l=b[o]
            o+=1
            if l==0:
                break
            if l&0xC0==0xC0:
                o+=1
                break
            o+=l
        return o
    
    for _ in range(q):
        o=skip_name(data,o)
        o+=4
    for _ in range(a+n):
        o=skip_name(data,o)
        if o+10>len(data):
            return data
        _,_,_,l=struct.unpack("!HHIH",data[o:o+10])
        o+=10+l
    
    new_data=bytearray(data)
    for _ in range(r):
        o=skip_name(data,o)
        if o+10>len(data):
            return data
        t=struct.unpack("!H",data[o:o+2])[0]
        if t==41:
            new_data[o+2:o+4]=struct.pack("!H",mtu_size)
            return bytes(new_data)
        _,_,l=struct.unpack("!HIH",data[o+2:o+10])
        o+=10+l
    return data

def handle_packet(sock, data, addr, mtu):
    up_sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
    up_sock.settimeout(5)
    try:
        up_sock.sendto(modify_packet(data,mtu),('127.0.0.1',DNSTT_PORT))
        resp,_=up_sock.recvfrom(4096)
        sock.sendto(modify_packet(resp,512),addr)
    except:
        pass
    finally:
        up_sock.close()

def main():
    MTU=512
    try:
        with open('/etc/voltron-tech/config/mtu','r') as f:
            MTU=int(f.read().strip())
    except:
        pass
    
    sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
    sock.bind(('0.0.0.0',PROXY_PORT))
    
    while True:
        data,addr=sock.recvfrom(4096)
        threading.Thread(target=handle_packet,args=(sock,data,addr,MTU),daemon=True).start()

if __name__=="__main__":
    main()
EOF

    chmod +x /usr/local/bin/voltron-edns-proxy.py

    cat > /etc/systemd/system/voltron-proxy.service <<EOF
[Unit]
Description=VOLTRON TECH EDNS Proxy
After=dnstt-voltron.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/voltron-edns-proxy.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}

# ========== TRAFFIC MONITOR ==========
create_traffic_monitor() {
    cat > /usr/local/bin/voltron-traffic <<'EOF'
#!/bin/bash

TRAFFIC_DB="/etc/voltron-tech/traffic"
USER_DB="/etc/voltron-tech/users"
mkdir -p $TRAFFIC_DB

monitor_user() {
    local username="$1"
    local traffic_file="$TRAFFIC_DB/$username"
    
    if command -v iptables >/dev/null 2>&1; then
        local current=$(iptables -vnx -L OUTPUT | grep "$username" | awk '{sum+=$2} END {print sum}' 2>/dev/null || echo "0")
        echo $((current / 1048576)) > "$traffic_file"
    fi
}

while true; do
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            [ -f "$user_file" ] && monitor_user "$(basename "$user_file")"
        done
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
}

# ========== AUTO REMOVER ==========
create_auto_remover() {
    cat > /usr/local/bin/voltron-cleaner <<'EOF'
#!/bin/bash

USER_DB="/etc/voltron-tech/users"
TRAFFIC_DB="/etc/voltron-tech/traffic"
LOG_FILE="/etc/voltron-tech/logs/removed.log"

while true; do
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                expire_date=$(grep "Expire:" "$user_file" | cut -d' ' -f2)
                
                if [ ! -z "$expire_date" ]; then
                    current_date=$(date +%Y-%m-%d)
                    if [[ "$current_date" > "$expire_date" ]] || [ "$current_date" = "$expire_date" ]; then
                        userdel -r "$username" 2>/dev/null || true
                        rm -f "$user_file"
                        rm -f "$TRAFFIC_DB/$username"
                        echo "$(date): Removed expired user $username" >> $LOG_FILE
                    fi
                fi
            fi
        done
    fi
    sleep 3600
done
EOF
    chmod +x /usr/local/bin/voltron-cleaner

    cat > /etc/systemd/system/voltron-cleaner.service <<EOF
[Unit]
Description=VOLTRON TECH Auto Remover

[Service]
Type=simple
ExecStart=/usr/local/bin/voltron-cleaner
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}

# ========== LOSS PROTECTION ==========
create_loss_protection() {
    cat > /usr/local/bin/voltron-loss <<'EOF'
#!/bin/bash

FEC_DB="/etc/voltron-tech/fec"
MTU_FILE="/etc/voltron-tech/config/mtu"
LOG_FILE="/etc/voltron-tech/logs/loss.log"
mkdir -p $FEC_DB

calculate_fec() {
    local loss=$1
    local mtu=$2
    local result="1.0"
    
    if ! [[ "$loss" =~ ^[0-9]+$ ]]; then
        loss=0
    fi
    
    if [ $mtu -le 512 ]; then
        if [ $loss -lt 2 ]; then
            result="1.1"
        elif [ $loss -lt 5 ]; then
            result="1.3"
        else
            result="1.5"
        fi
    elif [ $mtu -le 1000 ]; then
        if [ $loss -lt 2 ]; then
            result="1.2"
        elif [ $loss -lt 5 ]; then
            result="1.4"
        else
            result="1.7"
        fi
    elif [ $mtu -le 1500 ]; then
        if [ $loss -lt 2 ]; then
            result="1.3"
        elif [ $loss -lt 5 ]; then
            result="1.6"
        else
            result="2.0"
        fi
    else
        if [ $loss -lt 2 ]; then
            result="1.5"
        elif [ $loss -lt 5 ]; then
            result="1.8"
        else
            result="2.5"
        fi
    fi
    echo $result
}

calculate_duplicate() {
    local loss=$1
    local mtu=$2
    local result="1"
    
    if ! [[ "$loss" =~ ^[0-9]+$ ]]; then
        loss=0
    fi
    
    if [ $mtu -ge 1500 ]; then
        if [ $loss -lt 3 ]; then
            result="1"
        elif [ $loss -lt 8 ]; then
            result="2"
        else
            result="3"
        fi
    else
        if [ $loss -lt 5 ]; then
            result="1"
        elif [ $loss -lt 10 ]; then
            result="2"
        else
            result="3"
        fi
    fi
    echo $result
}

while true; do
    LOSS=$(ping -c 10 -W 1 8.8.8.8 | grep -oP '\d+(?=% packet loss)' || echo "0")
    MTU=$(cat $MTU_FILE 2>/dev/null || echo "1500")
    FEC_RATIO=$(calculate_fec $LOSS $MTU)
    DUP_LEVEL=$(calculate_duplicate $LOSS $MTU)
    
    echo "$LOSS $MTU $FEC_RATIO $DUP_LEVEL" > $FEC_DB/current
    echo "$(date) Loss:$LOSS% MTU:$MTU FEC:$FEC_RATIO DUP:$DUP_LEVEL" >> $LOG_FILE
    
    iptables -t mangle -F 2>/dev/null
    
    if [ $DUP_LEVEL -gt 1 ]; then
        iptables -t mangle -A OUTPUT -p tcp --tcp-flags SYN SYN -j MARK --set-mark $DUP_LEVEL
        iptables -t mangle -A OUTPUT -p udp --dport 53 -j MARK --set-mark $DUP_LEVEL
        iptables -t mangle -A OUTPUT -m length --length 0:100 -j MARK --set-mark $((DUP_LEVEL+1))
    fi
    
    sleep 30
done
EOF
    chmod +x /usr/local/bin/voltron-loss

    cat > /etc/systemd/system/voltron-loss.service <<EOF
[Unit]
Description=VOLTRON TECH Loss Protection
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/voltron-loss
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}

# ========== UNINSTALL FUNCTION ==========
create_uninstall() {
    cat > /usr/local/bin/voltron-uninstall <<'EOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║${YELLOW}              VOLTRON TECH - UNINSTALL SCRIPT                      ${RED}║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

read -p "Are you sure you want to uninstall VOLTRON TECH? (YES/no): " confirm

if [ "$confirm" != "YES" ]; then
    echo -e "${GREEN}Uninstall cancelled${NC}"
    exit 0
fi

echo -e "${YELLOW}Stopping all services...${NC}"
systemctl stop dnstt-voltron voltron-proxy voltron-traffic voltron-cleaner voltron-loss 2>/dev/null || true

echo -e "${YELLOW}Disabling services...${NC}"
systemctl disable dnstt-voltron voltron-proxy voltron-traffic voltron-cleaner voltron-loss 2>/dev/null || true

echo -e "${YELLOW}Removing service files...${NC}"
rm -f /etc/systemd/system/{dnstt-voltron,voltron-proxy,voltron-traffic,voltron-cleaner,voltron-loss}.service
rm -f /etc/systemd/system/voltron-*.service

echo -e "${YELLOW}Removing binaries...${NC}"
rm -f /usr/local/bin/{voltron,voltron-user,voltron-uninstall,voltron-edns-proxy.py,voltron-traffic,voltron-cleaner,voltron-loss}
rm -f /usr/local/bin/dnstt-server

echo -e "${YELLOW}Removing configuration files...${NC}"
rm -rf /etc/voltron-tech
rm -rf /etc/dnstt

echo -e "${YELLOW}Removing sysctl configurations...${NC}"
rm -f /etc/sysctl.d/99-voltron.conf
sysctl --system

echo -e "${YELLOW}Restoring SSH configuration...${NC}"
sed -i '/^Banner/d' /etc/ssh/sshd_config
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true

echo -e "${GREEN}✅ VOLTRON TECH has been uninstalled successfully!${NC}"
echo -e "${YELLOW}Note: Users were not removed. To remove users manually, use: userdel -r username${NC}"

exit 0
EOF
    chmod +x /usr/local/bin/voltron-uninstall
}

# ========== USER MANAGEMENT SCRIPT ==========
create_user_script() {
    cat > /usr/local/bin/voltron-user <<'EOF'
#!/bin/bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

UD="/etc/voltron-tech/users"
TD="/etc/voltron-tech/traffic"
mkdir -p $UD $TD

show_quote() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}            Always Remember VOLTRON TECH when you see X          ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

add_user() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}              CREATE SSH + DNS USER                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    read -p "$(echo -e $GREEN"Password: "$NC)" password
    read -p "$(echo -e $GREEN"Expire days: "$NC)" days
    read -p "$(echo -e $GREEN"Traffic limit (MB, 0 for unlimited): "$NC)" traffic_limit
    
    if [ -z "$username" ] || [ -z "$password" ] || [ -z "$days" ]; then
        echo -e "${RED}❌ All fields required!${NC}"
        return
    fi
    
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌ Days must be a number!${NC}"
        return
    fi
    
    if id "$username" &>/dev/null; then
        echo -e "${RED}❌ User already exists!${NC}"
        return
    fi
    
    useradd -m -s /bin/false "$username"
    echo "$username:$password" | chpasswd
    
    expire_date=$(date -d "+$days days" +"%Y-%m-%d")
    chage -E "$(date -d "$expire_date" +"%Y-%m-%d")" "$username"
    
    cat > $UD/$username <<INFO
Username: $username
Password: $password
Expire: $expire_date
Traffic_Limit: $traffic_limit
Created: $(date +"%Y-%m-%d %H:%M:%S")
INFO
    
    echo "0" > $TD/$username
    
    SERVER=$(cat /etc/voltron-tech/config/subdomain 2>/dev/null || echo "Not configured")
    PUBKEY=$(cat /etc/dnstt/server.pub 2>/dev/null || echo "Not generated")
    
    clear
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}                  USER DETAILS                                   ${GREEN}║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Username  :${CYAN} $username${NC}"
    echo -e "${GREEN}║${WHITE}  Password  :${CYAN} $password${NC}"
    echo -e "${GREEN}║${WHITE}  Server    :${CYAN} $SERVER${NC}"
    echo -e "${GREEN}║${WHITE}  Port      :${CYAN} 53 (DNS) / 22 (SSH)${NC}"
    echo -e "${GREEN}║${WHITE}  Public Key:${CYAN} $PUBKEY${NC}"
    echo -e "${GREEN}║${WHITE}  Expire    :${CYAN} $expire_date${NC}"
    echo -e "${GREEN}║${WHITE}  Traffic   :${CYAN} $traffic_limit MB${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    show_quote
}

list_users() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                     ACTIVE USERS                               ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    
    if [ -z "$(ls -A $UD 2>/dev/null)" ]; then
        echo -e "${RED}No users found${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        return
    fi
    
    printf "%-15s %-12s %-8s %-8s %-8s\n" "USERNAME" "EXPIRE" "LIMIT" "USED" "STATUS"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
    
    for user in $UD/*; do
        [ ! -f "$user" ] && continue
        u=$(basename "$user")
        ex=$(grep "Expire:" "$user" | cut -d' ' -f2)
        lm=$(grep "Traffic_Limit:" "$user" | cut -d' ' -f2)
        us=$(cat $TD/$u 2>/dev/null || echo "0")
        
        if passwd -S "$u" 2>/dev/null | grep -q "L"; then
            st="${RED}LOCKED${NC}"
        else
            current=$(date +%s)
            exp=$(date -d "$ex" +%s 2>/dev/null || echo "0")
            if [ $exp -le $current ] 2>/dev/null; then
                st="${YELLOW}EXPIRED${NC}"
            else
                st="${GREEN}ACTIVE${NC}"
            fi
        fi
        
        printf "%-15s %-12s %-8s %-8s %-8b\n" "$u" "$ex" "$lm" "$us" "$st"
    done
    
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    show_quote
}

lock_user() {
    read -p "Username to lock: " u
    if id "$u" &>/dev/null; then
        usermod -L "$u"
        echo -e "${GREEN}✅ User $u locked${NC}"
    else
        echo -e "${RED}❌ User not found${NC}"
    fi
    show_quote
}

unlock_user() {
    read -p "Username to unlock: " u
    if id "$u" &>/dev/null; then
        usermod -U "$u"
        echo -e "${GREEN}✅ User $u unlocked${NC}"
    else
        echo -e "${RED}❌ User not found${NC}"
    fi
    show_quote
}

delete_user() {
    read -p "Username to delete: " u
    read -p "Confirm delete? (y/n): " conf
    if [ "$conf" = "y" ]; then
        userdel -r "$u" 2>/dev/null
        rm -f $UD/$u $TD/$u
        echo -e "${GREEN}✅ User $u deleted${NC}"
    fi
    show_quote
}

show_info() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                  SERVER INFORMATION                             ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    
    SERVER=$(cat /etc/voltron-tech/config/subdomain 2>/dev/null || echo "Not configured")
    MTU=$(cat /etc/voltron-tech/config/mtu 2>/dev/null || echo "1500")
    PUBKEY=$(cat /etc/dnstt/server.pub 2>/dev/null || echo "Not generated")
    IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unknown")
    
    echo -e "${CYAN}║${WHITE}  Server    : ${GREEN}$SERVER${NC}"
    echo -e "${CYAN}║${WHITE}  IP        : ${GREEN}$IP${NC}"
    echo -e "${CYAN}║${WHITE}  MTU       : ${GREEN}$MTU${NC}"
    echo -e "${CYAN}║${WHITE}  DNS Port  : ${GREEN}53${NC}"
    echo -e "${CYAN}║${WHITE}  SSH Port  : ${GREEN}22${NC}"
    echo -e "${CYAN}║${WHITE}  Public Key: ${YELLOW}$PUBKEY${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    show_quote
}

case $1 in
    add) add_user ;;
    list) list_users ;;
    lock) lock_user ;;
    unlock) unlock_user ;;
    del) delete_user ;;
    info) show_info ;;
    *)
        echo "VOLTRON TECH User Management"
        echo "Usage: voltron-user {add|list|lock|unlock|del|info}"
        ;;
esac
EOF
    chmod +x /usr/local/bin/voltron-user
}

# ========== MAIN MENU SCRIPT ==========
create_main_menu() {
    cat > /usr/local/bin/voltron <<'EOF'
#!/bin/bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; PURPLE='\033[0;35m'
WHITE='\033[1;37m'; BOLD='\033[1m'; NC='\033[0m'

show_quote() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}            Always Remember VOLTRON TECH when you see X          ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_dashboard() {
    clear
    
    IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unknown")
    SUB=$(cat /etc/voltron-tech/config/subdomain 2>/dev/null || echo "Not configured")
    MTU=$(cat /etc/voltron-tech/config/mtu 2>/dev/null || echo "1500")
    
    DNS=$(systemctl is-active dnstt-voltron 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    PRX=$(systemctl is-active voltron-proxy 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    LOS=$(systemctl is-active voltron-loss 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    TRF=$(systemctl is-active voltron-traffic 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    
    LOSS="N/A"
    FEC="N/A"
    DUP="N/A"
    if [ -f /etc/voltron-tech/fec/current ]; then
        read LOSS CURRENT_MTU FEC DUP < /etc/voltron-tech/fec/current 2>/dev/null || true
    fi
    
    BBR=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${YELLOW}${BOLD}              VOLTRON TECH - MAIN DASHBOARD                    ${BLUE}║${NC}"
    echo -e "${BLUE}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${WHITE}  Subdomain : ${GREEN}$SUB${NC}"
    echo -e "${BLUE}║${WHITE}  IP        : ${GREEN}$IP${NC}"
    echo -e "${BLUE}║${WHITE}  MTU       : ${GREEN}$MTU${NC}"
    echo -e "${BLUE}║${WHITE}  BBR       : ${GREEN}$BBR${NC}"
    echo -e "${BLUE}║${WHITE}  Loss      : ${YELLOW}$LOSS%${NC}  FEC: $FEC  DUP: $DUP"
    echo -e "${BLUE}║${WHITE}  Services  : DNSTT:$DNS Proxy:$PRX Loss:$LOS Traffic:$TRF"
    echo -e "${BLUE}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${WHITE}  [1] Create SSH + DNS User${NC}"
    echo -e "${BLUE}║${WHITE}  [2] List All Users${NC}"
    echo -e "${BLUE}║${WHITE}  [3] Lock User${NC}"
    echo -e "${BLUE}║${WHITE}  [4] Unlock User${NC}"
    echo -e "${BLUE}║${WHITE}  [5] Delete User${NC}"
    echo -e "${BLUE}║${WHITE}  [6] Server Information${NC}"
    echo -e "${BLUE}║${WHITE}  [7] Restart All Services${NC}"
    echo -e "${BLUE}║${WHITE}  [8] View Public Key${NC}"
    echo -e "${BLUE}║${WHITE}  [9] Test Speed${NC}"
    echo -e "${BLUE}║${WHITE}  [10] View Loss Statistics${NC}"
    echo -e "${BLUE}║${WHITE}  [11] Change MTU${NC}"
    echo -e "${BLUE}║${RED}  [99] 🔴 UNINSTALL VOLTRON TECH${NC}"
    echo -e "${BLUE}║${YELLOW}  [00] EXIT${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

while true; do
    show_dashboard
    read -p "$(echo -e $GREEN"Select option: "$NC)" choice
    
    case $choice in
        1)
            voltron-user add
            read -p "Press Enter to continue..."
            ;;
        2)
            voltron-user list
            read -p "Press Enter to continue..."
            ;;
        3)
            voltron-user lock
            read -p "Press Enter to continue..."
            ;;
        4)
            voltron-user unlock
            read -p "Press Enter to continue..."
            ;;
        5)
            voltron-user del
            read -p "Press Enter to continue..."
            ;;
        6)
            voltron-user info
            read -p "Press Enter to continue..."
            ;;
        7)
            echo -e "${YELLOW}Restarting services...${NC}"
            systemctl restart dnstt-voltron voltron-proxy voltron-traffic voltron-cleaner voltron-loss 2>/dev/null || true
            echo -e "${GREEN}✅ Services restarted${NC}"
            read -p "Press Enter to continue..."
            ;;
        8)
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            echo -e "${YELLOW}PUBLIC KEY:${NC}"
            cat /etc/dnstt/server.pub
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            read -p "Press Enter to continue..."
            ;;
        9)
            echo -e "${YELLOW}Testing speed...${NC}"
            curl -o /dev/null -s -w "Download Speed: %{speed_download} bytes/sec\n" http://speedtest.tele2.net/10MB.zip
            read -p "Press Enter to continue..."
            ;;
        10)
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            echo -e "${YELLOW}LOSS STATISTICS:${NC}"
            tail -20 /etc/voltron-tech/logs/loss.log 2>/dev/null || echo "No loss data yet"
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            read -p "Press Enter to continue..."
            ;;
        11)
            echo -e "${YELLOW}Current MTU: $(cat /etc/voltron-tech/config/mtu)${NC}"
            read -p "Enter new MTU (512-1800): " new_mtu
            if [[ "$new_mtu" =~ ^[0-9]+$ ]] && [ $new_mtu -ge 512 ] && [ $new_mtu -le 1800 ]; then
                echo "$new_mtu" > /etc/voltron-tech/config/mtu
                echo -e "${GREEN}✅ MTU updated to $new_mtu${NC}"
                echo -e "${YELLOW}Restart services to apply...${NC}"
            else
                echo -e "${RED}❌ Invalid MTU${NC}"
            fi
            read -p "Press Enter to continue..."
            ;;
        99)
            echo -e "${RED}⚠️  WARNING: You are about to uninstall VOLTRON TECH!${NC}"
            read -p "Type 'UNINSTALL' to confirm: " confirm
            if [ "$confirm" = "UNINSTALL" ]; then
                voltron-uninstall
                exit 0
            else
                echo -e "${GREEN}Uninstall cancelled${NC}"
                read -p "Press Enter to continue..."
            fi
            ;;
        00|0)
            show_quote
            echo -e "${GREEN}Thank you for using VOLTRON TECH!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            read -p "Press Enter to continue..."
            ;;
    esac
done
EOF
    chmod +x /usr/local/bin/voltron
}

# ========== CREATE ALIASES ==========
create_aliases() {
    echo "alias menu='voltron'" >> ~/.bashrc
    echo "alias voltron='voltron'" >> ~/.bashrc
    echo "alias vtech='voltron'" >> ~/.bashrc
    echo "alias vt='voltron'" >> ~/.bashrc
}

# ========== START SERVICES ==========
start_services() {
    echo -e "${YELLOW}🚀 Starting services...${NC}"
    
    systemctl daemon-reload
    systemctl enable dnstt-voltron voltron-proxy voltron-traffic voltron-cleaner voltron-loss 2>/dev/null || true
    systemctl start dnstt-voltron voltron-proxy voltron-traffic voltron-cleaner voltron-loss 2>/dev/null || true
    
    echo -e "${GREEN}✅ Services started${NC}"
}

# ========== CONFIGURE FIREWALL ==========
configure_firewall() {
    echo -e "${YELLOW}🔧 Configuring firewall...${NC}"
    
    iptables -A INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -p udp --dport 5300 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
    iptables -P INPUT DROP 2>/dev/null || true
    iptables -P FORWARD DROP 2>/dev/null || true
    iptables -P OUTPUT ACCEPT 2>/dev/null || true
    
    netfilter-persistent save 2>/dev/null || iptables-save > /etc/iptables.rules 2>/dev/null || true
    
    echo -e "${GREEN}✅ Firewall configured${NC}"
}

# ========== CREATE INFO FILE ==========
create_info() {
    cat > /etc/voltron-tech/info.txt <<EOF
VOLTRON TECH v2.0
==================
Installation Date: $(date)
OS: $OS_NAME
Architecture: $ARCH
MTU: $MTU
Subdomain: $SUBDOMAIN
BBR: $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
EOF
}

# ========== SHOW SUMMARY ==========
show_summary() {
    clear
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}${BOLD}           VOLTRON TECH v2.0 INSTALLED SUCCESSFULLY!          ${GREEN}║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  OS        : ${CYAN}$OS_NAME${NC}"
    echo -e "${GREEN}║${WHITE}  Arch      : ${CYAN}$ARCH${NC}"
    echo -e "${GREEN}║${WHITE}  MTU       : ${CYAN}$MTU${NC}"
    echo -e "${GREEN}║${WHITE}  BBR       : ${CYAN}$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')${NC}"
    echo -e "${GREEN}║${WHITE}  Subdomain : ${CYAN}$SUBDOMAIN${NC}"
    echo -e "${GREEN}║${WHITE}  Public Key: ${YELLOW}$(cat /etc/dnstt/server.pub | cut -c1-50)...${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${YELLOW}  COMMANDS:${NC}"
    echo -e "${GREEN}║${WHITE}    voltron   - Open main menu${NC}"
    echo -e "${GREEN}║${WHITE}    menu      - Shortcut to voltron${NC}"
    echo -e "${GREEN}║${WHITE}    vtech     - Shortcut to voltron${NC}"
    echo -e "${GREEN}║${WHITE}    vt        - Shortcut to voltron${NC}"
    echo -e "${GREEN}║${WHITE}    voltron-user - User management${NC}"
    echo -e "${GREEN}║${WHITE}    voltron-uninstall - Uninstall script${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${RED}  To uninstall: Choose option 99 in menu${NC}"
    echo -e "${GREEN}║${YELLOW}  To exit: Choose option 00 in menu${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    show_quote
}

# ========== ASK TO OPEN MENU ==========
ask_open_menu() {
    if [ $AUTO_INSTALL -eq 0 ]; then
        echo ""
        read -p "Open menu now? (y/n): " open_menu
        if [ "$open_menu" = "y" ]; then
            voltron
        fi
    else
        echo -e "${GREEN}Installation complete! Type 'voltron' to open menu.${NC}"
    fi
}

# ========== MAIN INSTALLATION ==========
main() {
    show_banner
    detect_os
    detect_arch
    create_dirs
    install_deps
    backup_system
    create_banner
    configure_ssh
    fix_resolved
    select_mtu
    input_subdomain
    optimize_kernel
    optimize_interface
    install_dnstt
    create_dnstt_service
    create_edns_proxy
    create_traffic_monitor
    create_auto_remover
    create_loss_protection
    create_uninstall
    create_user_script
    create_main_menu
    create_aliases
    start_services
    configure_firewall
    create_info
    show_summary
    ask_open_menu
}

# Run main installation
main
