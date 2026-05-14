#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "== Validate script =="
"$ROOT_DIR/.dotfiles/bin/validate.sh" || true

echo "== Bootstrap dry-run =="
"$ROOT_DIR/.dotfiles/bin/bootstrap.sh" --dry-run || true

echo "== Bootstrap shell fallback =="
tmpdir="$(mktemp -d)"
tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmpdir" "$tmp_home"' EXIT
cat > "$tmpdir/dialog" <<'EOF'
#!/usr/bin/env bash
echo "dialog should not be used in shell fallback" >&2
exit 99
EOF
cp "$tmpdir/dialog" "$tmpdir/whiptail"
chmod +x "$tmpdir/dialog" "$tmpdir/whiptail"
bootstrap_output="$(printf '\n' | PATH="$tmpdir:$PATH" "$ROOT_DIR/.dotfiles/bin/bootstrap.sh" 2>&1 || true)"
printf '%s\n' "$bootstrap_output"
if ! grep -q "Dotfiles Bootstrap (no TUI available)" <<< "$bootstrap_output"; then
  echo "Bootstrap shell fallback banner not found in output." >&2
  exit 1
fi
if grep -q "should not be used in shell fallback" <<< "$bootstrap_output"; then
  echo "Bootstrap attempted to use dialog/whiptail without a terminal." >&2
  exit 1
fi

echo "== Bootstrap shell fallback without input =="
bootstrap_no_input_output="$("$ROOT_DIR/.dotfiles/bin/bootstrap.sh" < /dev/null 2>&1 || true)"
printf '%s\n' "$bootstrap_no_input_output"
if ! grep -q "No shell input available; skipping fallback menu." <<< "$bootstrap_no_input_output"; then
  echo "Bootstrap no-input fallback message not found in output." >&2
  exit 1
fi
if grep -q "Dotfiles Bootstrap (no TUI available)" <<< "$bootstrap_no_input_output"; then
  echo "Bootstrap displayed fallback menu despite no shell input." >&2
  exit 1
fi

echo "== Bootstrap shell fallback input capture =="
bootstrap_capture_output="$(printf '3\nTest User\ntest@example.com\nyes\n\n' | HOME="$tmp_home" PATH="$tmpdir:$PATH" "$ROOT_DIR/.dotfiles/bin/bootstrap.sh" 2>&1 || true)"
printf '%s\n' "$bootstrap_capture_output"
if ! grep -q '^	name = Test User$' "$tmp_home/.gitconfig.local"; then
  echo "Bootstrap shell fallback failed to capture Git username input correctly." >&2
  exit 1
fi
if ! grep -q '^	email = test@example.com$' "$tmp_home/.gitconfig.local"; then
  echo "Bootstrap shell fallback failed to capture Git email input correctly." >&2
  exit 1
fi

echo "== X-forwarding dry-run =="
"$ROOT_DIR/.dotfiles/bin/setup-xforward.sh" --dry-run || true

echo "All dry-runs completed."
