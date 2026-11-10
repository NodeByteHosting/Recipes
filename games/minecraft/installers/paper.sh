#!/bin/bash

set -e

PROJECT="paper"
VERSION="${VERSION:-LATEST}"
USER_AGENT="nodebyte-minecraft/1.0 (support@nodebyte.host)"

echo "Installing Paper..."

if [ "$VERSION" = "LATEST" ]; then
	echo "Resolving latest Minecraft version..."

	ALL_VERSIONS=$(curl -s -H "User-Agent: $USER_AGENT" "https://fill.papermc.io/v3/projects/${PROJECT}" \
		| jq -r '.versions | to_entries[] | .value[]' \
		| grep -vE -- '-(rc|pre)' \
		| sort -V -r)
	VERSION=""
	for CANDIDATE in $ALL_VERSIONS; do
		if curl -s -H "User-Agent: $USER_AGENT" "https://fill.papermc.io/v3/projects/${PROJECT}/versions/${CANDIDATE}/builds" \
			| jq -e 'any(.[]; .channel == "STABLE")' > /dev/null 2>&1; then
			VERSION="$CANDIDATE"
			break
		fi
	done
	if [ -z "$VERSION" ]; then
		echo "Error: No stable Paper version found."
		exit 1
	fi
fi

echo "Target MC version: $VERSION"

BUILDS_RESPONSE=$(curl -s -H "User-Agent: $USER_AGENT" "https://fill.papermc.io/v3/projects/${PROJECT}/versions/${VERSION}/builds")

if echo "$BUILDS_RESPONSE" | jq -e '.ok == false' > /dev/null 2>&1; then
	ERROR_MSG=$(echo "$BUILDS_RESPONSE" | jq -r '.message // "Unknown error"')
	echo "API Error: $ERROR_MSG"
	exit 1
fi

DOWNLOAD_URL=$(echo "$BUILDS_RESPONSE" | jq -r 'first(.[] | select(.channel == "STABLE") | .downloads."server:default".url) // "null"')
FILE_NAME=$(echo "$BUILDS_RESPONSE" | jq -r 'first(.[] | select(.channel == "STABLE") | .downloads."server:default".name) // "server.jar"')

if [ "$DOWNLOAD_URL" = "null" ]; then
	echo "Error: No stable build found for version $VERSION."
	exit 1
fi

echo "Downloading build: $FILE_NAME"
curl -L -H "User-Agent: $USER_AGENT" -o server.jar "$DOWNLOAD_URL"

echo "Paper installed successfully."
