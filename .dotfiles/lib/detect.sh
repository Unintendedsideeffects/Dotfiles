#!/usr/bin/env bash

# Shared distro and environment detection helpers for dotfile scripts.
# The functions here assume the caller is running under bash.

if [[ -n "${DF_DETECT_SH:-}" ]]; then
  return 0
fi

DF_DETECT_SH=1

_df_os_loaded=0
DF_OS_ID=""
DF_OS_LIKE=""
DF_OS_PRETTY=""
DF_OS_ID_LOWER=""
DF_OS_LIKE_LOWER=""

_df_load_os_release() {
  if [[ $_df_os_loaded -eq 1 ]]; then
    return
  fi

  local os_release="${DF_OS_RELEASE_PATH:-/etc/os-release}"
  if [[ -r "$os_release" ]]; then
    # shellcheck disable=SC1090
    . "$os_release"
    DF_OS_ID=${ID:-}
    DF_OS_LIKE=${ID_LIKE:-}
    DF_OS_PRETTY=${PRETTY_NAME:-}
  else
    DF_OS_ID=""
    DF_OS_LIKE=""
    DF_OS_PRETTY=""
  fi

  DF_OS_ID_LOWER=$(printf '%s' "$DF_OS_ID" | tr '[:upper:]' '[:lower:]')
  DF_OS_LIKE_LOWER=$(printf '%s' "$DF_OS_LIKE" | tr '[:upper:]' '[:lower:]')
  _df_os_loaded=1
}

# Accessors ---------------------------------------------------------------

df_os_id() {
  _df_load_os_release
  printf '%s' "$DF_OS_ID"
}

df_os_like() {
  _df_load_os_release
  printf '%s' "$DF_OS_LIKE"
}

df_os_pretty() {
  _df_load_os_release
  printf '%s' "$DF_OS_PRETTY"
}

# Predicates --------------------------------------------------------------

df_is_arch() {
  _df_load_os_release
  [[ "$DF_OS_ID_LOWER" == "arch" || "$DF_OS_LIKE_LOWER" == *"arch"* ]]
}

df_is_debian_like() {
  _df_load_os_release
  case "$DF_OS_ID_LOWER" in
    debian|ubuntu|linuxmint|raspbian|pop|kali|parrot|devuan|neon|zorin|mx|nitrux|proxmox)
      return 0
      ;;
  esac
  [[ "$DF_OS_LIKE_LOWER" == *"debian"* ]]
}

df_is_rhel_like() {
  _df_load_os_release
  case "$DF_OS_ID_LOWER" in
    rocky|almalinux|centos|rhel|fedora)
      return 0
      ;;
  esac
  [[ "$DF_OS_LIKE_LOWER" == *"rhel"* || "$DF_OS_LIKE_LOWER" == *"fedora"* ]]
}

df_is_proxmox() {
  _df_load_os_release
  [[ -d /etc/pve ]] || [[ "$DF_OS_ID_LOWER" == "proxmox" ]]
}

df_is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || \
  [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]] || \
  [[ -d /mnt/wsl ]] || \
  { [[ -f /proc/version ]] && grep -qi "microsoft" /proc/version 2>/dev/null && grep -qi "wsl" /proc/version 2>/dev/null; } || \
  { [[ -r /proc/sys/kernel/osrelease ]] && grep -qi "microsoft" /proc/sys/kernel/osrelease 2>/dev/null && grep -qi "wsl" /proc/sys/kernel/osrelease 2>/dev/null; }
}

# Derived helpers ---------------------------------------------------------

df_package_family() {
  if df_is_arch; then
    printf 'arch'
    return 0
  fi

  if df_is_debian_like; then
    printf 'debian'
    return 0
  fi

  if df_is_rhel_like; then
    printf 'rocky'
    return 0
  fi

  return 1
}
