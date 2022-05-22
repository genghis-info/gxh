#!/usr/bin/env bash
set -euo pipefail

echo -n ${XRAY_CONFIG} | base64 -d | sed "s/\"port\":\ 443,/\"port\": ${PORT},/g" > /usr/local/etc/xray/config.json
xray --config /usr/local/etc/xray/config.json
