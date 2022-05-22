#!/usr/bin/env bash
set -euo pipefail

# The files installed by the script conform to the Filesystem Hierarchy Standard:
# https://wiki.linuxfoundation.org/lsb/fhs

# The URL of the script project is:
# https://github.com/XTLS/Xray-install

# The URL of the script is based on:
# https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh

# If the script executes incorrectly, check it by yourself, or go to:
# https://github.com/XTLS/Xray-install/issues

# You can set this variable whatever you want in shell session right before running this script by issuing:
# export DAT_PATH='/usr/local/share/xray'
DAT_PATH=${DAT_PATH:-/usr/local/share/xray}

# You can set this variable whatever you want in shell session right before running this script by issuing:
# export JSON_PATH='/usr/local/etc/xray'
JSON_PATH=${JSON_PATH:-/usr/local/etc/xray}

# Set this variable only if you are starting xray with multiple configuration files:
# export JSONS_PATH='/usr/local/etc/xray'

# Gobal verbals

# Xray current version
CURRENT_VERSION=''

# Xray latest release version
RELEASE_LATEST=''

curl() {
  $(type -P curl) -L -q --retry 5 --retry-delay 10 --retry-max-time 60 "$@"
}


get_current_version() {
  # Get the CURRENT_VERSION
  if [[ -f '/usr/local/bin/xray' ]]; then
    CURRENT_VERSION="$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')"
    CURRENT_VERSION="v${CURRENT_VERSION#v}"
  else
    CURRENT_VERSION=""
  fi
}

get_latest_version() {
  # Get Xray latest release version number
  RELEASE_LATEST="$(curl -sS -H 'Accept: application/vnd.github.v3+json' 'https://api.github.com/repos/XTLS/Xray-core/releases/latest' | jq -r .tag_name)"
  RELEASE_LATEST="v${RELEASE_LATEST#v}"
  echo "Got latest version ${RELEASE_LATEST}"
}

download_xray() {
  DOWNLOAD_LINK="https://github.com/XTLS/Xray-core/releases/download/$INSTALL_VERSION/Xray-linux-64.zip"
  echo "Downloading Xray archive: $DOWNLOAD_LINK"
  if ! curl -R -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK"; then
    echo 'error: Download failed! Please check your network or try again.'
    return 1
  fi
  return 0
}

decompression() {
  if ! unzip -q "$1" -d "$TMP_DIRECTORY"; then
    echo 'error: Xray decompression failed.'
    "rm" -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    exit 1
  fi
  echo "info: Extract the Xray package to $TMP_DIRECTORY and prepare it for installation."
}

install_file() {
  NAME="$1"
  if [[ "$NAME" == 'xray' ]]; then
    install -m 755 "${TMP_DIRECTORY}/$NAME" "/usr/local/bin/$NAME"
  elif [[ "$NAME" == 'geoip.dat' ]] || [[ "$NAME" == 'geosite.dat' ]]; then
    install -m 644 "${TMP_DIRECTORY}/$NAME" "${DAT_PATH}/$NAME"
  fi
}

install_xray() {
  # Install Xray binary to /usr/local/bin/ and $DAT_PATH
  install_file xray
  # Install geoip.dat and geosite.dat
  install -d "$DAT_PATH"
  install_file geoip.dat
  install_file geosite.dat
  # Install Xray configuration file to $JSON_PATH
  if [[ ! -d "$JSON_PATH" ]]; then
    install -d "$JSON_PATH"
    echo "{}" > "${JSON_PATH}/config.json"
  fi
  # Used to store Xray log files
  if [[ ! -d '/var/log/xray/' ]]; then
    install -d -m 700 /var/log/xray/
    install -m 600 /dev/null /var/log/xray/access.log
    install -m 600 /dev/null /var/log/xray/error.log
  fi
}

install_geodata_from_v2fly() {
  # Download geoip.dat and geosite.dat from V2Fly (Unused)
  download_geodata() {
    if ! curl -x "${PROXY}" -R -H 'Cache-Control: no-cache' -o "${dir_tmp}/${2}" "${1}"; then
      echo 'error: Download failed! Please check your network or try again.'
      exit 1
    fi
    if ! curl -x "${PROXY}" -R -H 'Cache-Control: no-cache' -o "${dir_tmp}/${2}.sha256sum" "${1}.sha256sum"; then
      echo 'error: Download failed! Please check your network or try again.'
      exit 1
    fi
  }
  local download_link_geoip="https://github.com/v2fly/geoip/releases/latest/download/geoip.dat"
  local download_link_geosite="https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat"
  local file_ip='geoip.dat'
  local file_dlc='dlc.dat'
  local file_site='geosite.dat'
  local dir_tmp
  dir_tmp="$(mktemp -d)"
  download_geodata $download_link_geoip $file_ip
  download_geodata $download_link_geosite $file_dlc
  cd "${dir_tmp}"
  for i in "${dir_tmp}"/*.sha256sum; do
    if ! sha256sum -c "${i}"; then
      echo 'error: Check failed! Please check your network or try again.'
      exit 1
    fi
  done
  cd - > /dev/null
  install -d "$DAT_PATH"
  install -m 644 "${dir_tmp}"/${file_dlc} "${DAT_PATH}"/${file_site}
  install -m 644 "${dir_tmp}"/${file_ip} "${DAT_PATH}"/${file_ip}
  rm -r "${dir_tmp}"
  exit 0
}

main() {
  # Two very important variables
  TMP_DIRECTORY="$(mktemp -d)"
  ZIP_FILE="${TMP_DIRECTORY}/Xray-linux-64.zip"

  get_latest_version
  INSTALL_VERSION="$RELEASE_LATEST"

  if ! download_xray; then
    "rm" -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    exit 1
  fi
  decompression "$ZIP_FILE"

  install_xray
  echo 'installed: /usr/local/bin/xray'
  echo "installed: ${DAT_PATH}/geoip.dat"
  echo "installed: ${DAT_PATH}/geosite.dat"
  echo "installed: ${JSON_PATH}/config.json"

  "rm" -r "$TMP_DIRECTORY"
  echo "removed: $TMP_DIRECTORY"

  get_current_version
  echo "info: Xray $CURRENT_VERSION is installed."
}

main "$@"
