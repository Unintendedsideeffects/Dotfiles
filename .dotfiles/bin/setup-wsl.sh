#!/bin/bash
# WSL Configuration Setup Script

set -euo pipefail

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TEMPLATES_DIR="$(dirname "$SCRIPT_DIR")/templates"

# Check if running in WSL
# Multiple detection methods for better WSL reliability
if ! ([[ -n "${WSL_DISTRO_NAME:-}" ]] || \
      [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]] || \
      [[ -d /mnt/wsl ]] || \
      ([[ -f /proc/version ]] && grep -qi "microsoft" /proc/version && grep -qi "wsl" /proc/version) || \
      ([[ -r /proc/sys/kernel/osrelease ]] && grep -qi "microsoft" /proc/sys/kernel/osrelease 2>/dev/null && grep -qi "wsl" /proc/sys/kernel/osrelease 2>/dev/null)); then
    echo "This script is only for WSL environments"
    exit 1
fi

# Helper function to run commands with sudo when needed
run_cmd() {
    if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        "$@"
    fi
}

install_windows_nerd_fonts() {
    echo
    echo "Checking Windows host for Nerd Font installation..."

    if ! command -v powershell.exe >/dev/null 2>&1; then
        echo "- powershell.exe not found in PATH; skipping Windows font installation"
        return
    fi

    if ! powershell.exe -NoProfile -Command "if (Get-Command winget -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" >/dev/null 2>&1; then
        echo "- winget not available on Windows; install Nerd Fonts manually from https://www.nerdfonts.com"
        return
    fi

    local fonts=("NerdFonts.JetBrainsMono" "NerdFonts.CaskaydiaCove")

    for font in "${fonts[@]}"; do
        echo "- Installing/updating $font via winget..."
        if powershell.exe -NoProfile -Command "winget install --id $font --accept-package-agreements --accept-source-agreements" >/dev/null 2>&1; then
            echo "  OK  $font installed"
        else
            echo "  WARN Failed to install $font automatically. You may need to install it manually via Windows Terminal: winget install --id $font"
        fi
    done

    echo "- Nerd Font installation attempt complete. Configure Windows Terminal to use one of the installed Nerd Fonts."
}

# Check if wsl.conf already exists and validate it
if [[ -f /etc/wsl.conf ]]; then
    echo "Checking existing /etc/wsl.conf for issues..."

    # Check for invalid configurations
    if grep -q "wsl2\\." /etc/wsl.conf || grep -q 'kernelCommandLine = "' /etc/wsl.conf; then
        echo "ERROR: Found invalid WSL configuration format"
        echo "Backing up current configuration to /etc/wsl.conf.backup"
        run_cmd cp /etc/wsl.conf /etc/wsl.conf.backup

        echo "Creating corrected configuration..."
        run_cmd cp "$TEMPLATES_DIR/wsl.conf" /etc/wsl.conf

        # Replace template variables
        run_cmd sed -i "s/\${USER}/$USER/g" /etc/wsl.conf

        echo "OK: WSL configuration has been corrected"
        echo "WARNING: You need to restart WSL for changes to take effect:"
        echo "   wsl --shutdown"
        echo "   wsl"
    else
        echo "OK: Existing WSL configuration appears valid"
    fi
else
    echo "Creating new WSL configuration..."
    run_cmd cp "$TEMPLATES_DIR/wsl.conf" /etc/wsl.conf

    # Replace template variables
    run_cmd sed -i "s/\${USER}/$USER/g" /etc/wsl.conf

    echo "OK: WSL configuration created"
    echo "WARNING: You need to restart WSL for changes to take effect:"
    echo "   wsl --shutdown"
    echo "   wsl"
fi

echo "Current WSL configuration:"
cat /etc/wsl.conf

echo

echo "Ensuring Windows executables retain execute permissions (fmask=000)..."
fmask_updated=0
if grep -Eq '^\s*options\s*=.*fmask=000' /etc/wsl.conf; then
    echo "- fmask is already set to 000"
else
    echo "- Updating fmask to 000 in /etc/wsl.conf"
    if command -v python3 >/dev/null 2>&1; then
        run_cmd python3 - <<'PY'
import pathlib
import re

path = pathlib.Path("/etc/wsl.conf")
text = path.read_text()

