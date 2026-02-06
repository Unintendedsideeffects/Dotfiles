#!/bin/bash
# Quick install script for Malcolm's Dotfiles
set -euo pipefail

REINSTALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --reinstall)
            REINSTALL=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--reinstall]"
            exit 2
            ;;
    esac
done

IS_PIPED=false
if [[ ! -t 0 ]]; then
    IS_PIPED=true
fi

REPO_URL="https://github.com/Unintendedsideeffects/Dotfiles.git"

TTY_AVAILABLE=false
TTY_IN_FD=""
TTY_OUT_FD=""
if exec 5</dev/tty 6>/dev/tty 2>/dev/null; then
    TTY_AVAILABLE=true
    TTY_IN_FD=5
    TTY_OUT_FD=6
fi

read_tty_line() {
    local prompt="$1"
    local __var="$2"
    local default="${3:-}"
    local __value=""

    if [[ "$TTY_AVAILABLE" == true ]]; then
        printf '%s' "$prompt" >&$TTY_OUT_FD
        IFS= read -r -u "$TTY_IN_FD" __value || __value=""
    else
        IFS= read -r -p "$prompt" __value || __value=""
    fi

    if [[ -z "$__value" && -n "$default" ]]; then
        __value="$default"
    fi

    printf -v "$__var" '%s' "$__value"
}

read_tty_key() {
    local prompt="$1"
    local __var="$2"
    local __value=""
    local __discard=""

    if [[ "$TTY_AVAILABLE" == true ]]; then
        printf '%s' "$prompt" >&$TTY_OUT_FD
        IFS= read -r -n 1 -u "$TTY_IN_FD" __value || __value=""
        IFS= read -r -u "$TTY_IN_FD" __discard || true
        case "$__value" in
            $'\n'|$'\r') __value="" ;;
        esac
        printf '\n' >&$TTY_OUT_FD
    else
        IFS= read -r -n 1 -p "$prompt" __value || __value=""
        IFS= read -r __discard || true
    fi

    printf -v "$__var" '%s' "$__value"
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-N}"
    local auto_yes="${3:-false}"
    local reply=""

    if [[ "$TTY_AVAILABLE" != true ]]; then
        if [[ "$auto_yes" == "true" ]]; then
            echo "WARNING: No TTY available; auto-accepting to continue." >&2
            return 0
        fi
        [[ "$default" =~ ^[Yy]$ ]] && return 0 || return 1
    fi

    read_tty_key "$prompt" reply
    if [[ -z "$reply" && -n "$default" ]]; then
        reply="$default"
    fi

    case "${reply:0:1}" in
        [Yy]) return 0 ;;
        *) return 1 ;;
    esac
}

pause_for_enter() {
    local prompt="$1"

    if [[ "$TTY_AVAILABLE" == true ]]; then
        read_tty_line "$prompt" _ || true
    else
        echo "WARNING: No TTY available; continuing without pause." >&2
    fi
}

# Track created resources for cleanup
declare -a CREATED_USERS=()
declare -a CREATED_FILES=()

