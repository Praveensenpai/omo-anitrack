#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/omarchy/anitrack"
PINS_FILE="$CONFIG_DIR/pins.json"
CACHE_FILE="$HOME/.cache/omarchy/anitrack_schedule.json"

mkdir -p "$CONFIG_DIR"
[ ! -f "$PINS_FILE" ] && echo "[]" > "$PINS_FILE"

case "${1:-}" in
  open)
    url="${2:-https://anilist.co}"
    xdg-open "$url" >/dev/null 2>&1 &
    ;;
  pin)
    mediaId="${2:-}"
    if [ -n "$mediaId" ]; then
      # Toggle mediaId in pins.json
      jq --argjson mid "$mediaId" '
        if index($mid) != null then
          map(select(. != $mid))
        else
          . + [$mid]
        end
      ' "$PINS_FILE" > "$PINS_FILE.tmp" && mv "$PINS_FILE.tmp" "$PINS_FILE"

      # Also update cache file immediately
      if [ -f "$CACHE_FILE" ]; then
        PINS=$(cat "$PINS_FILE" 2>/dev/null || echo "[]")
        jq --argjson pins "$PINS" '
          .shows |= map(
            . as $item
            | .pinned = ($pins | index($item.mediaId) != null)
          )
          | .pinnedCount = (.shows | map(select(.pinned)) | length)
          | .pinnedTodayCount = (.shows | map(select(.pinned and .dayGroup == "today")) | length)
        ' "$CACHE_FILE" > "$CACHE_FILE.tmp" && mv "$CACHE_FILE.tmp" "$CACHE_FILE"
      fi
    fi
    ;;
  refresh)
    if "$SCRIPT_DIR/fetch.sh"; then
      count=$(jq -r '.allCount // (.shows | length) // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
      notify-send -a "Omo Anitrack" "Anime Schedule Updated" "Loaded $count airing shows from AniList." -t 2500 >/dev/null 2>&1 || true
    fi
    ;;
  *)
    echo "Usage: $0 {open <url>|pin <mediaId>|refresh}"
    exit 1
    ;;
esac
