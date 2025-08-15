#!/usr/bin/env bash
set -euo pipefail

# Usage: sudo .dotfiles/bin/install-obsidian-headless.sh [-u USER] [-d DISPLAY] [-p VNC_PORT] [-s SCREEN] [-o OBS_VER]
# Defaults: USER=$SUDO_USER or current, DISPLAY=5, VNC_PORT=5900, SCREEN=1280x800x16, OBS_VER=1.6.7

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Please run as root (sudo)." >&2
  exit 1
fi

USER_NAME="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
DISPLAY_NUM=5
VNC_PORT=5900
SCREEN="1280x800x16"
OBS_VER="1.6.7"

while getopts ":u:d:p:s:o:" opt; do
  case $opt in
    u) USER_NAME="$OPTARG" ;;
    d) DISPLAY_NUM="$OPTARG" ;;
    p) VNC_PORT="$OPTARG" ;;
    s) SCREEN="$OPTARG" ;;
    o) OBS_VER="$OPTARG" ;;
    *) echo "Invalid option" >&2; exit 2 ;;
  esac
done

USER_HOME=$(eval echo ~"$USER_NAME")

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  openbox xvfb x11vnc python3-xdg xdg-utils libnotify4 libnss3 libsecret-1-0 wget

# Obsidian install (idempotent)
DEB_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBS_VER}/obsidian_${OBS_VER}_amd64.deb"
TMP_DEB="/tmp/obsidian_${OBS_VER}_amd64.deb"
if ! command -v obsidian >/dev/null 2>&1; then
  echo "Installing Obsidian ${OBS_VER}..."
  wget -O "$TMP_DEB" "$DEB_URL"
  dpkg -i "$TMP_DEB" || true
  apt-get -f install -y
fi

# VNC password setup
sudo -u "$USER_NAME" mkdir -p "$USER_HOME/.vnc"
if [[ ! -f "$USER_HOME/.vnc/passwd" ]]; then
  echo "Setting VNC password for $USER_NAME (you will be prompted)";
  sudo -u "$USER_NAME" x11vnc -storepasswd
fi
chmod 600 "$USER_HOME/.vnc/passwd"
chown -R "$USER_NAME":"$USER_NAME" "$USER_HOME/.vnc"

# Render and install systemd unit files from templates
UNIT_DIR="/etc/systemd/system"
TEMPLATE_DIR="$(cd "$(dirname "$0")/../../systemd" && pwd)"

render() {
  local src="$1" dest="$2"
  sed -e "s|__USER__|$USER_NAME|g" \
      -e "s|__GROUP__|$USER_NAME|g" \
      -e "s|__HOME__|$USER_HOME|g" \
      -e "s|__DISPLAY__|$DISPLAY_NUM|g" \
      -e "s|__SCREEN__|$SCREEN|g" \
      -e "s|__VNC_PORT__|$VNC_PORT|g" \
      "$src" > "$dest"
}

install_unit() {
  local name="$1"
  local tmpl="$TEMPLATE_DIR/${name}.service.tmpl"
  local target="$UNIT_DIR/${name}.service"
  install -m 0644 /dev/null "$target"
  render "$tmpl" "$target"
}

install_unit obsidian-headless-xvfb
install_unit obsidian-headless-openboxsession
install_unit obsidian-headless-x11vnc
install_unit obsidian-headless

systemctl daemon-reload

systemctl enable --now obsidian-headless-xvfb.service
systemctl enable --now obsidian-headless-openboxsession.service
systemctl enable --now obsidian-headless-x11vnc.service
systemctl enable --now obsidian-headless.service

# Show status hints
systemctl --no-pager --full status obsidian-headless.service || true

cat <<EOF
Done.
- Connect a VNC viewer to port ${VNC_PORT} on this host.
- DISPLAY is :${DISPLAY_NUM} using screen ${SCREEN}.
- Manage services:
    sudo systemctl status obsidian-headless.service
    sudo systemctl status obsidian-headless-x11vnc.service
EOF
