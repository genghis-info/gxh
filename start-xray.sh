#!/usr/bin/env bash
set -euo pipefail

echo -n ${XRAY_CONFIG} | base64 -d > /usr/local/etc/xray/config.json
xray --config /usr/local/etc/xray/config.json
