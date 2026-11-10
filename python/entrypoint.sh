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

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}' 2>/dev/null || echo "127.0.0.1")
export INTERNAL_IP

# Validate working directory
if [ ! -d "/home/container" ]; then
  printf "\033[1m\033[31mERROR\033[0m: /home/container does not exist\n" >&2
  exit 1
fi

if [ ! -w "/home/container" ]; then
  printf "\033[1m\033[31mERROR\033[0m: /home/container is not writable\n" >&2
  exit 1
fi

cd /home/container || exit 1

# Validate Python is available
if ! command -v python >/dev/null 2>&1; then
  printf "\033[1m\033[31mERROR\033[0m: Python is not installed\n" >&2
  exit 1
fi

# Validate STARTUP variable is set
if [ -z "$STARTUP" ]; then
  printf "\033[1m\033[31mERROR\033[0m: STARTUP variable is not set\n" >&2
  exit 1
fi

# Print Python version
printf "\033[1m\033[33mcontainer@nodebyte~ \033[0mpython --version\n"
python --version

# Parse startup command
PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")

# Validate parsed command
if [ -z "$PARSED" ]; then
  printf "\033[1m\033[31mERROR\033[0m: Failed to parse STARTUP command\n" >&2
  exit 1
fi

# Execute command
printf "\033[1m\033[33mcontainer@nodebyte~ \033[0m%s\n" "$PARSED"
# shellcheck disable=SC2086
exec env ${PARSED}