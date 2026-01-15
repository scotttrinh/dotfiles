#!/usr/bin/env bash
input=$(cat)

# Extract values using jq
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
ctx_total=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Context usage requires summing multiple fields (includes cache tokens)
ctx_used=$(echo "$input" | jq '
  .context_window.current_usage //  { input_tokens: 0, cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }
  | .input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens
')

# Colors
green="\033[32m"
yellow="\033[33m"
red="\033[31m"
reset="\033[0m"

# Context formatting + smart zone color
ctx_used_k=$((ctx_used / 1000))
ctx_total_k=$((ctx_total / 1000))
if [ "$ctx_used" -le 30000 ]; then
  ctx_color="$green"
elif [ "$ctx_used" -le 100000 ]; then
  ctx_color="$yellow"
else
  ctx_color="$red"
fi

# Token formatting (show exact amount if < 1k)
if [ "$total_in" -lt 1000 ]; then
  in_str="$total_in"
else
  in_str="$((total_in / 1000))k"
fi
if [ "$total_out" -lt 1000 ]; then
  out_str="$total_out"
else
  out_str="$((total_out / 1000))k"
fi

# Lines diff
diff=$((added - removed))
[ "$diff" -ge 0 ] && diff_str="+$diff" || diff_str="$diff"

printf "%s | ${ctx_color}%sk${reset}/%sk | %s↓ %s↑ \$%.3f | ${green}+%s${reset} ${red}-%s${reset} (%s)" \
  "$model" "$ctx_used_k" "$ctx_total_k" "$in_str" "$out_str" "$cost" "$added" "$removed" "$diff_str"
