#!/usr/bin/env bash
# Returns a status indicator for a Claude Code pane.
# Usage: claude-status.sh <pane_id>
#
# Indicators:
#   ● — Claude is working
#   ! — Claude needs permission approval
#   ? — Claude is waiting for input
#   ○ — Claude is idle
#   (empty) — Not a Claude pane

set -e

pane_id="$1"
[[ -z "$pane_id" ]] && exit 0

content=$(tmux capture-pane -t "$pane_id" -p 2>/dev/null) || exit 0

# Strip empty lines, take last 25 for detection
filtered=$(echo "$content" | grep -v '^$' | tail -25)

# Not a Claude pane if no prompt character
if ! echo "$filtered" | grep -q '❯'; then
    exit 0
fi

# Check for fresh input field: ❯ with ─ border directly above it.
# Collect lines above the border — spinners may be pushed up by subtask lists.
has_input_field=false
above_border=()
prev_lines=()
prev_line=""
while IFS= read -r line; do
    if [[ "$line" == *'❯'* && "$prev_line" == *'─'* ]]; then
        has_input_field=true
        above_border=("${prev_lines[@]}")
        break
    fi
    prev_lines+=("$prev_line")
    prev_line="$line"
done <<< "$filtered"

# Fresh input field takes priority — stale prompts in scrollback are irrelevant
if $has_input_field; then
    # Scan lines above the border for working indicators. Limited to the captured
    # window (not the full pane) to avoid false positives from prose content.
    working=false
    for ab_line in "${above_border[@]}"; do
        if [[ "$ab_line" == *'ctrl+c to interrupt'* ]]; then
            working=true
            break
        elif [[ "$ab_line" =~ [^[:space:]]\ [^[:space:]]+… ]]; then
            working=true
            break
        fi
    done
    if $working; then
        echo "●"
    else
        echo "○"
    fi
# No input field — check for active prompts
# Permission approval prompt (tool wants to run something)
elif echo "$filtered" | grep -qF 'Do you want to proceed?'; then
    echo "!"
elif echo "$filtered" | grep -qF 'Esc to cancel'; then
    echo "?"
elif echo "$filtered" | grep -qF 'Enter to select'; then
    echo "?"
elif echo "$filtered" | grep -qE '\[(y/n|Y/n)\]'; then
    echo "?"
fi
