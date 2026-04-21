# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=24.04
ARG NODE_VERSION=20
ARG QQ_VERSION=3.2.25-45758
ARG QQ_URL_PATH=7516007c

# ---------- Stage 1: build napcat from source ----------
FROM node:${NODE_VERSION}-bookworm-slim AS builder

WORKDIR /src

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates git python3 make g++ \
 && npm i -g pnpm

COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
RUN --mount=type=cache,target=/root/.local/share/pnpm/store,sharing=locked \
    pnpm fetch

COPY . .
RUN --mount=type=cache,target=/root/.local/share/pnpm/store,sharing=locked \
    pnpm install --frozen-lockfile --offline

RUN pnpm --filter napcat-webui-frontend run build \
 && pnpm run build:shell \
 && pnpm --filter napcat-plugin-builtin run build

WORKDIR /src/packages/napcat-shell/dist
RUN npm install --omit=dev && rm -f package-lock.json

# ---------- Stage 2: runtime ----------
FROM ubuntu:${UBUNTU_VERSION} AS runtime

ARG QQ_VERSION
ARG QQ_URL_PATH
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    DISPLAY=:1 \
    FFMPEG_PATH=/usr/bin/ffmpeg \
    NAPCAT_UID=1000 \
    NAPCAT_GID=1000

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gosu tini tzdata \
        xvfb fonts-wqy-zenhei ffmpeg \
        libnotify4 libsecret-1-0 libgbm1 libxss1 libatspi2.0-0 libx11-xcb1 \
        libnss3 libasound2t64 libdbus-1-3 libgtk-3-0 libxtst6 libglib2.0-0; \
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone; \
    arch="${TARGETARCH:-amd64}"; \
    QQ_URL="https://dldir1v6.qq.com/qqfile/qq/QQNT/${QQ_URL_PATH}/linuxqq_${QQ_VERSION}_${arch}.deb"; \
    echo "Downloading QQ: ${QQ_URL}"; \
    for i in 1 2 3 4 5; do \
        curl --retry 3 --retry-delay 5 --connect-timeout 30 --max-time 600 -fL -o /tmp/linuxqq.deb "${QQ_URL}" && break \
        || (echo "attempt $i failed, retrying..." && sleep 10); \
    done; \
    apt-get install -y --no-install-recommends /tmp/linuxqq.deb; \
    rm -f /tmp/linuxqq.deb; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN set -eux; \
    if id -u ubuntu >/dev/null 2>&1; then userdel -r ubuntu 2>/dev/null || true; fi; \
    useradd --no-log-init -u 1000 -m -d /app -s /bin/bash napcat

WORKDIR /app

COPY --from=builder /src/packages/napcat-shell/dist /app/napcat

RUN set -eux; \
    echo "(async () => { await import('file:///app/napcat/napcat.mjs'); })();" > /opt/QQ/resources/app/loadNapCat.js; \
    sed -i 's|"main":[[:space:]]*"[^"]*"|"main": "./loadNapCat.js"|' /opt/QQ/resources/app/package.json; \
    mkdir -p /app/napcat/config /app/.config/QQ; \
    chown -R napcat:napcat /app

COPY docker/templates/ /app/templates/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 6099

VOLUME ["/app/napcat/config", "/app/.config/QQ"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://127.0.0.1:6099/ >/dev/null || exit 1

LABEL org.opencontainers.image.source="https://github.com/1orz/NapCatQQ-fork" \
      org.opencontainers.image.description="NapCatQQ on Ubuntu 24.04 LTS, built from source" \
      org.opencontainers.image.licenses="See LICENSE"

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
