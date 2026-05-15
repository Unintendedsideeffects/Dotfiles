#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_USER="${DOTFILES_TEST_USER:-dotfiles-test}"
TEST_HOME="/home/${TEST_USER}"
TEST_NAME="${DOTFILES_TEST_NAME:-Dotfiles Test User}"
TEST_EMAIL="${DOTFILES_TEST_EMAIL:-dotfiles-test@example.com}"
INSTALL_LOG="${TEST_HOME}/.dotfiles/install.log"
SELECTIONS="${DF_BOOTSTRAP_SELECTIONS:-packages locale_setup git_config validate}"
INPUT_FILE=""

log() {
  printf '[debian-e2e] %s\n' "$*"
}

assert_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    printf 'ASSERTION FAILED: expected file %s\n' "$path" >&2
    exit 1
  fi
}

assert_dir() {
  local path="$1"
  if [[ ! -d "$path" ]]; then
    printf 'ASSERTION FAILED: expected directory %s\n' "$path" >&2
    exit 1
  fi
}

assert_contains() {
  local path="$1"
  local needle="$2"
  if ! grep -Fq "$needle" "$path"; then
    printf 'ASSERTION FAILED: expected %s to contain %s\n' "$path" "$needle" >&2
    exit 1
  fi
}

dump_install_log_on_failure() {
  local status=$?
  if ((status != 0)); then
    echo >&2
    echo "==== Debian install check failed ====" >&2
    if [[ -f "$INSTALL_LOG" ]]; then
      tail -n 200 "$INSTALL_LOG" >&2 || true
    else
      echo "Install log not found at $INSTALL_LOG" >&2
    fi
  fi
  [[ -n "$INPUT_FILE" ]] && rm -f "$INPUT_FILE"
  exit "$status"
}
trap dump_install_log_on_failure EXIT

log "Installing base devcontainer prerequisites"
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y sudo git curl ca-certificates passwd locales

if ! id "$TEST_USER" >/dev/null 2>&1; then
  log "Creating test user $TEST_USER"
  useradd -m -s /bin/bash "$TEST_USER"
fi

cat > "/etc/sudoers.d/${TEST_USER}" <<EOF
Defaults:${TEST_USER} env_keep += "DF_BOOTSTRAP_SELECTIONS DEBIAN_FRONTEND DF_INSTALL_LOG_FILE"
${TEST_USER} ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 "/etc/sudoers.d/${TEST_USER}"

log "Resetting test home at $TEST_HOME"
rm -rf \
  "${TEST_HOME}/.Xresources" \
  "${TEST_HOME}/.bashrc" \
  "${TEST_HOME}/.config" \
  "${TEST_HOME}/.cfg" \
  "${TEST_HOME}/.envrc" \
  "${TEST_HOME}/.gitattributes" \
  "${TEST_HOME}/.gitconfig-aliases" \
  "${TEST_HOME}/.gitignore" \
  "${TEST_HOME}/.dotfiles" \
  "${TEST_HOME}/.gitconfig" \
  "${TEST_HOME}/.gitconfig.local" \
  "${TEST_HOME}/.xbindkeysrc" \
  "${TEST_HOME}/.xinitrc" \
  "${TEST_HOME}/.zshrc" \
  "${TEST_HOME}/.zprofile" \
  "${TEST_HOME}/.claude"

mkdir -p "$TEST_HOME"
chown -R "$TEST_USER:$TEST_USER" "$TEST_HOME"

log "Running quick-install from local repository"
INPUT_FILE="$(mktemp)"
printf 'yes\n%s\n%s\nyes\n' "$TEST_NAME" "$TEST_EMAIL" >"$INPUT_FILE"
sudo -u "$TEST_USER" \
  env -u SUDO_USER -u SUDO_UID -u SUDO_GID \
  HOME="$TEST_HOME" \
  DF_BOOTSTRAP_SELECTIONS="$SELECTIONS" \
  DEBIAN_FRONTEND=noninteractive \
  DOTFILES_REPO_URL="$ROOT_DIR" \
  bash "$ROOT_DIR/.dotfiles/bin/quick-install.sh" <"$INPUT_FILE"

log "Checking installed files and git configuration"
assert_file "${TEST_HOME}/.dotfiles/.installed"
assert_file "$INSTALL_LOG"
assert_file "${TEST_HOME}/.zshrc"
assert_file "${TEST_HOME}/.gitconfig"
assert_file "${TEST_HOME}/.gitconfig.local"
assert_dir "${TEST_HOME}/.cfg"
assert_contains "${TEST_HOME}/.gitconfig.local" "name = ${TEST_NAME}"
assert_contains "${TEST_HOME}/.gitconfig.local" "email = ${TEST_EMAIL}"
assert_contains "$INSTALL_LOG" "Repo:  $ROOT_DIR"
assert_contains "$INSTALL_LOG" "PRETTY_NAME="
assert_contains "$INSTALL_LOG" "Bootstrap started:"
assert_contains "$INSTALL_LOG" "Completed action: packages"
assert_contains "$INSTALL_LOG" "Completed action: locale_setup"
assert_contains "$INSTALL_LOG" "Completed action: git_config"
assert_contains "$INSTALL_LOG" "Completed action: validate"
assert_contains "$INSTALL_LOG" "Package install output"
assert_contains "$INSTALL_LOG" "Validation output"
assert_contains "$INSTALL_LOG" "Bootstrap completed successfully"

log "Checking default shell and validation result"
expected_shell="$(command -v zsh)"
actual_shell="$(getent passwd "$TEST_USER" | cut -d: -f7)"
if [[ "$actual_shell" != "$expected_shell" ]]; then
  printf 'ASSERTION FAILED: expected default shell %s, got %s\n' "$expected_shell" "$actual_shell" >&2
  exit 1
fi

sudo -u "$TEST_USER" env -u SUDO_USER -u SUDO_UID -u SUDO_GID HOME="$TEST_HOME" "${TEST_HOME}/.dotfiles/bin/validate.sh" >/tmp/dotfiles-validate.out
cat /tmp/dotfiles-validate.out
assert_contains /tmp/dotfiles-validate.out "Status:"

log "Debian quick-install end-to-end check passed"
