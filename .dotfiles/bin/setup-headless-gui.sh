#!/usr/bin/env bash
set -euo pipefail

# Headless GUI setup for Arch-based systems (Proxmox-friendly LXC/VM)
# Features: X11 forwarding, Xvfb + WM session (openbox/i3), optional VNC and Obsidian
# Uses systemd user units with lingering

# Defaults (can be overridden by flags)
TARGET_USER="${TARGET_USER:-${SUDO_USER:-${USER}}}"
DISPLAY_NUM="${DISPLAY_NUM:-:5}"
VNC_PORT="${VNC_PORT:-5900}"
WM_CHOICE="${WM_CHOICE:-openbox}"
INSTALL_OBSIDIAN="${INSTALL_OBSIDIAN:-true}"
ENABLE_VNC="${ENABLE_VNC:-true}"

usage() {
  cat <<EOF
Headless GUI setup (Arch-based)

Flags:
  --user NAME            Target username (default: current user)
  --display :N           X display number (default: :5)
  --vnc-port PORT        VNC server port (default: 5900)
  --wm openbox|i3        Window manager (default: openbox)
  --obsidian true|false  Install and run Obsidian (default: true)
  --enable-vnc true|false Enable VNC server (default: true)
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) TARGET_USER="$2"; shift 2 ;;
    --display) DISPLAY_NUM="$2"; shift 2 ;;
    --vnc-port) VNC_PORT="$2"; shift 2 ;;
    --wm) WM_CHOICE="$2"; shift 2 ;;
    --obsidian) INSTALL_OBSIDIAN="$2"; shift 2 ;;
    --enable-vnc) ENABLE_VNC="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run as root (sudo)." >&2
    exit 1
  fi
}

assert_arch() {
  if ! grep -qi 'arch' /etc/os-release; then
    echo "This script targets Arch-based systems." >&2
    exit 1
  fi
}

user_home() {
  getent passwd "$TARGET_USER" | cut -d: -f6
}

install_packages() {
  local packages=(
    xorg-xauth xorg-xhost xorg-server-xvfb xorg-xinit xterm
    openssh
    x11vnc
  )
  case "$WM_CHOICE" in
    openbox) packages+=(openbox obconf tint2) ;;
    i3) packages+=(i3-wm i3status dmenu) ;;
    *) echo "Unsupported WM: $WM_CHOICE"; exit 1 ;;
  esac

  pacman -Sy --noconfirm --needed "${packages[@]}"
}

configure_sshd() {
  # Enable X11 forwarding
  local sshd_conf="/etc/ssh/sshd_config"
  install -Dm644 "$sshd_conf" "$sshd_conf.bak.$(date +%s)"
  awk '
    BEGIN{foundX11F=0;foundX11Use=0;foundTCP=0}
    /^X11Forwarding/ {foundX11F=1; print "X11Forwarding yes"; next}
    /^X11UseLocalhost/ {foundX11Use=1; print "X11UseLocalhost yes"; next}
    /^X11DisplayOffset/ {print "X11DisplayOffset 10"; next}
    /^AddressFamily/ {print; next}
    /^#?X11/ {next}
    {print}
    END{
      if(!foundX11F) print "X11Forwarding yes";
      if(!foundX11Use) print "X11UseLocalhost yes";
    }
  ' "$sshd_conf" >"$sshd_conf.tmp"
  mv "$sshd_conf.tmp" "$sshd_conf"
  systemctl enable --now sshd
}

setup_systemd_user_units() {
  local home; home=$(user_home)
  local user_unit_dir="$home/.config/systemd/user"
  install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_USER" "$user_unit_dir"

  # Xvfb unit
  cat >"$user_unit_dir/headless-xvfb.service" <<UNIT
[Unit]
Description=Headless Xvfb display on %i
After=default.target

[Service]
Type=simple
ExecStart=/usr/bin/Xvfb $DISPLAY_NUM -screen 0 1920x1080x24 -nolisten tcp
Restart=on-failure

[Install]
WantedBy=default.target
UNIT

  # Window manager unit
  local wm_exec
  case "$WM_CHOICE" in
    openbox) wm_exec="/usr/bin/openbox-session";;
    i3) wm_exec="/usr/bin/i3";;
  esac
  cat >"$user_unit_dir/headless-wm.service" <<UNIT
