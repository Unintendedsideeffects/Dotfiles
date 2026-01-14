#!/usr/bin/env bash
# set -euo pipefail

# Cleanup function to keep only the 5 most recent backups
cleanup_old_backups() {
    local backup_base_dir="$HOME/.local/backups/cfg"

    # Check if backup directory exists
    if [[ ! -d "$backup_base_dir" ]]; then
        mkdir -p "$backup_base_dir"
        return 0
    fi

    # Count the number of backup directories
    local backup_count
    backup_count=$(find "$backup_base_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)

    # If we have more than 5 backups, remove the oldest ones
    if [[ $backup_count -gt 5 ]]; then
        echo "Cleaning up old backups (keeping 5 most recent)..."
        # List directories by modification time, oldest first, skip the 5 newest, and delete
        find "$backup_base_dir" -mindepth 1 -maxdepth 1 -type d -printf '%T+ %p\n' | \
            sort | \
            head -n -5 | \
            cut -d' ' -f2- | \
            while IFS= read -r old_backup; do
                echo " - Removing old backup: $(basename "$old_backup")"
                rm -rf "$old_backup"
            done
    fi
}

config() {
    # The base command for git with the bare repo setup
    local git_cmd=("/usr/bin/git" "--git-dir=$HOME/.cfg" "--work-tree=$HOME")

    # Check if the command is 'pull'
    if [[ "$1" == "pull" && "$#" -eq 1 ]]; then
        # Attempt to pull
        local pull_output
        local pull_exit_code
        pull_output=$("${git_cmd[@]}" pull 2>&1)
        pull_exit_code=$?

        if [[ $pull_exit_code -eq 0 ]]; then
            echo "Dotfiles pull successful."
            echo "$pull_output"
            return 0
        fi

        # Check for the specific "overwritten by" error
        if echo "$pull_output" | command grep -q "overwritten by"; then
            echo "Pull failed due to local changes. Backing up conflicting files."

            # Create a timestamped backup directory
            local backup_dir="$HOME/.local/backups/cfg/$(date +'%Y%m%d-%H%M%S')"
            if ! mkdir -p "$backup_dir"; then
                echo "Error: Failed to create backup directory."
                return 1
            fi
            echo "Backup directory created: $backup_dir"

            # Extract the list of conflicting files from the git output
            # Files appear after "overwritten by merge:" line, indented with whitespace
            local conflicting_files
            conflicting_files=$(echo "$pull_output" | command grep -E '^\s+\.' | awk '{print $1}')

            if [[ -z "$conflicting_files" ]]; then
                echo "Error: Could not parse conflicting files from git output."
                echo "Git output:"
                echo "$pull_output"
                return 1
            fi

            # Move conflicting files to the backup directory
            echo "Backing up conflicting files:"
            local backup_failed=0
            for file in $conflicting_files; do
                local full_path="$HOME/$file"
                if [[ -e "$full_path" ]]; then
                    echo " - $file"
                    # Ensure parent directory exists in backup location
                    local file_backup_dir="$backup_dir/$(dirname "$file")"
                    if ! mkdir -p "$file_backup_dir"; then
                        echo "Error: Failed to create directory structure for $file"
                        backup_failed=1
                        continue
                    fi
                    if ! mv "$full_path" "$backup_dir/$file"; then
                        echo "Error: Failed to backup $file"
                        backup_failed=1
                    fi
                else
                    echo " - Warning: $file not found at $full_path"
                fi
            done

            if [[ $backup_failed -eq 1 ]]; then
                echo "Warning: Some files failed to backup. Check errors above."
            fi

            # Clean up old backups (keep only 5 most recent)
            cleanup_old_backups

            echo "Retrying pull..."
            # Attempt to pull again
            if "${git_cmd[@]}" pull; then
                echo "Pull successful after backing up local changes."
                echo "Your conflicting files were moved to $backup_dir"
                return 0
            else
                echo "Error: Pull failed again after backup."
                echo "Please resolve conflicts manually. Your files are safe in $backup_dir"
                return 1
            fi
        else
            # For other pull errors, just print the error
            echo "Error: An error occurred during 'config pull':"
            echo "$pull_output"
            return $pull_exit_code
        fi
    else
        # For any other command than 'pull', just pass it to git
        "${git_cmd[@]}" "$@"
    fi
}

safe_checkout() {
  local backup_dir="$HOME/.local/backups/dotfiles/.dotfiles-backup.$(date +%s)"
  mkdir -p "$backup_dir"

  if config checkout 2>&1 | command grep -E "\s+\." | awk '{print $1}' | while read -r f; do
    mkdir -p "$backup_dir/$(dirname "$f")"
    mv "$HOME/$f" "$backup_dir/$f"
  done; then
    :
  fi
  config checkout

  # Rotate backups
  if [[ -x "$HOME/.local/bin/backup-rotate" ]]; then
    "$HOME/.local/bin/backup-rotate" "$HOME/.local/backups/dotfiles" 5
  fi
}
