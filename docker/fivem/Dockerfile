# FXServer runtime image.
# The actual FXServer build (run.sh, FXServer, alpine/, etc.) is NOT baked into
# this image — it's pulled by scripts/update-fivem-server.(sh|bat) into ./fxserver
# and bind-mounted in at runtime. This keeps server updates independent of image
# rebuilds, matching how Cfx.re ships/updates artifacts.

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        jq \
        xz-utils \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# FXServer's Linux build is x86_64-only. On an arm64 build host, compile
# box64 (no prebuilt Debian/arm64 package exists — build-from-source is
# the officially documented install path) so entrypoint.sh can invoke it
# explicitly on the FXServer binary chain, scoped to this container only.
# Deliberately NOT using box64's own `make install` binfmt_misc
# registration — that's a host-kernel-level change affecting every
# container on the machine, not something a single image should do.
RUN if [ "$(uname -m)" = "aarch64" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
            build-essential cmake git \
        && git clone --depth 1 https://github.com/ptitSeb/box64 /tmp/box64 \
        && mkdir /tmp/box64/build && cd /tmp/box64/build \
        && cmake .. -D ARM_DYNAREC=ON -D CMAKE_BUILD_TYPE=RelWithDebInfo \
        && make -j"$(nproc)" \
        && cp box64 /usr/local/bin/box64 \
        && cd / && rm -rf /tmp/box64 \
        && apt-get purge -y build-essential cmake git \
        && apt-get autoremove -y \
        && apt-get install -y --no-install-recommends libatomic1 \
        && rm -rf /var/lib/apt/lists/* ; \
    fi

WORKDIR /fxserver

COPY docker/fivem/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 30120/tcp
EXPOSE 30120/udp
EXPOSE 40120/tcp

ENTRYPOINT ["/entrypoint.sh"]
