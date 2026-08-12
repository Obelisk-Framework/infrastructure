#!/usr/bin/env bash
# Downloads a FXServer linux build into ./fxserver (bind-mounted into the
# fxserver container by docker-compose.yml).
#
# Usage: scripts/update-fivem-server.sh [recommended|latest|optional|critical]

set -euo pipefail

CHANNEL="${1:-recommended}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TARGET_DIR="$ROOT_DIR/fxserver"
API_URL="https://changelogs-live.fivem.net/api/changelog/versions/linux/server"

command -v curl >/dev/null 2>&1 || { echo "error: curl is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "error: jq is required (apt install jq / brew install jq)" >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "error: tar is required" >&2; exit 1; }

echo "Fetching '${CHANNEL}' FXServer build info..."
response="$(curl -fsSL "$API_URL")"

download_url="$(echo "$response" | jq -r --arg ch "$CHANNEL" '.[$ch + "_download"] // empty')"
build="$(echo "$response" | jq -r --arg ch "$CHANNEL" '.[$ch] // empty')"

if [[ -z "$download_url" ]]; then
    echo "error: could not resolve a download URL for channel '${CHANNEL}'" >&2
    echo "known channels: $(echo "$response" | jq -r 'keys | map(select(endswith("_download") | not)) | join(", ")')" >&2
    exit 1
fi

echo "Latest ${CHANNEL} build: ${build}"
echo "Downloading: ${download_url}"

tmpfile="$(mktemp --suffix=.tar.xz)"
trap 'rm -f "$tmpfile"' EXIT
curl -fL "$download_url" -o "$tmpfile"

mkdir -p "$TARGET_DIR"
echo "Extracting to ${TARGET_DIR}..."
tar -xJf "$tmpfile" -C "$TARGET_DIR"

echo "$build" > "$TARGET_DIR/.build-version"
echo "FXServer updated to build ${build} (${CHANNEL})."
