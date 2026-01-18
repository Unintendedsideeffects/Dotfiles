#!/usr/bin/env bash
# StatusLine command for Claude Code - Adventure Time theme

input=$(cat)

float_lt() {
    awk -v a="$1" -v b="$2" 'BEGIN {
        if (a == "" || b == "") exit 1
        if (a !~ /^-?[0-9]+([.][0-9]+)?$/ || b !~ /^-?[0-9]+([.][0-9]+)?$/) exit 1
        exit !(a < b)
    }'
}

cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
output_style=$(echo "$input" | jq -r '.output_style.name // empty')

# Usage tracking (5-hour window)
usage_pct=$(echo "$input" | jq -r '.usage.percent_used // empty')
usage_reset=$(echo "$input" | jq -r '.usage.reset_time // empty')

# Directory display
dir="$cwd"
[[ "$dir" == "$HOME"* ]] && dir="~${dir#$HOME}"
IFS='/' read -ra PARTS <<< "$dir"
[[ ${#PARTS[@]} -gt 4 ]] && dir="${PARTS[0]}/…/${PARTS[-2]}/${PARTS[-1]}"

# OS icon
os="󰌽"
[[ -f /etc/os-release ]] && . /etc/os-release
case "$ID" in
    debian) os="󰣚" ;; ubuntu) os="󰕈" ;; arch) os="󰣇" ;;
esac

user=$(whoami)

# Git status
git_info=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
    [[ -z "$branch" ]] && branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    if [[ -n "$branch" ]]; then
        [[ -n $(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null) ]] && branch+="*"
        git_info="\033[48;2;240;198;116m\033[38;2;222;147;95m\033[38;2;0;0;0m  $branch \033[0m"
    fi
fi

# Output style
style_info=""
if [[ -n "$output_style" && "$output_style" != "null" ]]; then
    if [[ -n "$git_info" ]]; then
        style_info="\033[48;2;75;174;22m\033[38;2;240;198;116m\033[38;2;0;0;0m 󰧮 $output_style \033[0m"
    else
        style_info="\033[48;2;75;174;22m\033[38;2;222;147;95m\033[38;2;0;0;0m 󰧮 $output_style \033[0m"
    fi
fi

# Usage info (5-hour limit)
usage_info=""
if [[ -n "$usage_pct" && "$usage_pct" != "null" ]]; then
    # Color based on usage: green < 50, yellow 50-80, red > 80
    if float_lt "$usage_pct" 50; then
        usage_bg="75;174;22"  # green
    elif float_lt "$usage_pct" 80; then
        usage_bg="240;198;116"  # yellow
    else
        usage_bg="242;90;85"  # red
    fi
    
    # Determine previous segment color for transition
    if [[ -n "$style_info" ]]; then
        prev_color="75;174;22"
    elif [[ -n "$git_info" ]]; then
        prev_color="240;198;116"
    else
        prev_color="222;147;95"
    fi
    
    usage_info="\033[48;2;${usage_bg}m\033[38;2;${prev_color}m\033[38;2;0;0;0m 󱑆 ${usage_pct}% \033[0m"
fi

# Model info - determine previous color for transition
if [[ -n "$usage_info" ]]; then
    if float_lt "$usage_pct" 50; then
        model_prev="75;174;22"
    elif float_lt "$usage_pct" 80; then
        model_prev="240;198;116"
    else
        model_prev="242;90;85"
    fi
elif [[ -n "$style_info" ]]; then
    model_prev="75;174;22"
elif [[ -n "$git_info" ]]; then
    model_prev="240;198;116"
else
    model_prev="222;147;95"
fi

# Build prompt with powerline transitions
printf '\033[48;2;242;90;85m\033[38;2;0;0;0m %s %s \033[0m' "$os" "$user"
printf '\033[48;2;222;147;95m\033[38;2;242;90;85m\033[38;2;0;0;0m %s \033[0m' "$dir"

[[ -n "$git_info" ]] && printf "$git_info"
[[ -n "$style_info" ]] && printf "$style_info"
[[ -n "$usage_info" ]] && printf "$usage_info"

printf '\033[48;2;50;153;204m\033[38;2;%sm\033[38;2;0;0;0m %s \033[0m' "$model_prev" "$model"
printf '\033[38;2;50;153;204m\033[0m'
