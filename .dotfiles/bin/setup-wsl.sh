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

# Check if wsl.conf already exists and validate it
if [[ -f /etc/wsl.conf ]]; then
    echo "Checking existing /etc/wsl.conf for issues..."

    # Check for invalid configurations
    if grep -q "wsl2\\." /etc/wsl.conf || grep -q 'kernelCommandLine = "' /etc/wsl.conf; then
        echo "❌ Found invalid WSL configuration format"
        echo "Backing up current configuration to /etc/wsl.conf.backup"
        run_cmd cp /etc/wsl.conf /etc/wsl.conf.backup

        echo "Creating corrected configuration..."
        run_cmd cp "$TEMPLATES_DIR/wsl.conf" /etc/wsl.conf

        # Replace template variables
        run_cmd sed -i "s/\${USER}/$USER/g" /etc/wsl.conf

        echo "✅ WSL configuration has been corrected"
        echo "⚠️  You need to restart WSL for changes to take effect:"
        echo "   wsl --shutdown"
        echo "   wsl"
    else
        echo "✅ Existing WSL configuration appears valid"
    fi
else
    echo "Creating new WSL configuration..."
    run_cmd cp "$TEMPLATES_DIR/wsl.conf" /etc/wsl.conf

    # Replace template variables
    run_cmd sed -i "s/\${USER}/$USER/g" /etc/wsl.conf

    echo "✅ WSL configuration created"
    echo "⚠️  You need to restart WSL for changes to take effect:"
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
    fmask_updated=1
fi

if [[ $fmask_updated -eq 1 ]]; then
    echo "✅ Updated WSL automount options to include fmask=000"
    echo "⚠️  You need to restart WSL for changes to take effect:"
    echo "   wsl --shutdown"
    echo "   wsl"
else
    echo "✅ WSL automount options already include fmask=000"
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

echo "✅ Kernel tuning applied. Values will persist across WSL restarts."
