#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "== Validate script =="
"$ROOT_DIR/.dotfiles/bin/validate.sh" || true

echo "== Bootstrap dry-run =="
"$ROOT_DIR/.dotfiles/bin/bootstrap.sh" --dry-run || true

echo "== Bootstrap shell fallback =="
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
cat > "$tmpdir/dialog" <<'EOF'
#!/usr/bin/env bash
echo "dialog should not be used in shell fallback" >&2
exit 99
EOF
cp "$tmpdir/dialog" "$tmpdir/whiptail"
chmod +x "$tmpdir/dialog" "$tmpdir/whiptail"
bootstrap_output="$(printf '\n' | PATH="$tmpdir:$PATH" "$ROOT_DIR/.dotfiles/bin/bootstrap.sh" 2>&1 || true)"
printf '%s\n' "$bootstrap_output"
grep -q "Dotfiles Bootstrap (no TUI available)" <<< "$bootstrap_output"
if grep -q "should not be used in shell fallback" <<< "$bootstrap_output"; then
  echo "Bootstrap attempted to use dialog/whiptail without a terminal." >&2
  exit 1
fi

echo "== X-forwarding dry-run =="
"$ROOT_DIR/.dotfiles/bin/setup-xforward.sh" --dry-run || true

echo "All dry-runs completed."
