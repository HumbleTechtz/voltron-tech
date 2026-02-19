#!/bin/bash

RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
BLUE='\033[94m'
CYAN='\033[96m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Error: This script must be run as root.${NC}"
   exit 1
fi

echo -e "${BLUE}📦 Installing VOLTRON TECH ULTIMATE Manager...${NC}"

MENU_URL="https://raw.githubusercontent.com/HumbleTechtz/voltron-tech/refs/heads/main/main.sh"

echo -e "${YELLOW}⬇️ Downloading main script...${NC}"
wget -q --show-progress -O /usr/local/bin/menu "$MENU_URL"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Download failed! Check your internet connection.${NC}"
    exit 1
fi

chmod +x /usr/local/bin/menu

echo -e "${YELLOW}⚙️ Running initial setup (this will install ULTIMATE BOOSTER)...${NC}"
/usr/local/bin/menu --install-setup

echo -e "${GREEN}✅ Installation complete!${NC}"
echo -e "${CYAN}➡️ Type 'menu' to start VOLTRON TECH ULTIMATE${NC}"
