#!/usr/bin/env bash

input=$(cat)
# Always write latest; append rate_limits if present (so we catch it when it appears)
echo "$input" | jq . > /tmp/statusline-debug.json
echo "$input" | jq -e '.rate_limits' > /tmp/statusline-debug-ratelimits.json 2>/dev/null || true
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')

# Shorten home directory to ~
home="$HOME"
if [[ "$cwd" == "$home"* ]]; then
  cwd="~${cwd#$home}"
fi

# Git info — panda-themed
git_info=""
git_panda=""
if command -v git &>/dev/null && [[ "$SKIP_GIT_PROMPT" != "true" ]]; then
  actual_cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
  ref=$(env LANG=C git -C "$actual_cwd" symbolic-ref --short HEAD 2>/dev/null)
  if [[ -z "$ref" ]]; then
    ref=$(env LANG=C git -C "$actual_cwd" describe --tags --always 2>/dev/null)
  fi

  if [[ -n "$ref" ]]; then
    marks=""
    dirty=false
    first_line=true
    while IFS= read -r line; do
      if [[ $line == \#\#* ]]; then
        if [[ $line =~ ahead\ ([0-9]+) ]]; then
          marks+=" ${BASH_REMATCH[1]}🐾↑"
        fi
        if [[ $line =~ behind\ ([0-9]+) ]]; then
          marks+=" ${BASH_REMATCH[1]}🐾↓"
        fi
      elif [[ "$first_line" != "true" ]]; then
        dirty=true
        break
      fi
      first_line=false
    done < <(env LANG=C git -C "$actual_cwd" status --porcelain --branch 2>/dev/null)

    # Dirty/clean repo panda
    if $dirty; then
      git_panda="🐼💢"
    else
      git_panda="🐼🧹"
    fi

    git_info=" ⑂${ref}${marks}"
  fi
fi

# Model and context
model=$(echo "$input" | jq -r '.model.display_name // "—"')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | xargs printf '%.0f')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
# Current usage = input + output + cache tokens
ctx_used=$(echo "$input" | jq -r '
  .context_window.current_usage |
  ((.input_tokens // 0) + (.output_tokens // 0) +
   (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))
')
# Format as Xk
ctx_used_k=$(echo "$ctx_used" | awk '{printf "%.0fk", $1/1000}')
ctx_size_k=$(echo "$ctx_size" | awk '{printf "%.0fk", $1/1000}')

cost_raw=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
cost=$(printf '$%.2f' "$cost_raw")

# Rate limits with reset countdowns
now=$(date +%s)
rl_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl_5h_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
rl_7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
rl_7d_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Format seconds remaining as Xh:Ym
fmt_countdown() {
  local secs=$1
  if (( secs <= 0 )); then echo "now"; return; fi
  local h=$(( secs / 3600 ))
  local m=$(( (secs % 3600) / 60 ))
  printf '%dh:%02dm' "$h" "$m"
}

# ANSI colors
blue=$'\033[34m'
cyan=$'\033[36m'
green=$'\033[38;5;28m'
yellow=$'\033[33m'
red=$'\033[31m'
orange=$'\033[38;5;208m'
cost_blue=$'\033[38;5;74m'
dim=$'\033[2m'
reset=$'\033[0m'

# Panda bamboo bar — panda walks along eating bamboo
bar_width=20
filled=$(( ctx_pct * bar_width / 100 ))
empty=$(( bar_width - filled ))
eaten=$(printf '%*s' "$filled" '' | tr ' ' '╌')
bamboo=$(printf '%*s' "$empty" '' | tr ' ' '│')
bar="${dim}${eaten}${reset}🐼${green}${bamboo}${reset}"

# 5h rate limit — bamboo snack segments + color-coded percentage
rl_5h_pct=""
rl_5h_bar=""
rl_5h_reset=""
if [[ -n "$rl_5h" ]]; then
  rl_5h=$(printf '%.0f' "$rl_5h")
  # Color for the percentage number
  if (( rl_5h >= 90 )); then
    rl_pct_color=$red
  elif (( rl_5h >= 80 )); then
    rl_pct_color=$orange
  elif (( rl_5h >= 60 )); then
    rl_pct_color=$yellow
  else
    rl_pct_color=$reset
  fi
  rl_5h_pct="${rl_pct_color}${rl_5h}%${reset}"

  # Bamboo snack segments (10 wide) — remaining segments in green, eaten in dim
  snack_width=10
  snack_used=$(( rl_5h * snack_width / 100 ))
  snack_left=$(( snack_width - snack_used ))
  snack_eaten=""
  for ((i=0; i<snack_used; i++)); do snack_eaten+="▱ "; done
  snack_remaining=""
  for ((i=0; i<snack_left; i++)); do snack_remaining+="▰ "; done
  rl_5h_bar="${dim}${snack_eaten}${reset}🐼${green}${snack_remaining}${reset}"

  # Reset countdown
  if [[ -n "$rl_5h_resets" ]]; then
    remaining=$(( rl_5h_resets - now ))
    rl_5h_reset=" ${dim}(resets $(fmt_countdown $remaining))${reset}"
  fi
fi

# Line 1: location + git + dirty/clean panda
echo "🐾 ${blue}${cwd}${reset}${cyan}${git_info}${reset} ${git_panda}"
# Context percentage color
if (( ctx_pct >= 90 )); then
  ctx_pct_color=$red
elif (( ctx_pct >= 80 )); then
  ctx_pct_color=$orange
elif (( ctx_pct >= 60 )); then
  ctx_pct_color=$yellow
else
  ctx_pct_color=$reset
fi
# Line 2: context panda — bamboo forest
echo "   ${dim}${eaten}${reset}🐼${green}${bamboo}${reset} ${ctx_pct_color}${ctx_pct}%${reset} ${dim}(${ctx_used_k}/${ctx_size_k})${reset}"
# Line 3: snack panda — rate limit + cost
if [[ -n "$rl_5h_pct" ]]; then
  echo "   ${rl_5h_bar} ${rl_5h_pct} ◦ ${dim}resets $(fmt_countdown $remaining)${reset} ◦ ${cost_blue}${cost}${reset}"
fi
