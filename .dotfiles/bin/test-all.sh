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
bootstrap_capture_output="$(printf 'Test User\ntest@example.com\nyes\n' | HOME="$tmp_home" PATH="$tmpdir:$PATH" DF_BOOTSTRAP_SELECTIONS='git_config' "$ROOT_DIR/.dotfiles/bin/bootstrap.sh" 2>&1 || true)"
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

echo "== Default shell update prefers passwordless sudo usermod =="
shell_test_dir="$(mktemp -d)"
shell_state_file="$shell_test_dir/current-shell"
sudo_log_file="$shell_test_dir/sudo.log"
usermod_log_file="$shell_test_dir/usermod.log"
trap 'rm -rf "$tmpdir" "$tmp_home" "$shell_test_dir"' EXIT
printf '/bin/bash\n' > "$shell_state_file"

cat > "$shell_test_dir/zsh" <<EOF
#!/usr/bin/env bash
exit 0
EOF

cat > "$shell_test_dir/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" && "\${2:-}" == "testuser" ]]; then
  printf 'testuser:x:1000:1000::/home/testuser:%s\n' "\$(cat "$shell_state_file")"
  exit 0
fi
exit 1
EOF

cat > "$shell_test_dir/sudo" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$sudo_log_file"
if [[ "\${1:-}" == "-n" && "\${2:-}" == "true" ]]; then
  exit 0
fi
if [[ "\${1:-}" == "-n" ]]; then
  shift
fi
"\$@"
EOF

cat > "$shell_test_dir/usermod" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$usermod_log_file"
if [[ "\${1:-}" == "-s" && -n "\${2:-}" ]]; then
  printf '%s\n' "\$2" > "$shell_state_file"
  exit 0
fi
exit 1
EOF

cat > "$shell_test_dir/chsh" <<'EOF'
#!/usr/bin/env bash
echo "chsh should not be used when passwordless sudo usermod is available" >&2
exit 99
EOF

chmod +x "$shell_test_dir/zsh" "$shell_test_dir/getent" "$shell_test_dir/sudo" "$shell_test_dir/usermod" "$shell_test_dir/chsh"
shell_update_output="$(PATH="$shell_test_dir:$PATH" USER="testuser" HOME="$tmp_home" "$ROOT_DIR/.dotfiles/bin/setup-packages.sh" --test-ensure-zsh-default-shell 2>&1 || true)"
printf '%s\n' "$shell_update_output"
expected_zsh_path="$shell_test_dir/zsh"
if [[ "$(cat "$shell_state_file")" != "$expected_zsh_path" ]]; then
  echo "Default shell update did not switch to the expected zsh path." >&2
  exit 1
fi
if ! grep -Fxq -- "-n usermod -s $expected_zsh_path testuser" "$sudo_log_file"; then
  echo "Default shell update did not use sudo -n usermod for passwordless sudo." >&2
  exit 1
fi
if grep -q "chsh should not be used" <<< "$shell_update_output"; then
  echo "Default shell update incorrectly fell back to chsh." >&2
  exit 1
fi

echo "All dry-runs completed."
