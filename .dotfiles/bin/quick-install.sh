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

# Track created resources for cleanup
declare -a CREATED_USERS=()
declare -a CREATED_FILES=()

# Cleanup handler for failures
cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        echo "ERROR: Installation failed with exit code $exit_code"
        echo "Performing cleanup..."

        # Offer to remove created user
        if [[ ${#CREATED_USERS[@]} -gt 0 ]]; then
            for user in "${CREATED_USERS[@]}"; do
                echo ""
                read -p "Remove user $user? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
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

# Check all required dependencies upfront
required_commands=("git" "sudo" "awk" "grep" "getent" "useradd" "usermod" "visudo")
missing_commands=()

for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing_commands+=("$cmd")
    fi
done

if [[ ${#missing_commands[@]} -gt 0 ]]; then
    echo "ERROR: Required commands not found: ${missing_commands[*]}"
    echo "Please install missing dependencies and try again."
    exit 1
fi

# Determine target user and home directory
if [[ $EUID -eq 0 ]]; then
    # Running as root
    echo "Running as root."
    echo ""

    # Ask if they want to create a new user or install for root
    read -p "Do you want to create a new user? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Create a new user
        while true; do
            read -p "Enter username for new user: " new_username

            # Validate username
            if [[ -z "$new_username" ]]; then
                echo "ERROR: Username cannot be empty."
                continue
            fi

            if ! [[ "$new_username" =~ ^[a-z_][a-z0-9_-]*\$?$ ]]; then
                echo "ERROR: Invalid username. Use lowercase letters, numbers, underscore, and hyphen."
                continue
            fi

            if id "$new_username" >/dev/null 2>&1; then
                echo "ERROR: User '$new_username' already exists."
                continue
            fi

            break
        done

        echo ""
        echo "Creating user: $new_username"
        if ! useradd -m -s /bin/bash "$new_username"; then
            echo "ERROR: Failed to create user '$new_username'"
            exit 1
        fi
        CREATED_USERS+=("$new_username")

        echo ""
        echo "Set password for $new_username:"
        if ! passwd "$new_username"; then
            echo "ERROR: Failed to set password for '$new_username'"
            exit 1
        fi

        # Ask about passwordless sudo
        echo ""
        echo "WARNING: Passwordless sudo allows the user to run commands as root without a password."
        echo "This is convenient but reduces security. Only enable on trusted systems."
        echo ""
        read -p "Enable passwordless sudo for $new_username? (y/N): " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Use visudo to validate sudoers entry before writing
            sudoers_entry="$new_username ALL=(ALL) NOPASSWD:ALL"
            temp_sudoers=$(mktemp)
            CREATED_FILES+=("$temp_sudoers")

            echo "$sudoers_entry" > "$temp_sudoers"
            chmod 0440 "$temp_sudoers"

            # Validate with visudo
            if visudo -c -f "$temp_sudoers" >/dev/null 2>&1; then
                mv "$temp_sudoers" "/etc/sudoers.d/$new_username"
                CREATED_FILES+=("/etc/sudoers.d/$new_username")
                echo "Passwordless sudo enabled for $new_username"
            else
                rm -f "$temp_sudoers"
                echo "ERROR: Invalid sudoers syntax. This should not happen."
                exit 1
            fi
        else
            # Regular sudo access - try both common group names
            if usermod -aG sudo "$new_username" 2>/dev/null; then
                echo "Added $new_username to sudo group"
            elif usermod -aG wheel "$new_username" 2>/dev/null; then
                echo "Added $new_username to wheel group"
            else
                echo "ERROR: Could not add $new_username to sudo/wheel group"
                echo "Your system may use a different group for sudo access."
                exit 1
            fi
        fi

        TARGET_USER="$new_username"
        TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    else
        # Install for root
        TARGET_USER="root"
        TARGET_HOME="/root"
    fi
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

if [[ "$SKIP_INSTALL" == true ]]; then
    if [[ ! -d "$CONFIG_DIR" ]]; then
        echo "WARNING: Existing dotfiles repo not found; continuing with reinstall."
        SKIP_INSTALL=false
    else
        # Keep scripts current when rerunning, but don't overwrite local changes.
        if [[ -n "$(config status --porcelain 2>/dev/null)" ]]; then
            echo "WARNING: Local dotfiles changes detected; skipping update pull."
        else
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

    # Limit checkout to .dotfiles to keep repo metadata (README, etc.) out of $HOME
    if config sparse-checkout init --cone >/dev/null 2>&1; then
        config sparse-checkout set .dotfiles >/dev/null 2>&1 || true
    else
        config config core.sparseCheckout true
        run_as_user mkdir -p "$CONFIG_DIR/info"
        printf "/.dotfiles/\n" > "$CONFIG_DIR/info/sparse-checkout"
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
config log --oneline -5

echo ""
echo "The following scripts will be executed:"
echo "  - .dotfiles/shell/install.sh - Install shell configuration"
echo "  - .dotfiles/bin/bootstrap.sh - Interactive system setup"
echo ""
echo "WARNING: These scripts will be executed with the privileges of user: $TARGET_USER"
echo ""
read -p "Continue with installation? (y/N): " -n 1 -r </dev/tty
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled by user."
    exit 0
fi

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
read -p "Press Enter to continue with interactive setup..." </dev/tty

run_as_user "$TARGET_HOME/.dotfiles/bin/bootstrap.sh"

# Mark installation as successful
INSTALL_MARKER="$TARGET_HOME/.dotfiles/.installed"
echo "$(date +%s)" | run_as_user tee "$INSTALL_MARKER" >/dev/null

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
echo ""
echo "Learn more: https://github.com/Unintendedsideeffects/Dotfiles"

# Disable cleanup trap on success
trap - EXIT
