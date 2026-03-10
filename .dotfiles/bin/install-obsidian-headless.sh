#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   sudo .dotfiles/bin/install-obsidian-headless.sh \
#     [-u USER] [-d DISPLAY] [-p VNC_PORT] [-s SCREEN] [-o OBS_VER] [-w WM] \
#     [-v VAULT_PATH] [-y ENABLE_SYNC_SERVICE]
#
# Defaults:
#   USER=$SUDO_USER or current
#   DISPLAY=5
#   VNC_PORT=5900
#   SCREEN=1280x800x24
#   OBS_VER=1.12.4
#   WM=openbox
#   VAULT_PATH=$HOME/Code/Obsidian/ObsidianVault
#   ENABLE_SYNC_SERVICE=auto

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Please run as root (sudo)." >&2
  exit 1
fi

USER_NAME="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
DISPLAY_NUM=5
VNC_PORT=5900
SCREEN="1280x800x24"
OBS_VER="1.12.4"
WM="openbox"
WM_UNIT=""
VAULT_PATH=""
ENABLE_SYNC_SERVICE="auto"

while getopts ":u:d:p:s:o:w:v:y:" opt; do
  case $opt in
    u) USER_NAME="$OPTARG" ;;
    d) DISPLAY_NUM="$OPTARG" ;;
    p) VNC_PORT="$OPTARG" ;;
    s) SCREEN="$OPTARG" ;;
    o) OBS_VER="$OPTARG" ;;
    w) WM="$OPTARG" ;;
    v) VAULT_PATH="$OPTARG" ;;
    y) ENABLE_SYNC_SERVICE="$OPTARG" ;;
    *) echo "Invalid option" >&2; exit 2 ;;
  esac
done

if ! id "$USER_NAME" >/dev/null 2>&1; then
  echo "Unknown user: $USER_NAME" >&2
  exit 1
fi

USER_HOME="$(eval echo "~${USER_NAME}")"
USER_UID="$(id -u "$USER_NAME")"
LOCAL_BIN_DIR="$USER_HOME/.local/bin"
LOCAL_SHARE_DIR="$USER_HOME/.local/share"
DESKTOP_DIR="$LOCAL_SHARE_DIR/applications"
APP_DIR="$USER_HOME/Applications"

if [[ -z "$VAULT_PATH" ]]; then
  VAULT_PATH="$USER_HOME/Code/Obsidian/ObsidianVault"
fi

APPIMAGE_PATH="$APP_DIR/Obsidian-${OBS_VER}.AppImage"
APPIMAGE_LINK="$APP_DIR/Obsidian.AppImage"

. /etc/os-release
ID_LOWER="${ID,,}"
ID_LIKE_LOWER="${ID_LIKE:-}"
ID_LIKE_LOWER="${ID_LIKE_LOWER,,}"

is_arch() { [[ "$ID_LOWER" == "arch" || "$ID_LIKE_LOWER" == *"arch"* ]]; }
is_debian_like() { [[ "$ID_LOWER" == "debian" || "$ID_LOWER" == "ubuntu" || "$ID_LIKE_LOWER" == *"debian"* ]]; }

run_as_user() {
  sudo -u "$USER_NAME" \
    env HOME="$USER_HOME" PATH="$LOCAL_BIN_DIR:/usr/local/bin:/usr/bin:/bin" \
    "$@"
}

install_base_packages() {
  if is_arch; then
    pacman -Sy --noconfirm --needed \
      curl jq nodejs npm wget xdg-utils desktop-file-utils \
      xorg-server-xvfb x11vnc xorg-xauth libnotify nss libsecret

    if [[ "$WM" == "openbox" ]]; then
      pacman -Sy --noconfirm --needed openbox obconf tint2
    elif [[ "$WM" == "i3" ]]; then
      pacman -Sy --noconfirm --needed i3-wm i3status dmenu
    else
      echo "Unsupported WM: $WM" >&2
      exit 1
    fi
  elif is_debian_like; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      curl jq nodejs npm wget xdg-utils desktop-file-utils \
      xvfb x11vnc xauth libnotify4 libnss3 libsecret-1-0

    if [[ "$WM" == "openbox" ]]; then
      DEBIAN_FRONTEND=noninteractive apt-get install -y openbox tint2
    elif [[ "$WM" == "i3" ]]; then
      DEBIAN_FRONTEND=noninteractive apt-get install -y i3-wm i3status dmenu
    else
      echo "Unsupported WM: $WM" >&2
      exit 1
    fi
  else
    echo "Unsupported distro: $ID" >&2
    exit 1
  fi
}

