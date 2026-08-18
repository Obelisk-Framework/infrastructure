#!/usr/bin/env bash
set -euo pipefail

CONNECTOR_ENTRY="/fxserver/server/resources/oblsk_connector/index.js"
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

# FXServer's Linux build is x86_64-only. On an arm64 host, run.sh's own
# `exec .../ld-musl-x86_64.so.1 ... FXServer ...` chain would otherwise be
# picked up transparently by whatever binfmt_misc handler the host has
# registered for x86_64 ELF binaries (typically qemu-user-static) — which
# has been observed to crash FXServer with a SIGSEGV partway through boot.
# Interpreting the same chain explicitly through box64 (built for arm64 in
# the Dockerfile) instead is a scoped, per-container alternative that
# doesn't touch the host's own binfmt_misc registration.
if [[ "$(uname -m)" == "aarch64" ]] && command -v box64 >/dev/null 2>&1; then
    echo "[obelisk] arm64 host detected, running FXServer under box64..."
    # box64 targets the real binary directly and resolves its shared-library
    # deps itself via BOX64_LD_LIBRARY_PATH — going through run.sh's own
    # ld-musl-x86_64.so.1 loader indirection (meant for the non-emulated
    # case) confuses box64's own library resolution instead.
    export BOX64_LD_LIBRARY_PATH="$(pwd)/alpine/usr/lib/v8:$(pwd)/alpine/lib:$(pwd)/alpine/usr/lib"
    # FXServer embeds the Mono runtime (its C# scripting host), which is
    # exactly the class of workload box64 ships built-in conservative
    # settings for (its own MonoBleedingEdge auto-detection applies these
    # same two flags) — ARM's weaker memory model otherwise breaks Mono's
    # threading/GC assumptions under naive dynarec translation, which is
    # the likely cause of the libuv assertion crash seen without them.
    export BOX64_DYNAREC_STRONGMEM=1
    export BOX64_DYNAREC_BIGBLOCK=0
    exec box64 ./alpine/opt/cfx-server/FXServer +set citizen_dir "$(pwd)/alpine/opt/cfx-server/citizen/" +exec server.cfg
fi

exec ./run.sh +exec server.cfg