[Unit]
Description=Headless Window Manager ($WM_CHOICE)
After=headless-xvfb.service
Requires=headless-xvfb.service

[Service]
Environment=DISPLAY=$DISPLAY_NUM
Type=simple
ExecStart=$wm_exec
Restart=on-failure

[Install]
WantedBy=default.target
UNIT

  # VNC server unit (optional)
  if [[ "$ENABLE_VNC" == "true" ]]; then
    cat >"$user_unit_dir/headless-x11vnc.service" <<UNIT
[Unit]
Description=x11vnc on $DISPLAY_NUM
After=headless-xvfb.service
Requires=headless-xvfb.service

[Service]
Environment=DISPLAY=$DISPLAY_NUM
ExecStart=/usr/bin/x11vnc -display $DISPLAY_NUM -rfbport $VNC_PORT -shared -nopw -forever -xkb
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
UNIT
  fi

  # Obsidian (optional)
  if [[ "$INSTALL_OBSIDIAN" == "true" ]]; then
    local obs_dir="$home/.local/opt/obsidian"
    install -d -o "$TARGET_USER" -g "$TARGET_USER" "$obs_dir"
    # Download latest AppImage if not present
    if [[ ! -f "$obs_dir/Obsidian.AppImage" ]]; then
      # Use GitHub API to find latest release
      local url
      url=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | \
            grep browser_download_url | grep -i AppImage | cut -d '"' -f4 | head -n1)
      curl -L "$url" -o "$obs_dir/Obsidian.AppImage"
      chmod +x "$obs_dir/Obsidian.AppImage"
      chown "$TARGET_USER:$TARGET_USER" "$obs_dir/Obsidian.AppImage"
    fi

    # Provide a convenient wrapper on PATH
    local user_bin_dir="$home/.local/bin"
    install -d -o "$TARGET_USER" -g "$TARGET_USER" "$user_bin_dir"
    cat >"$user_bin_dir/obsidian" <<'WRAP'
#!/usr/bin/env bash
exec "$HOME/.local/opt/obsidian/Obsidian.AppImage" "$@"
WRAP
    chmod +x "$user_bin_dir/obsidian"
    chown "$TARGET_USER:$TARGET_USER" "$user_bin_dir/obsidian"

    cat >"$user_unit_dir/headless-obsidian.service" <<UNIT
[Unit]
Description=Headless Obsidian
After=headless-xvfb.service
Requires=headless-xvfb.service

[Service]
Environment=DISPLAY=$DISPLAY_NUM
Environment=APPDIR=$obs_dir
ExecStart=$obs_dir/Obsidian.AppImage --no-sandbox
Restart=on-failure
WorkingDirectory=$obs_dir

[Install]
WantedBy=default.target
UNIT
  fi

  chown -R "$TARGET_USER:$TARGET_USER" "$home/.config/systemd"
}

enable_lingering() {
  loginctl enable-linger "$TARGET_USER"
}

start_services() {
  # Use systemctl --user via machinectl --uid/user shell is messy in scripts; use su -l
  su -l "$TARGET_USER" -s /bin/bash -c "systemctl --user daemon-reload"
  su -l "$TARGET_USER" -s /bin/bash -c "systemctl --user enable --now headless-xvfb.service"
  su -l "$TARGET_USER" -s /bin/bash -c "systemctl --user enable --now headless-wm.service"
  if [[ "$ENABLE_VNC" == "true" ]]; then
    su -l "$TARGET_USER" -s /bin/bash -c "systemctl --user enable --now headless-x11vnc.service"
  fi
  if [[ "$INSTALL_OBSIDIAN" == "true" ]]; then
    su -l "$TARGET_USER" -s /bin/bash -c "systemctl --user enable --now headless-obsidian.service"
  fi
}

main() {
  require_root
  assert_arch
  install_packages
  configure_sshd
  setup_systemd_user_units
  enable_lingering
  start_services

  cat <<MSG
Done. Access options:
- Per-app X forwarding: ssh -X ${TARGET_USER}@<host> xterm
- VNC: connect to <host>:$VNC_PORT
- Obsidian: ssh -X ${TARGET_USER}@<host> obsidian (or via VNC)
MSG
}

main "$@"
