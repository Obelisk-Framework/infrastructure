#!/usr/bin/env bash
set -euo pipefail

CONNECTOR_ENTRY="/fxserver/server/resources/local/oblsk_connector/index.js"
FXSERVER_CHANNEL="${FXSERVER_CHANNEL:-recommended}"

if [[ ! -x "/fxserver/server/run.sh" ]]; then
    echo "[obelisk] /fxserver/server/run.sh not found, downloading '${FXSERVER_CHANNEL}' FXServer build..."

    api_url="https://changelogs-live.fivem.net/api/changelog/versions/linux/server"
    response="$(curl -fsSL "$api_url")"
    download_url="$(echo "$response" | jq -r --arg ch "$FXSERVER_CHANNEL" '.[$ch + "_download"] // empty')"
    build="$(echo "$response" | jq -r --arg ch "$FXSERVER_CHANNEL" '.[$ch] // empty')"

    if [[ -z "$download_url" ]]; then
        echo "[obelisk] error: could not resolve a download URL for channel '${FXSERVER_CHANNEL}'" >&2
        exit 1
    fi

    echo "[obelisk] Downloading build ${build}: ${download_url}"
    tmpfile="$(mktemp --suffix=.tar.xz)"
    curl -fL "$download_url" -o "$tmpfile"
    mkdir -p /fxserver/server
    tar -xJf "$tmpfile" -C /fxserver/server
    rm -f "$tmpfile"
    echo "$build" > /fxserver/server/.build-version
    echo "[obelisk] FXServer bootstrapped to build ${build} (${FXSERVER_CHANNEL})."
fi

CONNECTOR_PID=""
if [[ -f "$CONNECTOR_ENTRY" ]]; then
    echo "[obelisk] Starting oblsk_connector on 127.0.0.1:${MYSQL_SERVER_PORT:-3000}..."
    node "$CONNECTOR_ENTRY" &
    CONNECTOR_PID=$!
else
    echo "[obelisk] oblsk_connector not mounted, skipping (DB queries will fail)." >&2
fi

cleanup() {
    if [[ -n "$CONNECTOR_PID" ]]; then
        kill "$CONNECTOR_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

cd /fxserver/server
exec ./run.sh +exec server.cfg