fetch_obsidian_url() {
  local api url

  if [[ "$OBS_VER" == "latest" ]]; then
    api="https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"
  else
    api="https://api.github.com/repos/obsidianmd/obsidian-releases/releases/tags/v${OBS_VER}"
  fi

  url="$(
    curl -fsSL "$api" | jq -r '.assets[] | select(.name | test("AppImage"; "i")) | .browser_download_url' | head -n1
  )"

  if [[ -z "$url" || "$url" == "null" ]]; then
    url="$(
      curl -fsSL "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest" \
        | jq -r '.assets[] | select(.name | test("AppImage"; "i")) | .browser_download_url' | head -n1
    )"
  fi

  if [[ -z "$url" || "$url" == "null" ]]; then
    echo "Unable to find an Obsidian AppImage release asset." >&2
    exit 1
  fi

  printf '%s\n' "$url"
}

install_obsidian_appimage() {
  local download_url

  install -d -m 0755 "$APP_DIR"
  chown "$USER_NAME":"$USER_NAME" "$APP_DIR"

  if [[ ! -f "$APPIMAGE_PATH" ]]; then
    download_url="$(fetch_obsidian_url)"
    curl -fL "$download_url" -o "${APPIMAGE_PATH}.tmp"
    mv "${APPIMAGE_PATH}.tmp" "$APPIMAGE_PATH"
  fi

  chmod +x "$APPIMAGE_PATH"
  chown "$USER_NAME":"$USER_NAME" "$APPIMAGE_PATH"
  ln -sfn "$APPIMAGE_PATH" "$APPIMAGE_LINK"
  chown -h "$USER_NAME":"$USER_NAME" "$APPIMAGE_LINK"
}

install_obsidian_wrapper() {
  install -d -m 0755 "$LOCAL_BIN_DIR" "$DESKTOP_DIR"

  cat >"$LOCAL_BIN_DIR/obsidian-wrapper" <<EOF
#!/bin/bash

set -euo pipefail

APPIMAGE="$APPIMAGE_PATH"

if [[ -z "\${DISPLAY:-}" ]]; then
    export DISPLAY=:$DISPLAY_NUM
fi

export XDG_RUNTIME_DIR="\${XDG_RUNTIME_DIR:-/run/user/$USER_UID}"
export DBUS_SESSION_BUS_ADDRESS="\${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$USER_UID/bus}"
export ELECTRON_OZONE_PLATFORM_HINT="\${ELECTRON_OZONE_PLATFORM_HINT:-x11}"
export APPIMAGE_EXTRACT_AND_RUN=1

exec "\${APPIMAGE}" "\$@"
EOF

  chmod +x "$LOCAL_BIN_DIR/obsidian-wrapper"
  chown "$USER_NAME":"$USER_NAME" "$LOCAL_BIN_DIR/obsidian-wrapper"

  ln -sfn "$LOCAL_BIN_DIR/obsidian-wrapper" "$LOCAL_BIN_DIR/obsidian"
  chown -h "$USER_NAME":"$USER_NAME" "$LOCAL_BIN_DIR/obsidian"

  cat >"$DESKTOP_DIR/obsidian.desktop" <<EOF
[Desktop Entry]
Name=Obsidian
Exec=$LOCAL_BIN_DIR/obsidian %U
Terminal=false
Type=Application
MimeType=x-scheme-handler/obsidian;
Categories=Office;
EOF

  chown "$USER_NAME":"$USER_NAME" "$DESKTOP_DIR/obsidian.desktop"

  run_as_user xdg-mime default obsidian.desktop x-scheme-handler/obsidian >/dev/null 2>&1 || true
  run_as_user update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
}

install_ob_cli() {
  install -d -m 0755 "$USER_HOME/.local" "$USER_HOME/.cache/npm"
  chown -R "$USER_NAME":"$USER_NAME" "$USER_HOME/.local" "$USER_HOME/.cache/npm"

  run_as_user env \
    npm_config_prefix="$USER_HOME/.local" \
    npm_config_cache="$USER_HOME/.cache/npm" \
    npm install -g obsidian-headless
}

setup_vnc_password() {
  run_as_user mkdir -p "$USER_HOME/.vnc"

  if [[ ! -f "$USER_HOME/.vnc/passwd" ]]; then
    echo "Setting VNC password for $USER_NAME (you will be prompted)."
    run_as_user x11vnc -storepasswd
  fi

  chmod 600 "$USER_HOME/.vnc/passwd"
  chown -R "$USER_NAME":"$USER_NAME" "$USER_HOME/.vnc"
}

ensure_xauthority() {
  run_as_user touch "$USER_HOME/.Xauthority"
  chown "$USER_NAME":"$USER_NAME" "$USER_HOME/.Xauthority"
}

