#!/usr/bin/env bash
set -euo pipefail

# Usage: sudo .dotfiles/bin/install-obsidian-headless.sh [-u USER] [-d DISPLAY] [-p VNC_PORT] [-s SCREEN] [-o OBS_VER] [-w WM]
# Defaults: USER=$SUDO_USER or current, DISPLAY=5, VNC_PORT=5900, SCREEN=1280x800x16, OBS_VER=1.6.7

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Please run as root (sudo)." >&2
  exit 1
fi

USER_NAME="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
DISPLAY_NUM=5
VNC_PORT=5900
SCREEN="1280x800x24"
OBS_VER="1.6.7"
WM="openbox"

while getopts ":u:d:p:s:o:w:" opt; do
  case $opt in
    u) USER_NAME="$OPTARG" ;;
    d) DISPLAY_NUM="$OPTARG" ;;
    p) VNC_PORT="$OPTARG" ;;
    s) SCREEN="$OPTARG" ;;
    o) OBS_VER="$OPTARG" ;;
    w) WM="$OPTARG" ;;
    *) echo "Invalid option" >&2; exit 2 ;;
  esac
done

USER_HOME=$(eval echo ~"$USER_NAME")

# --- Distro detection ---
. /etc/os-release
ID_LOWER="${ID,,}"
ID_LIKE_LOWER="${ID_LIKE:-}"
ID_LIKE_LOWER="${ID_LIKE_LOWER,,}"

is_arch() { [[ "$ID_LOWER" == "arch" || "$ID_LIKE_LOWER" == *"arch"* ]]; }
is_debian_like() { [[ "$ID_LOWER" == "debian" || "$ID_LOWER" == "ubuntu" || "$ID_LIKE_LOWER" == *"debian"* ]]; }

install_base_packages() {
  if is_arch; then
    pacman -Sy --noconfirm --needed \
      xorg-server-xvfb x11vnc xdg-utils libnotify nss libsecret wget xorg-xauth
    if [[ "$WM" == "openbox" ]]; then
      pacman -Sy --noconfirm --needed openbox obconf tint2
    elif [[ "$WM" == "i3" ]]; then
      pacman -Sy --noconfirm --needed i3-wm i3status dmenu
    else
      echo "Unsupported WM: $WM" >&2; exit 1
    fi
  elif is_debian_like; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      xvfb x11vnc python3-xdg xdg-utils libnotify4 libnss3 libsecret-1-0 wget xauth
    if [[ "$WM" == "openbox" ]]; then
      DEBIAN_FRONTEND=noninteractive apt-get install -y openbox tint2
    elif [[ "$WM" == "i3" ]]; then
      DEBIAN_FRONTEND=noninteractive apt-get install -y i3-wm i3status dmenu
    else
      echo "Unsupported WM: $WM" >&2; exit 1
    fi
  else
    echo "Unsupported distro: $ID" >&2; exit 1
  fi
}

install_obsidian() {
  if command -v obsidian >/dev/null 2>&1; then return 0; fi

  if is_arch; then
    # Try repo package first, then AUR via yay if available; else fallback to AppImage
    if pacman -Si obsidian >/dev/null 2>&1; then
      pacman -Sy --noconfirm --needed obsidian
      return 0
    fi
    if command -v yay >/dev/null 2>&1; then
      yay -S --noconfirm --needed obsidian
      return 0
    fi
    # AppImage fallback
    local appdir="/opt/obsidian"
    install -d "$appdir"
    local url
    url=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/tags/v${OBS_VER} | \
          grep browser_download_url | grep -i AppImage | cut -d '"' -f4 | head -n1)
    if [[ -z "$url" ]]; then
      url=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | \
            grep browser_download_url | grep -i AppImage | cut -d '"' -f4 | head -n1)
    fi
    curl -L "$url" -o "$appdir/Obsidian.AppImage"
    chmod +x "$appdir/Obsidian.AppImage"
    ln -sf "$appdir/Obsidian.AppImage" /usr/local/bin/obsidian
    setcap cap_sys_admin=ep "$appdir/Obsidian.AppImage" || true
    return 0
  fi

  if is_debian_like; then
    local deb_url="https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBS_VER}/obsidian_${OBS_VER}_amd64.deb"
    local tmp_deb="/tmp/obsidian_${OBS_VER}_amd64.deb"
    echo "Installing Obsidian ${OBS_VER} (Debian package)..."
    wget -O "$tmp_deb" "$deb_url"
    dpkg -i "$tmp_deb" || true
    apt-get -f install -y
    return 0
  fi
}

install_base_packages
install_obsidian

# VNC password setup
sudo -u "$USER_NAME" mkdir -p "$USER_HOME/.vnc"
if [[ ! -f "$USER_HOME/.vnc/passwd" ]]; then
  echo "Setting VNC password for $USER_NAME (you will be prompted)";
  sudo -u "$USER_NAME" x11vnc -storepasswd
fi
chmod 600 "$USER_HOME/.vnc/passwd"
chown -R "$USER_NAME":"$USER_NAME" "$USER_HOME/.vnc"

# Ensure XAUTHORITY exists to appease some WMs/apps
sudo -u "$USER_NAME" touch "$USER_HOME/.Xauthority"
chown "$USER_NAME":"$USER_NAME" "$USER_HOME/.Xauthority"

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

# Render generic WM unit
WM_EXEC="/usr/bin/openbox-session"
WM_NAME="Openbox"
if [[ "$WM" == "i3" ]]; then
  WM_EXEC="/usr/bin/i3"
  WM_NAME="i3"
  
  # Note: Using existing i3 config, but startup commands may fail in headless mode
fi
render "$TEMPLATE_DIR/obsidian-headless-wm.service.tmpl" "$UNIT_DIR/obsidian-headless-wm.service"
sed -i "s|__WM_EXEC__|$WM_EXEC|g; s|__WM_NAME__|$WM_NAME|g" "$UNIT_DIR/obsidian-headless-wm.service"

install_unit obsidian-headless-x11vnc
install_unit obsidian-headless

systemctl daemon-reload

systemctl enable --now obsidian-headless-xvfb.service
systemctl enable --now obsidian-headless-wm.service
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
