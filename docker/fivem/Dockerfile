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

WORKDIR /fxserver

COPY docker/fivem/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 30120/tcp
EXPOSE 30120/udp
EXPOSE 40120/tcp

ENTRYPOINT ["/entrypoint.sh"]
