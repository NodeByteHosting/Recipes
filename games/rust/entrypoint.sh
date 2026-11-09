#!/bin/bash
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

# Make internal Docker IP address available to processes.
export INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}' 2>/dev/null || echo "127.0.0.1")

# Set TZ if provided
TZ=${TZ:-UTC}
export TZ

# Handle steamcmd auto-update
if [ -z "${AUTO_UPDATE}" ] || [ "${AUTO_UPDATE}" = "1" ]; then
  printf "\033[1m\033[33mcontainer@nodebyte~ \033[0mUpdating Rust server via steamcmd...\n"
  bash /home/container/steamcmd/steamcmd.sh +force_install_dir /home/container +login anonymous +app_update 258550 +quit
else
  printf "\033[1m\033[33mcontainer@nodebyte~ \033[0mAuto-update disabled. Starting with existing server files.\n"
fi

# Parse Pterodactyl startup variables
MODIFIED_STARTUP=$(eval echo "$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')")
printf "\033[1m\033[33mcontainer@nodebyte~ \033[0m%s\n" "${MODIFIED_STARTUP}"

# Handle frameworks (Carbon/Oxide)
if [ "${FRAMEWORK}" = "carbon" ]; then
  printf "\033[1m\033[33mcontainer@nodebyte~ \033[0mSetting up Carbon framework...\n"
  curl -sSL "https://github.com/CarbonCommunity/Carbon.Core/releases/download/production_build/Carbon.Linux.Release.tar.gz" | tar zx
  export DOORSTOP_ENABLED=1
  export DOORSTOP_TARGET_ASSEMBLY="$(pwd)/carbon/managed/Carbon.Preloader.dll"
  MODIFIED_STARTUP="LD_PRELOAD=$(pwd)/libdoorstop.so ${MODIFIED_STARTUP}"
elif [ "${OXIDE}" = "1" ] || [ "${FRAMEWORK}" = "oxide" ]; then
  printf "\033[1m\033[33mcontainer@nodebyte~ \033[0mSetting up Oxide framework...\n"
  curl -sSL "https://github.com/OxideMod/Oxide.Rust/releases/latest/download/Oxide.Rust-linux.zip" > umod.zip
  unzip -o -q umod.zip
  rm umod.zip
fi

# Fix for Rust not starting properly with newer libc versions
export LD_LIBRARY_PATH=$(pwd)/RustDedicated_Data/Plugins/x86_64:$(pwd):${LD_LIBRARY_PATH}

# Run the server via Node.js wrapper for output filtering and RCON
node /wrapper.js "${MODIFIED_STARTUP}"