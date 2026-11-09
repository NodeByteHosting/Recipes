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

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
Text="${GREEN}[STARTUP]${NC}"

export TXHOST_GAME_NAME=${TXHOST_GAME_NAME:-"redm"}
export TXHOST_DATA_PATH=${TXHOST_DATA_PATH:-"/home/container/txData"}
export TXHOST_INTERFACE=${TXHOST_INTERFACE:-"0.0.0.0"}
export TXHOST_TXA_PORT=${TXHOST_TXA_PORT:-40120}
export TXHOST_FXS_PORT=${TXHOST_FXS_PORT:-30120}
export TXHOST_DEFAULT_CFXKEY=${TXHOST_DEFAULT_CFXKEY:-"${REDM_LICENSE}"}
export TXHOST_MAX_SLOTS=${TXHOST_MAX_SLOTS:-"${MAX_PLAYERS}"}
export TXHOST_PROVIDER_NAME=${TXHOST_PROVIDER_NAME:-"${PROVIDER_NAME:-NodeByte Hosting}"}
export TXHOST_QUIET_MODE=${TXHOST_QUIET_MODE:-"false"}

if [ -z "$TXHOST_DEFAULT_CFXKEY" ]; then
    echo -e "${Text} ${YELLOW}Warning: No license key provided. Set REDM_LICENSE or TXHOST_DEFAULT_CFXKEY.${NC}"
fi

if [ "${AUTO_UPDATE}" = "1" ]; then
    echo -e "${Text} ${BLUE}Checking for updates...${NC}"
    DOWNLOAD_LINK=$(curl -sSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server | jq -r '.latest_download' 2>/dev/null || true)
    if [ -n "$DOWNLOAD_LINK" ] && [ "$DOWNLOAD_LINK" != "null" ]; then
        curl -sSL "$DOWNLOAD_LINK" -o fx.tar.xz
        rm -rf /home/container/alpine
        tar -xf fx.tar.xz
        rm -f fx.tar.xz run.sh
        echo -e "${Text} ${GREEN}Server files updated.${NC}"
    else
        echo -e "${Text} ${YELLOW}Could not find the latest download. Starting with the existing files.${NC}"
    fi
fi

SERVER_BIN_PATH="$(pwd)/alpine/opt/cfx-server/FXServer"
LD_PATH="$(pwd)/alpine/opt/cfx-server/ld-musl-x86_64.so.1"

if [ ! -f "$SERVER_BIN_PATH" ] || [ ! -f "$LD_PATH" ]; then
    echo -e "${RED}[ERROR] Server files not found. Reinstall the server.${NC}"
    exit 1
fi

STEAM_AUTH_ARGS=""
if [ "${REQUIRE_STEAM_AUTH}" = "1" ]; then
    STEAM_AUTH_ARGS="+set sv_enforceSteamAuth true"
fi

if [ "$TXADMIN_ENABLE" = "1" ]; then
    TXADMIN_ARGS="+start_txadmin"
else
    TXADMIN_ARGS="+exec server.cfg"
fi

exec "$LD_PATH" \
    --library-path "$(pwd)/alpine/usr/lib/v8/:$(pwd)/alpine/lib/:$(pwd)/alpine/usr/lib/:$(pwd)/alpine/opt/cfx-server/lib/" \
    -- "$SERVER_BIN_PATH" \
    +set citizen_dir "$(pwd)/alpine/opt/cfx-server/citizen/" \
    +set gamename rdr3 \
    +set sv_licenseKey ${TXHOST_DEFAULT_CFXKEY} \
    +set sv_maxplayers ${MAX_PLAYERS} \
    $STEAM_AUTH_ARGS \
    $TXADMIN_ARGS