UNIT_DIR="/etc/systemd/system"
TEMPLATE_DIR="$(cd "$(dirname "$0")/../systemd" && pwd)"

render() {
  local src="$1" dest="$2"
  sed -e "s|__USER__|$USER_NAME|g" \
      -e "s|__GROUP__|$USER_NAME|g" \
      -e "s|__HOME__|$USER_HOME|g" \
      -e "s|__UID__|$USER_UID|g" \
      -e "s|__DISPLAY__|$DISPLAY_NUM|g" \
      -e "s|__SCREEN__|$SCREEN|g" \
      -e "s|__VNC_PORT__|$VNC_PORT|g" \
      -e "s|__WM_UNIT__|$WM_UNIT|g" \
      -e "s|__VAULT__|$VAULT_PATH|g" \
      "$src" >"$dest"
}

install_unit() {
  local name="$1"
  local tmpl="$TEMPLATE_DIR/${name}.service.tmpl"
  local target="$UNIT_DIR/${name}.service"
  install -m 0644 /dev/null "$target"
  render "$tmpl" "$target"
}

should_enable_sync_service() {
  case "$ENABLE_SYNC_SERVICE" in
    auto)
      run_as_user ob sync-status --path "$VAULT_PATH" >/dev/null 2>&1
      ;;
    true|yes|1)
      return 0
      ;;
    false|no|0)
      return 1
      ;;
    *)
      echo "Invalid ENABLE_SYNC_SERVICE value: $ENABLE_SYNC_SERVICE" >&2
      exit 1
      ;;
  esac
}

install_base_packages
install_obsidian_appimage
install_obsidian_wrapper
install_ob_cli
setup_vnc_password
ensure_xauthority

install_unit obsidian-headless-xvfb

WM_EXEC="/usr/bin/openbox-session"
WM_NAME="Openbox"
WM_UNIT="obsidian-headless-openboxsession.service"
if [[ "$WM" == "i3" ]]; then
  WM_EXEC="/usr/bin/i3"
  WM_NAME="i3"
  WM_UNIT="obsidian-headless-wm.service"
fi

if [[ "$WM" == "openbox" ]]; then
  install_unit obsidian-headless-openboxsession
  rm -f "$UNIT_DIR/obsidian-headless-wm.service"
  systemctl disable --now obsidian-headless-wm.service >/dev/null 2>&1 || true
else
  render "$TEMPLATE_DIR/obsidian-headless-wm.service.tmpl" "$UNIT_DIR/obsidian-headless-wm.service"
  sed -i "s|__WM_EXEC__|$WM_EXEC|g; s|__WM_NAME__|$WM_NAME|g" "$UNIT_DIR/obsidian-headless-wm.service"
  rm -f "$UNIT_DIR/obsidian-headless-openboxsession.service"
  systemctl disable --now obsidian-headless-openboxsession.service >/dev/null 2>&1 || true
fi

install_unit obsidian-headless-x11vnc
install_unit obsidian-headless
install_unit obsidian-headless-sync

systemctl daemon-reload

systemctl enable --now obsidian-headless-xvfb.service
systemctl enable --now "$WM_UNIT"
systemctl enable --now obsidian-headless-x11vnc.service
systemctl enable --now obsidian-headless.service

SYNC_SERVICE_STATE="installed but not enabled"
if should_enable_sync_service; then
  systemctl enable --now obsidian-headless-sync.service
  SYNC_SERVICE_STATE="enabled"
else
  systemctl disable --now obsidian-headless-sync.service >/dev/null 2>&1 || true
fi

systemctl --no-pager --full status obsidian-headless.service || true

cat <<EOF
Done.
- AppImage: $APPIMAGE_PATH
- Wrapper: $LOCAL_BIN_DIR/obsidian-wrapper
- Vault: $VAULT_PATH
- VNC: localhost:$VNC_PORT on DISPLAY :$DISPLAY_NUM
- Obsidian CLI helper: $LOCAL_BIN_DIR/ob
- Sync service: $SYNC_SERVICE_STATE

Next steps:
  1. Connect to VNC through SSH/Tailscale and open Obsidian.
  2. In Obsidian, enable Settings -> General -> Command line interface.
  3. Log into Obsidian Sync:
       ob login --email <email>
       ob sync-setup --vault <remote-vault-name-or-id> --path $VAULT_PATH --device-name $(hostname -s)
  4. If sync is not enabled yet:
       sudo systemctl enable --now obsidian-headless-sync.service
  5. Google Drive sync is separate from 'ob':
       configure rclone remote GoogleDriveObsidianSync
       enable the vault-local user services obsidian-sync.service and obsidian-sync-watcher.service
EOF
