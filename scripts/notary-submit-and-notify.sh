#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  notary-submit-and-notify.sh <file> [profile] [title] [staple_target]
  notary-submit-and-notify.sh --watch <submission_id> <profile> <title> [staple_target]
EOF
}

notify() {
  local title="$1"
  local message="$2"
  osascript -e "display notification \"${message//\"/\\\"}\" with title \"${title//\"/\\\"}\"" >/dev/null 2>&1 || true
}

json_field() {
  local key="$1"
  /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get(sys.argv[1], ""))' "$key"
}

watch_submission() {
  local submission_id="$1"
  local profile="$2"
  local title="$3"
  local staple_target="${4:-}"

  while true; do
    local info_json
    info_json="$(xcrun notarytool info "$submission_id" --keychain-profile "$profile" --output-format json)"
    local status
    status="$(printf '%s' "$info_json" | json_field status)"

    case "$status" in
      Accepted)
        if [ -n "$staple_target" ] && [ -e "$staple_target" ]; then
          if xcrun stapler staple "$staple_target" >/dev/null 2>&1; then
            xcrun stapler validate "$staple_target" >/dev/null 2>&1 || true
            notify "$title" "Accepted and stapled"
            echo "Accepted and stapled: $staple_target"
          else
            notify "$title" "Accepted, but stapling failed"
            echo "Accepted, but stapling failed: $staple_target"
          fi
        else
          notify "$title" "Accepted"
          echo "Accepted"
        fi
        break
        ;;
      Invalid|Rejected)
        local log_path
        log_path="/tmp/notary-${submission_id}.log.json"
        xcrun notarytool log "$submission_id" --keychain-profile "$profile" >"$log_path" 2>/dev/null || true
        notify "$title" "Failed: ${status}"
        echo "Failed: ${status}. Log: $log_path"
        break
        ;;
      *)
        sleep 30
        ;;
    esac
  done
}

if [ "${1:-}" = "--watch" ]; then
  if [ "$#" -lt 4 ]; then
    usage
    exit 1
  fi
  watch_submission "$2" "$3" "$4" "${5:-}"
  exit 0
fi

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

FILE="$1"
PROFILE="${2:-ez-paste-notary}"
TITLE="${3:-notarytool}"
STAPLE_TARGET="${4:-}"

if [ ! -f "$FILE" ]; then
  echo "Error: file not found: $FILE" >&2
  exit 1
fi

submit_json="$(xcrun notarytool submit "$FILE" --keychain-profile "$PROFILE" --output-format json)"
submission_id="$(printf '%s' "$submit_json" | json_field id)"

if [ -z "$submission_id" ]; then
  echo "Error: could not parse submission ID" >&2
  exit 1
fi

watch_log="/tmp/notary-watch-${submission_id}.log"
nohup "$0" --watch "$submission_id" "$PROFILE" "$TITLE" "$STAPLE_TARGET" >"$watch_log" 2>&1 &
watch_pid=$!

echo "Submitted: $submission_id"
echo "Watcher PID: $watch_pid"
echo "Watcher log: $watch_log"
