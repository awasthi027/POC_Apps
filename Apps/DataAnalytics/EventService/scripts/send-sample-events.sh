#!/bin/bash
# Sends sample events to the service, in the same format the SDK uses, so the chart page has data.
# Usage: ./scripts/send-sample-events.sh [count] [url]
set -euo pipefail
COUNT="${1:-200}"
URL="${2:-http://localhost:8080/v1/analytics/events}"
NAMES=(app_opened screen_viewed product_viewed add_to_cart purchase search)
NOW=$(date +%s)

events=""
for ((i = 0; i < COUNT; i++)); do
  name="${NAMES[$((RANDOM % ${#NAMES[@]}))]}"
  seconds_ago=$((RANDOM % 86400))                                  # spread over the last 24 hours
  ts=$(date -u -r $((NOW - seconds_ago)) +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$((NOW - seconds_ago))" +%Y-%m-%dT%H:%M:%SZ)
  user=$((RANDOM % 20))
  id="sample-$NOW-$i"                                              # a fixed id: sending twice does not duplicate
  [ -n "$events" ] && events+=","
  events+="{\"event_id\":\"$id\",\"event_name\":\"$name\",\"timestamp\":\"$ts\",\"session_id\":\"s-$user\",\"anonymous_id\":\"anon-$user\",\"user_id\":\"user-$user\",\"properties\":{\"source\":\"sample\"},\"schema_version\":1}"
done

curl -sS -X POST "$URL" -H 'Content-Type: application/json' \
  -d "{\"project_id\":\"demo\",\"batch_id\":\"sample-$NOW\",\"events\":[${events}]}" | head -c 300
echo
