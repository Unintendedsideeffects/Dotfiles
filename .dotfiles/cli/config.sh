#!/usr/bin/env bash
# set -euo pipefail

safe_checkout() {
  if config checkout 2>&1 | grep -E "\s+\." | awk '{print $1}' | while read -r f; do mv "$HOME/$f" "$HOME/$f.backup"; done; then
    :
  fi
  config checkout
}

config() {
    # The base command for git with the bare repo setup
    local git_cmd=("/usr/bin/git" "--git-dir=$HOME/.cfg" "--work-tree=$HOME")

    # Check if the command is 'pull'
    if [[ "$1" == "pull" && "$#" -eq 1 ]]; then
        # Attempt to pull
        pull_output=$("${git_cmd[@]}" pull 2>&1)
        pull_exit_code=$?

        if [[ $pull_exit_code -eq 0 ]]; then
            echo "Dotfiles pull successful."
            echo "$pull_output"
            return 0
        fi

        # Check for the specific "overwritten by" error
        if echo "$pull_output" | grep -q "overwritten by"; then
            echo "Pull failed due to local changes. Backing up conflicting files."

            # Create a timestamped backup directory
            local backup_dir="$HOME/.backup/cfg/$(date +'%Y%m%d-%H%M%S')"
            mkdir -p "$backup_dir"
            echo "Backup directory created: $backup_dir"

            # Extract the list of conflicting files from the git output
            local conflicting_files
            conflicting_files=$(echo "$pull_output" | grep -E '^\s+[^\s]' | awk '{print $1}')

            if [[ -z "$conflicting_files" ]]; then
                echo "Could not parse conflicting files from git output."
                echo "Git output:"
                echo "$pull_output"
                return 1
            fi

            # Move conflicting files to the backup directory
            echo "Backing up conflicting files:"
            for file in $conflicting_files; do
                local full_path="$HOME/$file"
                if [[ -e "$full_path" ]]; then
                    echo " - $file"
                    # Ensure parent directory exists in backup location
                    mkdir -p "$backup_dir/$(dirname "$file")"
                    mv "$full_path" "$backup_dir/$file"
                else
                    echo " - Warning: $file not found at $full_path"
                fi
            done

            echo "Retrying pull..."
            # Attempt to pull again
            "${git_cmd[@]}" pull
            if [[ $? -eq 0 ]]; then
                echo "Pull successful after backing up local changes."
                echo "Your conflicting files were moved to $backup_dir"
            else
                echo "Pull failed again after backup."
                echo "Please resolve conflicts manually. Your files are safe in $backup_dir"
                return 1
            fi
        else
            # For other pull errors, just print the error
            echo "An error occurred during 'config pull':"
            echo "$pull_output"
            return $pull_exit_code
        fi
    else
        # For any other command than 'pull', just pass it to git
        "${git_cmd[@]}" "$@"
    fi
}
