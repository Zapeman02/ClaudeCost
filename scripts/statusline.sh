#!/bin/zsh
# Claude Code status line. Saves the plan's rate limits for ClaudeCost and prints a short usage line.
# Claude Code runs this in the background with session JSON on stdin; it never opens a window.
input=$(cat)
limits=$(print -r -- "$input" | jq -c '.rate_limits // empty | {five_hour, seven_day}' 2>/dev/null)

if [[ -n "$limits" ]]; then
    file="$HOME/.claude/claudecost-limits.json"
    print -r -- "$limits" > "$file.tmp" && mv "$file.tmp" "$file"
fi

print -r -- "$input" | jq -r '
    [ (.rate_limits.five_hour.used_percentage // empty | "5h \(round)%"),
      (.rate_limits.seven_day.used_percentage // empty | "week \(round)%") ] | join(" · ")
' 2>/dev/null
