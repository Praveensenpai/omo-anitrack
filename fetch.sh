#!/bin/bash
set -euo pipefail

CACHE_DIR="$HOME/.cache/omarchy"
CONFIG_DIR="$HOME/.config/omarchy/anitrack"
mkdir -p "$CACHE_DIR" "$CONFIG_DIR"

OUTPUT_FILE="$CACHE_DIR/anitrack_schedule.json"
PINS_FILE="$CONFIG_DIR/pins.json"

[ ! -f "$PINS_FILE" ] && echo "[]" > "$PINS_FILE"

NOW=$(date +%s)
START_TODAY=$(date -d "today 00:00:00" +%s)
END_TODAY=$(date -d "today 23:59:59" +%s)
END_TOMORROW=$(date -d "tomorrow 23:59:59" +%s)
END_WEEK=$(date -d "+7 days 23:59:59" +%s)

QUERY=$(cat << GRAPHQL
query {
  p1: Page(page: 1, perPage: 50) {
    airingSchedules(airingAt_greater: $START_TODAY, airingAt_lesser: $END_WEEK, sort: TIME) {
      id episode airingAt timeUntilAiring media { id title { romaji english native } coverImage { medium large } siteUrl genres episodes }
    }
  }
  p2: Page(page: 2, perPage: 50) {
    airingSchedules(airingAt_greater: $START_TODAY, airingAt_lesser: $END_WEEK, sort: TIME) {
      id episode airingAt timeUntilAiring media { id title { romaji english native } coverImage { medium large } siteUrl genres episodes }
    }
  }
  p3: Page(page: 3, perPage: 50) {
    airingSchedules(airingAt_greater: $START_TODAY, airingAt_lesser: $END_WEEK, sort: TIME) {
      id episode airingAt timeUntilAiring media { id title { romaji english native } coverImage { medium large } siteUrl genres episodes }
    }
  }
  p4: Page(page: 4, perPage: 50) {
    airingSchedules(airingAt_greater: $START_TODAY, airingAt_lesser: $END_WEEK, sort: TIME) {
      id episode airingAt timeUntilAiring media { id title { romaji english native } coverImage { medium large } siteUrl genres episodes }
    }
  }
}
GRAPHQL
)

PAYLOAD=$(jq -n --arg q "$QUERY" '{query: $q}')

RAW_JSON=$(curl -s --max-time 10 -X POST https://graphql.anilist.co \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" || true)

if [ -z "$RAW_JSON" ] || ! echo "$RAW_JSON" | jq -e '.data.p1.airingSchedules' >/dev/null 2>&1; then
  # If offline or API failure, keep existing cache if available
  if [ -f "$OUTPUT_FILE" ]; then
    exit 0
  fi
  echo '{"shows":[],"todayCount":0,"pinnedTodayCount":0,"nextShow":""}' > "$OUTPUT_FILE"
  exit 0
fi

PINS=$(cat "$PINS_FILE" 2>/dev/null || echo "[]")

PARSED=$(echo "$RAW_JSON" | jq \
  --argjson pins "$PINS" \
  --argjson now "$NOW" \
  --argjson startToday "$START_TODAY" \
  --argjson endToday "$END_TODAY" \
  --argjson endTomorrow "$END_TOMORROW" '
  ([.data.p1.airingSchedules[], .data.p2.airingSchedules[], .data.p3.airingSchedules[], .data.p4.airingSchedules[]] | unique_by(.id))
  | map(
      . as $item
      | ($item.media.id) as $mid
      | ($pins | index($mid) != null) as $isPinned
      | (
          if $item.airingAt <= $endToday then "today"
          elif $item.airingAt <= $endTomorrow then "tomorrow"
          else "this_week" end
        ) as $dayGroup
      | {
          id: $item.id,
          mediaId: $item.media.id,
          title: ($item.media.title.romaji // $item.media.title.english // $item.media.title.native // "Unknown"),
          titleEnglish: ($item.media.title.english // ""),
          titleNative: ($item.media.title.native // ""),
          episode: $item.episode,
          totalEpisodes: ($item.media.episodes // 0),
          airingAt: $item.airingAt,
          coverImage: ($item.media.coverImage.medium // $item.media.coverImage.large // ""),
          siteUrl: ($item.media.siteUrl // "https://anilist.co"),
          genres: (($item.media.genres // [])[0:2]),
          pinned: $isPinned,
          dayGroup: $dayGroup
        }
    )
  | {
      shows: .,
      todayCount: (map(select(.dayGroup == "today")) | length),
      tomorrowCount: (map(select(.dayGroup == "tomorrow")) | length),
      thisWeekCount: (map(select(.dayGroup == "this_week")) | length),
      allCount: length,
      pinnedCount: (map(select(.pinned)) | length),
      pinnedTodayCount: (map(select(.pinned and .dayGroup == "today")) | length),
      nextAiring: (map(select(.airingAt > $now)) | first // null),
      lastUpdated: $now
    }
')

echo "$PARSED" > "$OUTPUT_FILE"
