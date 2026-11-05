#!/usr/bin/env bash
# Keep only the NEWEST robot_state_publisher; kill the stale ones.
echo "before:"
ps -eo pid,etimes,cmd | grep "[r]obot_state_publisher" | awk '{printf "  pid=%s uptime=%ss\n", $1, $2}'

ps -eo pid,etimes,cmd | grep "[r]obot_state_publisher" \
  | sort -k2 -n | tail -n +2 | awk '{print $1}' | while read -r p; do
      echo "  killing stale pid=$p"
      kill -9 "$p" 2>/dev/null
    done
sleep 3

echo "after:"
ps -eo pid,etimes,cmd | grep "[r]obot_state_publisher" | awk '{printf "  pid=%s uptime=%ss\n", $1, $2}'
