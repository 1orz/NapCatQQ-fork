#!/usr/bin/env bash
set -e
trap "" SIGPIPE

PUID="${NAPCAT_UID:-1000}"
PGID="${NAPCAT_GID:-1000}"

if [ "$(id -u napcat)" != "${PUID}" ]; then
    usermod -o -u "${PUID}" napcat
fi
if [ "$(id -g napcat)" != "${PGID}" ]; then
    groupmod -o -g "${PGID}" napcat
    usermod -g "${PGID}" napcat
fi
chown -R napcat:napcat /app

WEBUI_CONFIG=/app/napcat/config/webui.json
if [ ! -f "${WEBUI_CONFIG}" ] && [ -n "${WEBUI_TOKEN}" ]; then
    cat > "${WEBUI_CONFIG}" <<EOF
{
    "host": "0.0.0.0",
    "prefix": "${WEBUI_PREFIX:-}",
    "port": 6099,
    "token": "${WEBUI_TOKEN}",
    "loginRate": 3
}
EOF
    chown napcat:napcat "${WEBUI_CONFIG}"
fi

if [ -n "${MODE}" ] && [ -f "/app/templates/${MODE}.json" ]; then
    cp "/app/templates/${MODE}.json" /app/napcat/config/onebot11.json
    chown napcat:napcat /app/napcat/config/onebot11.json
fi

rm -f /tmp/.X1-lock

gosu napcat Xvfb :1 -screen 0 1280x720x24 +extension GLX +render >/dev/null 2>&1 &
sleep 1

cd /app/napcat
if [ -n "${ACCOUNT}" ]; then
    exec gosu napcat /opt/QQ/qq --no-sandbox -q "${ACCOUNT}"
else
    exec gosu napcat /opt/QQ/qq --no-sandbox
fi
