#!/bin/ash
#
# Copyright (c) 2026 NodeByte LTD
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

set -e

cd /home/container || exit 1

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

Text="${GREEN}[STARTUP]${NC}"

# Set environment defaults
export TXHOST_GAME_NAME=${TXHOST_GAME_NAME:-"fivem"}
export TXHOST_DATA_PATH=${TXHOST_DATA_PATH:-"/home/container/txData"}
export TXHOST_INTERFACE=${TXHOST_INTERFACE:-"0.0.0.0"}
export TXHOST_TXA_PORT=${TXHOST_TXA_PORT:-40120}
export TXHOST_FXS_PORT=${TXHOST_FXS_PORT:-30120}
export TXHOST_DEFAULT_CFXKEY=${TXHOST_DEFAULT_CFXKEY:-"${FIVEM_LICENSE}"}
export TXHOST_MAX_SLOTS=${TXHOST_MAX_SLOTS:-"${MAX_PLAYERS}"}
export TXHOST_PROVIDER_NAME=${TXHOST_PROVIDER_NAME:-"${PROVIDER_NAME:-NodeByte Hosting}"}
export TXHOST_PROVIDER_LOGO=${TXHOST_PROVIDER_LOGO:-"${PROVIDER_LOGO}"}
export TXHOST_QUIET_MODE=${TXHOST_QUIET_MODE:-"false"}

# Export internal IP for FiveM
export INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}' 2>/dev/null || echo "127.0.0.1")

echo -e "${Text} ${BLUE}Validating configuration...${NC}"

# Validate license key
if [ -z "$TXHOST_DEFAULT_CFXKEY" ]; then
    echo -e "${Text} ${YELLOW}Warning: No FiveM license key provided. Set FIVEM_LICENSE or TXHOST_DEFAULT_CFXKEY${NC}"
fi

# Validate port conflicts
if [ "$TXHOST_TXA_PORT" = "30120" ] 2>/dev/null; then
    echo -e "${RED}[ERROR] TXHOST_TXA_PORT cannot be 30120${NC}"
    exit 1
fi

if [ "$TXHOST_FXS_PORT" = "40120" ] 2>/dev/null; then
    echo -e "${RED}[ERROR] TXHOST_FXS_PORT cannot be 40120${NC}"
    exit 1
fi

echo -e "${Text} ${GREEN}Configuration validated${NC}"
echo -e "${Text} Game: ${TXHOST_GAME_NAME}"
echo -e "${Text} txAdmin Port: ${TXHOST_TXA_PORT}"
echo -e "${Text} Server Port: ${TXHOST_FXS_PORT}"
echo -e "${Text} Max Slots: ${TXHOST_MAX_SLOTS:-unlimited}"

# Auto-update check and download
if [ "${AUTO_UPDATE}" = "1" ] && [ ! -f "$(pwd)/alpine/opt/cfx-server/cfx-server" ]; then
    echo -e "${Text} ${BLUE}Checking for updates...${NC}"
    
    CFX_CHANGELOGS=$(curl -sSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$CFX_CHANGELOGS" ]; then
        DOWNLOAD_LINK=$(echo "$CFX_CHANGELOGS" | grep -o '"latest_download":"[^"]*"' | cut -d'"' -f4 2>/dev/null)
        
        if [ -n "$DOWNLOAD_LINK" ] && [ "$DOWNLOAD_LINK" != "null" ]; then
            rm -rf /home/container/alpine > /dev/null 2>&1

            echo -e "${Text} ${BLUE}Downloading latest CitizenFX Resources...${NC}"

            curl -sSL "${DOWNLOAD_LINK}" -o "${DOWNLOAD_LINK##*/}" > /dev/null 2>&1
            tar -xf "${DOWNLOAD_LINK##*/}" > /dev/null 2>&1
            rm -rf "${DOWNLOAD_LINK##*/}" run.sh > /dev/null 2>&1

            echo -e "${Text} ${GREEN}CitizenFX Resources updated successfully!${NC}"
        else
            echo -e "${Text} ${YELLOW}Could not determine latest download link${NC}"
        fi
    else
        echo -e "${Text} ${YELLOW}Update check failed (network or API issue)${NC}"
    fi
else 
    echo -e "${Text} ${BLUE}Auto Update is disabled (set AUTO_UPDATE=1 to enable)${NC}"
fi

echo -e "${Text} ${BLUE}Starting FiveM Server...${NC}"

GAME_BUILD_ARGS=""
STEAM_AUTH_ARGS=""
if [ "${REQUIRE_STEAM_AUTH}" = "1" ]; then
    STEAM_AUTH_ARGS="+set sv_enforceSteamAuth true"
fi
if [ -f "$(pwd)/alpine/opt/cfx-server/cfx-server" ]; then
    SERVER_BIN_PATH="$(pwd)/alpine/opt/cfx-server/cfx-server"
    LD_PATH="$(pwd)/alpine/lib/ld-musl-x86_64.so.1"
    LIBRARY_PATH="$(pwd)/alpine/lib/:$(pwd)/alpine/usr/lib/"
else
    SERVER_BIN_PATH="$(pwd)/alpine/opt/cfx-server/FXServer"
    LD_PATH="$(pwd)/alpine/opt/cfx-server/ld-musl-x86_64.so.1"
    LIBRARY_PATH="$(pwd)/alpine/usr/lib/v8/:$(pwd)/alpine/lib/:$(pwd)/alpine/usr/lib/:$(pwd)/alpine/opt/cfx-server/lib/"
    if [ -n "${SV_GAMEBUILD}" ]; then
        GAME_BUILD_ARGS="+set sv_enforceGameBuild ${SV_GAMEBUILD}"
    fi
fi

# Validate binary paths
if [ ! -f "$SERVER_BIN_PATH" ]; then
    echo -e "${RED}[ERROR] FiveM server binary not found at ${SERVER_BIN_PATH}${NC}"
    exit 1
fi

if [ ! -f "$LD_PATH" ]; then
    echo -e "${RED}[ERROR] Loader not found at ${LD_PATH}${NC}"
    exit 1
fi

# Set txAdmin args based on TXADMIN_ENABLE
if [ "$TXADMIN_ENABLE" = "1" ]; then
    TXADMIN_ARGS="+start_txadmin"
else
    TXADMIN_ARGS="+exec server.cfg"
fi

# Execute FiveM server
exec "$LD_PATH" \
    --library-path "$LIBRARY_PATH" \
    -- "$SERVER_BIN_PATH" \
    +set citizen_dir "$(pwd)/alpine/opt/cfx-server/citizen/" \
    +set sv_licenseKey ${FIVEM_LICENSE} \
    +set sv_maxplayers ${MAX_PLAYERS} \
    $GAME_BUILD_ARGS \
    $STEAM_AUTH_ARGS \
    $TXADMIN_ARGS