# Cleanup handler for failures
cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        echo "========================================"
        echo "Installation FAILED: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Exit code: $exit_code"
        echo "========================================"
        echo ""
        echo "ERROR: Installation failed with exit code $exit_code"
        echo "Performing cleanup..."

        # Offer to remove created user
        if [[ ${#CREATED_USERS[@]} -gt 0 ]]; then
            for user in "${CREATED_USERS[@]}"; do
                echo ""
                if prompt_yes_no "Remove user $user? (y/N): " "N"; then
                    userdel -r "$user" 2>/dev/null || true
                    rm -f "/etc/sudoers.d/$user"
                    echo "User $user removed"
                fi
            done
        fi

        # Clean up created files
        for file in "${CREATED_FILES[@]}"; do
            rm -f "$file"
        done
    fi
}

trap cleanup_on_error EXIT

# Helper function to check for commands with extended PATH
# /usr/sbin is not in default PATH for non-root users on Debian
# Args: $1 - command name to check
# Returns: 0 if command exists, 1 otherwise
command_exists() {
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH" command -v "$1" >/dev/null 2>&1
}

run_as_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
        return $?
    fi

    if command_exists sudo; then
        sudo "$@"
        return $?
    fi

    return 1
}

install_git_if_missing() {
    if command_exists git; then
        return 0
    fi

    echo "git not found; attempting to install it."

    if [[ $EUID -ne 0 ]] && ! command_exists sudo; then
        echo "ERROR: git is missing and sudo is not available to install it."
        exit 1
    fi

    if command_exists apt-get; then
        run_as_root apt-get update
        run_as_root apt-get install -y git
    elif command_exists apt; then
        run_as_root apt update
        run_as_root apt install -y git
    elif command_exists dnf; then
        run_as_root dnf install -y git
    elif command_exists yum; then
        run_as_root yum install -y git
    elif command_exists pacman; then
        run_as_root pacman -Sy --noconfirm git
    elif command_exists apk; then
        run_as_root apk add git
    else
        echo "ERROR: git is missing and no supported package manager was found."
        exit 1
    fi

    if ! command_exists git; then
        echo "ERROR: git is still missing after the install attempt."
        exit 1
    fi
}

# Check all required dependencies upfront
# Core commands needed for basic operation
required_commands=("sudo" "awk" "grep" "getent")
missing_commands=()

for cmd in "${required_commands[@]}"; do
    if ! command_exists "$cmd"; then
        missing_commands+=("$cmd")
    fi
done

if [[ ${#missing_commands[@]} -gt 0 ]]; then
    echo "ERROR: Required commands not found: ${missing_commands[*]}"
    echo "Please install missing dependencies and try again."
    exit 1
fi

install_git_if_missing

# Check optional commands for user creation flow
# These are only needed when creating a new user as root
USER_CREATION_AVAILABLE=true
user_creation_commands=("useradd" "usermod" "visudo")
missing_user_commands=()

for cmd in "${user_creation_commands[@]}"; do
    if ! command_exists "$cmd"; then
        missing_user_commands+=("$cmd")
        USER_CREATION_AVAILABLE=false
    fi
done

if [[ "$USER_CREATION_AVAILABLE" != true ]]; then
    echo "WARNING: User creation commands not available: ${missing_user_commands[*]}"
    echo "User creation will not be available in the setup menu."
fi

# Export flag for bootstrap menu
export DF_USER_CREATION_AVAILABLE="$USER_CREATION_AVAILABLE"

# Determine target user and home directory
if [[ $EUID -eq 0 ]]; then
    # Running as root - install for root
    # User creation is now available in the bootstrap menu
    TARGET_USER="root"
    TARGET_HOME="/root"
    echo "Running as root. Installing for root user."
    echo "User creation and passwordless sudo are available in the setup menu."
    echo ""
elif [[ -n "${SUDO_USER:-}" ]]; then
    # Running with sudo as regular user
    TARGET_USER="$SUDO_USER"
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
else
    # Running as regular user
    TARGET_USER="$USER"
    TARGET_HOME="$HOME"
fi

# Validate TARGET_HOME
if [[ -z "$TARGET_HOME" ]]; then
    echo "ERROR: Could not determine home directory for $TARGET_USER"
    exit 1
fi

if [[ ! -d "$TARGET_HOME" ]]; then
    echo "ERROR: Home directory does not exist: $TARGET_HOME"
    exit 1
fi

CONFIG_DIR="$TARGET_HOME/.cfg"
INSTALL_MARKER="$TARGET_HOME/.dotfiles/.installed"

# Setup installation logging
LOG_DIR="$TARGET_HOME/.dotfiles"
LOG_FILE="$LOG_DIR/install.log"

# Create log directory if it doesn't exist
if [[ "$TARGET_USER" != "$(whoami)" ]]; then
    sudo -u "$TARGET_USER" mkdir -p "$LOG_DIR" 2>/dev/null || true
else
    mkdir -p "$LOG_DIR" 2>/dev/null || true
fi

# Start logging with timestamp header
{
    echo ""
    echo "========================================"
    echo "Installation started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "User: $TARGET_USER"
    echo "Home: $TARGET_HOME"
    echo "========================================"
    echo ""
} >> "$LOG_FILE" 2>&1

# Save original file descriptors for later restoration (needed for TUI programs)
exec 3>&1 4>&2

# Redirect all output to both terminal and log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Check if already installed
SKIP_INSTALL=false
if [[ -f "$INSTALL_MARKER" ]]; then
    if [[ "$IS_PIPED" != true && "$REINSTALL" != true ]]; then
        SKIP_INSTALL=true
    fi
fi

echo ""
echo "Installing Malcolm's Dotfiles for user: $TARGET_USER"
echo "Home directory: $TARGET_HOME"
echo "Log file: $LOG_FILE"
echo ""

# Helper to run commands as target user
run_as_user() {
    # Validate HOME directory exists
    if [[ ! -d "$TARGET_HOME" ]]; then
        echo "ERROR: TARGET_HOME does not exist: $TARGET_HOME"
        exit 1
    fi

    if [[ "$TARGET_USER" != "$(whoami)" ]]; then
        sudo -u "$TARGET_USER" HOME="$TARGET_HOME" -- "$@"
    else
        "$@"
    fi
}

# Config helper for managing dotfiles directly (no shell setup required).
config() {
    run_as_user /usr/bin/git --git-dir="$CONFIG_DIR" --work-tree="$TARGET_HOME" "$@"
}

create_local_gitconfig_from_existing() {
    local source_file="$TARGET_HOME/.gitconfig"
    local local_file="$TARGET_HOME/.gitconfig.local"
    local backup_dir="$TARGET_HOME/.local/backups/dotfiles"
    local backup_file="$backup_dir/.gitconfig.pre-dotfiles.$(date +%s)"

    run_as_user mkdir -p "$backup_dir"
    run_as_user cp "$source_file" "$backup_file"
    run_as_user cp "$source_file" "$local_file"

    local source_abs=""
    local local_abs=""
    source_abs=$(run_as_user readlink -f "$source_file" 2>/dev/null || echo "$source_file")
    local_abs=$(run_as_user readlink -f "$local_file" 2>/dev/null || echo "$local_file")

    resolve_gitconfig_include_path() {
        local include_path="$1"
        local base_file="$2"
        local base_dir=""
        local expanded_path=""

        base_dir=$(dirname "$base_file")
        case "$include_path" in
            \~/*) expanded_path="$TARGET_HOME/${include_path#\~/}" ;;
            \~) expanded_path="$TARGET_HOME" ;;
            /*) expanded_path="$include_path" ;;
            *) expanded_path="$base_dir/$include_path" ;;
        esac

        run_as_user readlink -f "$expanded_path" 2>/dev/null || printf '%s\n' "$expanded_path"
    }

    sanitize_gitconfig_include_key() {
        local key="$1"
        local include_value=""
        local include_resolved=""
        local safe_values=()

        # Keep non-recursive includes, drop ones that would re-include
        # ~/.gitconfig or ~/.gitconfig.local and trigger depth errors.
        while IFS= read -r include_value; do
            [[ -z "$include_value" ]] && continue
            include_resolved=$(resolve_gitconfig_include_path "$include_value" "$source_file")
            if [[ "$include_resolved" == "$source_abs" || "$include_resolved" == "$local_abs" ]]; then
                continue
            fi
            safe_values+=("$include_value")
        done < <(run_as_user git config --no-includes --file "$source_file" --get-all "$key" 2>/dev/null || true)

        run_as_user git config --file "$local_file" --unset-all "$key" 2>/dev/null || true
        for include_value in "${safe_values[@]}"; do
            run_as_user git config --file "$local_file" --add "$key" "$include_value"
        done
    }

    sanitize_gitconfig_include_key "include.path"

    local include_if_keys=()
    local include_if_key=""
    while IFS= read -r include_if_key; do
        [[ -n "$include_if_key" ]] && include_if_keys+=("$include_if_key")
    done < <(run_as_user git config --no-includes --file "$source_file" --name-only --get-regexp '^includeif\..*\.path$' 2>/dev/null || true)
    for include_if_key in "${include_if_keys[@]}"; do
        sanitize_gitconfig_include_key "$include_if_key"
    done

    local migrated_name=""
    local migrated_email=""
    migrated_name=$(run_as_user git config --no-includes --file "$local_file" --get user.name 2>/dev/null || true)
    migrated_email=$(run_as_user git config --no-includes --file "$local_file" --get user.email 2>/dev/null || true)

    echo "Backed up existing .gitconfig to $backup_file"
    echo "Created .gitconfig.local from existing .gitconfig (recursive includes removed)"
    if [[ -z "$migrated_name" || -z "$migrated_email" ]]; then
        echo "WARNING: Could not fully migrate git identity (user.name/user.email). Run bootstrap Git Configuration to set them."
    fi
}

configure_sparse_checkout() {
    local apply="${1:-false}"

    # Use non-cone mode for explicit pattern control
    # Include dotfiles directories and shell/git configs; exclude repo metadata
    config config core.sparseCheckout true
    config config core.sparseCheckoutCone false
    run_as_user mkdir -p "$CONFIG_DIR/info"
    run_as_user bash -c "cat > '$CONFIG_DIR/info/sparse-checkout' << 'EOF'
/.dotfiles/
/.config/
/.claude/
/.bashrc
/.zshrc
/.zprofile
/.gitconfig
/.gitconfig-aliases
/.gitconfig.local.example
/.gitattributes
/.gitignore
/.envrc
/.xbindkeysrc
/.xinitrc
/.Xresources
/.SHA256SUMS
EOF"

    if [[ "$apply" == "true" ]]; then
        config read-tree -mu HEAD >/dev/null 2>&1 || config checkout -f >/dev/null 2>&1 || true
    fi
}

if [[ "$SKIP_INSTALL" == true ]]; then
    if [[ ! -d "$CONFIG_DIR" ]]; then
        echo "WARNING: Existing dotfiles repo not found; continuing with reinstall."
        SKIP_INSTALL=false
    else
        # Keep scripts current when rerunning, but don't overwrite local changes.
        if [[ -n "$(config status --porcelain 2>/dev/null)" ]]; then
            echo "WARNING: Local dotfiles changes detected; skipping update pull."
        else
            configure_sparse_checkout true
            if ! config pull >/dev/null 2>&1; then
                echo "WARNING: Failed to update dotfiles; continuing with reinstall."
                SKIP_INSTALL=false
            fi
        fi
    fi
fi

if [[ "$SKIP_INSTALL" != true ]]; then
    # Backup existing .cfg if it exists
    if [[ -d "$CONFIG_DIR" ]]; then
        echo "WARNING: Backing up existing .cfg directory..."
        run_as_user mkdir -p "$TARGET_HOME/.local/backups/cfg-repo"
        run_as_user mv "$CONFIG_DIR" "$TARGET_HOME/.local/backups/cfg-repo/.cfg.backup.$(date +%s)"
    fi

    # Clone the bare repository
    echo "Cloning dotfiles repository..."
    run_as_user git clone --bare "$REPO_URL" "$CONFIG_DIR"

    # Limit checkout to .dotfiles and .config to keep repo metadata (README, etc.) out of $HOME
    configure_sparse_checkout false

    # Preserve user identity settings without moving include directives into
    # .gitconfig.local (which can create recursive include loops).
    if [[ -f "$TARGET_HOME/.gitconfig" && ! -f "$TARGET_HOME/.gitconfig.local" ]]; then
        echo "Preserving existing .gitconfig safely..."
        create_local_gitconfig_from_existing
    fi

    # Handle existing dotfiles
    echo "Installing dotfiles (will overwrite existing files)..."
    if ! checkout_output=$(config checkout 2>&1); then
        echo "WARNING: Some files already exist. Creating backup and forcing checkout..."
        backup_dir="$TARGET_HOME/.local/backups/dotfiles/.dotfiles-backup.$(date +%s)"
        run_as_user mkdir -p "$backup_dir"

        mapfile -t conflict_files < <(printf '%s\n' "$checkout_output" | grep -E "^\s+\." | awk '{print $1}')
        if [[ ${#conflict_files[@]} -eq 0 ]]; then
            echo "ERROR: Failed to determine conflicting files for backup."
            echo "$checkout_output"
            exit 1
        fi

        for path in "${conflict_files[@]}"; do
            if [[ -e "$TARGET_HOME/$path" ]]; then
                run_as_user mkdir -p "$backup_dir/$(dirname "$path")"
                run_as_user mv "$TARGET_HOME/$path" "$backup_dir/$path"
            fi
        done

        # Force checkout, overwriting existing files
        config checkout -f
        echo "OK: Dotfiles installed (existing files backed up to $backup_dir)"

        # Rotate backups to keep only 5 most recent
        if [[ -x "$TARGET_HOME/.local/bin/backup-rotate" ]]; then
            run_as_user "$TARGET_HOME/.local/bin/backup-rotate" "$TARGET_HOME/.local/backups/dotfiles" 5
        fi
    else
        echo "OK: Dotfiles installed successfully"
    fi

    # Make scripts executable
    echo "Making scripts executable..."
    for dir in "$TARGET_HOME/.dotfiles/bin" "$TARGET_HOME/.dotfiles/shell"; do
        if [[ -d "$dir" ]]; then
            run_as_user find "$dir" -type f -name "*.sh" -exec chmod +x {} \;
        else
            echo "WARNING: Directory not found: $dir"
        fi
    done
fi

# Verify repository and show what will be executed
echo ""
echo "Repository cloned successfully. Recent commits:"
config --no-pager log --oneline -5

echo ""
echo "The following scripts will be executed:"
echo "  - .dotfiles/shell/install.sh - Install shell configuration"
echo "  - .dotfiles/bin/bootstrap.sh - Interactive system setup"
echo ""

# Source the config to get the config alias
run_as_user bash -c "source '$TARGET_HOME/.dotfiles/cli/config.sh'"

# Install shell configuration
echo ""
echo "Installing shell configuration..."
run_as_user "$TARGET_HOME/.dotfiles/shell/install.sh"

# Run interactive bootstrap
echo ""
echo "Starting interactive setup..."
echo "   - Select 'Install Packages' to get development tools"
echo "   - Select 'WSL Configuration Setup' if you're on WSL"
echo ""
pause_for_enter "Press Enter to continue with interactive setup..."

# Temporarily restore normal stdout/stderr for TUI programs (whiptail/dialog)
# The tee redirection breaks terminal control needed for arrow keys and proper display
exec 1>&3 2>&4

if [[ "$TTY_AVAILABLE" == true ]]; then
    if command -v tput >/dev/null 2>&1; then
        if ! tput cols >/dev/null 2>&1; then
            export TERM="xterm-256color"
        fi
    fi
    if run_as_user "$TARGET_HOME/.dotfiles/bin/bootstrap.sh" </dev/tty >/dev/tty 2>&1; then
        :
    else
        bootstrap_rc=$?
        echo "WARNING: Interactive bootstrap exited with code $bootstrap_rc; continuing installation." >&2
    fi
else
    echo "WARNING: No TTY available; skipping interactive bootstrap." >&2
    echo "You can run the bootstrap menu later with: ~/.dotfiles/bin/bootstrap.sh" >&2
fi

exec > >(tee -a "$LOG_FILE") 2>&1 # Re-enable logging after interactive bootstrap completes

# Mark installation as successful
INSTALL_MARKER="$TARGET_HOME/.dotfiles/.installed"
echo "$(date +%s)" | run_as_user tee "$INSTALL_MARKER" >/dev/null

echo ""
echo "========================================"
echo "Installation completed: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
if [[ $EUID -eq 0 && "$TARGET_USER" != "root" ]]; then
    echo "   - Switch to the new user: su - $TARGET_USER"
fi
echo "   - Restart your shell or run: source ~/.zshrc"
echo "   - Use 'config' command to manage your dotfiles"
echo "   - Run 'validate.sh' to verify your setup"
echo "   - Review installation log: $LOG_FILE"
echo ""
echo "Learn more: https://github.com/Unintendedsideeffects/Dotfiles"

# Close saved file descriptors
exec 3>&- 4>&-

# Disable cleanup trap on success
trap - EXIT