pattern = re.compile(r'(^\s*options\s*=\s*")(.*?)("\s*$)', re.MULTILINE)

def rebuild(value: str) -> str:
    parts = [segment.strip() for segment in value.split(',') if segment.strip()]
    parts = [segment for segment in parts if not segment.startswith('fmask=')]
    parts.append('fmask=000')
    return ','.join(parts)

match = pattern.search(text)
if match:
    new_text = pattern.sub(lambda m: f"{m.group(1)}{rebuild(m.group(2))}{m.group(3)}", text, count=1)
else:
    lines = text.splitlines()
    inserted = False
    for index, line in enumerate(lines):
        if line.strip().lower() == '[automount]':
            insert_at = index + 1
            while insert_at < len(lines) and lines[insert_at].strip() == '':
                insert_at += 1
            lines.insert(insert_at, 'options = "fmask=000"')
            inserted = True
            break
    if not inserted:
        lines.extend(['', '[automount]', 'options = "fmask=000"'])
    new_text = '\n'.join(lines).rstrip('\n') + '\n'

if new_text != text:
    path.write_text(new_text)
PY
    else
        tmpfile=$(mktemp)
        if grep -Eq '^\s*options\s*=.*' /etc/wsl.conf; then
            run_cmd awk '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function rebuild(value, out, i, n, parts, item) {
  n = split(value, parts, ",")
  for (i = 1; i <= n; i++) {
    item = trim(parts[i])
    if (item == "" || item ~ /^fmask=/) continue
    out = out (out == "" ? "" : ",") item
  }
  out = out (out == "" ? "fmask=000" : out ",fmask=000")
  return out
}
{
  line = $0
  if (!done && match(line, /^[ \t]*options[ \t]*=[ \t]*"(.*)"/, m)) {
    newval = rebuild(m[1])
    sub(/".*"/, "\"" newval "\"", line)
    done = 1
  }
  print line
}' /etc/wsl.conf > "$tmpfile"
        elif grep -Eq '^\s*\[automount\]\s*$' /etc/wsl.conf; then
            run_cmd awk '
{
  print
  if (!inserted && $0 ~ /^[ \t]*\[automount\][ \t]*$/) {
    print "options = \"fmask=000\""
    inserted = 1
  }
}
END {
  if (!inserted) {
    print ""
    print "[automount]"
    print "options = \"fmask=000\""
  }
}' /etc/wsl.conf > "$tmpfile"
        else
            printf '\n[automount]\noptions = "fmask=000"\n' | run_cmd tee -a /etc/wsl.conf >/dev/null
            tmpfile=""
        fi

        if [[ -n "$tmpfile" ]]; then
            run_cmd mv "$tmpfile" /etc/wsl.conf
        fi
    fi
    fmask_updated=1
fi

if [[ $fmask_updated -eq 1 ]]; then
    echo "OK: Updated WSL automount options to include fmask=000"
    echo "WARNING: You need to restart WSL for changes to take effect:"
    echo "   wsl --shutdown"
    echo "   wsl"
else
    echo "OK: WSL automount options already include fmask=000"
fi

echo

echo "Configuring WSL kernel tuning..."

SYSCTL_CONF="/etc/sysctl.d/99-wsl-network-tuning.conf"
SYSCTL_SETTINGS=$'net.core.rmem_max = 16777216\nnet.core.wmem_max = 16777216\nvm.vfs_cache_pressure = 1000000\n'

if [[ -f "$SYSCTL_CONF" ]]; then
    echo "- Existing $SYSCTL_CONF detected"
else
    echo "- Writing persistent sysctl configuration to $SYSCTL_CONF"
    run_cmd mkdir -p /etc/sysctl.d
    printf '%s\n' "$SYSCTL_SETTINGS" | run_cmd tee "$SYSCTL_CONF" >/dev/null
fi

echo "- Applying sysctl values now"
while IFS='=' read -r key value; do
    key="${key// /}"
    value="${value// /}"
    [[ -z "$key" ]] && continue
    run_cmd sysctl -w "$key=$value"
done <<< "$SYSCTL_SETTINGS"

echo "OK: Kernel tuning applied. Values will persist across WSL restarts."

install_windows_nerd_fonts
