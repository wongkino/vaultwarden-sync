#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
. /app/i18n.sh

echo "$(t step_env)"

require_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "$(t missing_env "$name")" >&2
    exit 1
  fi
}

notify_apprise() {
  local title="$1"
  local body="$2"
  local type="${3:-info}"

  if [ -z "${APPRISE_URL:-}" ]; then
    echo "$(t apprise_skip)"
    return 0
  fi

  echo "$(t apprise_sending "$type")"
  if ! curl -fsSg -X POST \
    --data-urlencode "title=${title}" \
    --data-urlencode "body=${body}" \
    --data-urlencode "type=${type}" \
    -- "$APPRISE_URL"; then
    echo "$(t apprise_failed)" >&2
  fi
  echo
}

SRC_URL="${SRC_URL:-https://vault-src.example.com}"
DEST_URL="${DEST_URL:-https://vault-dest.example.com}"
EXPORT_FILE="/tmp/vault_encrypted.json"
OLD_ITEM_IDS_FILE="/tmp/vw_old_item_ids.json"
OLD_FOLDER_IDS_FILE="/tmp/vw_old_folder_ids.json"
SRC_META_FILE="/tmp/vw_src_meta.json"
DEST_OLD_META_FILE="/tmp/vw_dest_old_meta.json"
SRC_APPDATA="/tmp/bw-src"
DEST_APPDATA="/tmp/bw-dest"
SYNC_RESULT="failure"
SYNC_DETAIL="$(t detail_early_end)"

export BW_NOINTERACTION=1
mkdir -p "$SRC_APPDATA" "$DEST_APPDATA"

bw_src() {
  BITWARDENCLI_APPDATA_DIR="$SRC_APPDATA" bw "$@"
}

bw_dest() {
  BITWARDENCLI_APPDATA_DIR="$DEST_APPDATA" bw "$@"
}

# Reduce bw list items JSON to [{name, fp}, ...]
# 將 bw list items 轉成 [{name, fp}, ...]
# Content fingerprint only (no revisionDate — import always rewrites it on dest).
# 僅比對內容指紋（不含 revisionDate：匯入會重寫目的地時間戳）
items_to_meta() {
  jq -c '[.[] | {
    name: (.name // "(unnamed)"),
    fp: ([
      (.type // 0 | tostring),
      (.login.username // ""),
      (.login.password // ""),
      ((.login.uris // []) | map(.uri // "") | sort | join("|")),
      (.notes // ""),
      (.card.brand // ""),
      (.card.cardholderName // ""),
      (.card.number // ""),
      (.identity.firstName // ""),
      (.identity.lastName // "")
    ] | join("\t"))
  }]'
}

# Compare source vs old destination meta → added / removed / changed.
# 比對來源與舊目的地 meta → 新增／刪除／變更
build_change_summary() {
  local src_file="$1"
  local dest_file="$2"

  jq -nr --slurpfile src "$src_file" --slurpfile dest "$dest_file" '
    def index_by_name:
      (.[0] // [])
      | group_by(.name)
      | map({key: .[0].name, value: (map(.fp) | unique | join("||"))})
      | from_entries;

    ($src | index_by_name) as $sm
    | ($dest | index_by_name) as $dm
    | ($sm | keys) as $sk
    | ($dm | keys) as $dk
    | ($sk - $dk) as $added
    | ($dk - $sk) as $removed
    | ($sk - ($sk - $dk)) as $common
    | ($common | map(select($sm[.] != $dm[.])) | sort) as $changed
    | ($common | map(select($sm[.] == $dm[.])) | sort) as $unchanged
    | {
        added_count: ($added | length),
        removed_count: ($removed | length),
        changed_count: ($changed | length),
        unchanged_count: ($unchanged | length),
        added_sample: ($added | sort | join(", ")),
        removed_sample: ($removed | sort | join(", ")),
        changed_sample: ($changed | join(", "))
      }
    | @json
  '
}

cleanup() {
  local exit_code=$?

  echo "$(t cleanup)"
  rm -f "$EXPORT_FILE" "$OLD_ITEM_IDS_FILE" "$OLD_FOLDER_IDS_FILE" \
    "$SRC_META_FILE" "$DEST_OLD_META_FILE"
  bw_src logout 2>/dev/null || true
  bw_dest logout 2>/dev/null || true

  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  if [ "$SYNC_RESULT" = "success" ]; then
    notify_apprise \
      "$(t notify_ok_title)" \
      "$(t notify_ok_body "$ts" "$SYNC_DETAIL")" \
      "success"
  else
    notify_apprise \
      "$(t notify_fail_title)" \
      "$(t notify_fail_body "$ts" "$SYNC_DETAIL" "$exit_code")" \
      "failure"
  fi

  return "$exit_code"
}
trap cleanup EXIT

require_var SRC_CLIENTID
require_var SRC_CLIENTSECRET
require_var SRC_PASSWORD
require_var DEST_CLIENTID
require_var DEST_CLIENTSECRET
require_var DEST_PASSWORD

EXPORT_PASSWORD="${EXPORT_PASSWORD:-$SRC_PASSWORD}"

echo "$(t step_export)"
bw_src config server "$SRC_URL"
BW_CLIENTID="$SRC_CLIENTID" BW_CLIENTSECRET="$SRC_CLIENTSECRET" bw_src login --apikey
SRC_SESSION=$(bw_src unlock --passwordenv SRC_PASSWORD --raw)
bw_src sync --session "$SRC_SESSION" >/dev/null

bw_src list items --session "$SRC_SESSION" > /tmp/vw_src_items.json
items_to_meta < /tmp/vw_src_items.json > "$SRC_META_FILE"
SRC_COUNT=$(jq 'length' /tmp/vw_src_items.json)
rm -f /tmp/vw_src_items.json

bw_src export \
  --format encrypted_json \
  --password "$EXPORT_PASSWORD" \
  --output "$EXPORT_FILE" \
  --session "$SRC_SESSION"

if [ ! -s "$EXPORT_FILE" ]; then
  SYNC_DETAIL="$(t export_empty)"
  echo "$SYNC_DETAIL" >&2
  exit 1
fi

echo "$(t export_ok "$SRC_COUNT")"

echo "$(t step_dest_login)"
bw_dest config server "$DEST_URL"
BW_CLIENTID="$DEST_CLIENTID" BW_CLIENTSECRET="$DEST_CLIENTSECRET" bw_dest login --apikey
DEST_SESSION=$(bw_dest unlock --passwordenv DEST_PASSWORD --raw)
bw_dest sync --session "$DEST_SESSION" >/dev/null

echo "$(t step_snapshot)"
bw_dest list items --session "$DEST_SESSION" > /tmp/vw_dest_items.json
jq -c '[.[].id]' /tmp/vw_dest_items.json > "$OLD_ITEM_IDS_FILE"
items_to_meta < /tmp/vw_dest_items.json > "$DEST_OLD_META_FILE"
rm -f /tmp/vw_dest_items.json
bw_dest list folders --session "$DEST_SESSION" | jq -c '[.[] | select(.id != null) | .id]' > "$OLD_FOLDER_IDS_FILE"
OLD_COUNT=$(jq 'length' "$OLD_ITEM_IDS_FILE")
echo "$(t snapshot_done "$OLD_COUNT")"

echo "$(t step_import)"
export BW_EXPORT_PASSWORD="$EXPORT_PASSWORD"
bw_dest import bitwardenpasswordprotected "$EXPORT_FILE" \
  --passwordenv BW_EXPORT_PASSWORD \
  --session "$DEST_SESSION"

bw_dest sync --force --session "$DEST_SESSION" >/dev/null
AFTER_IMPORT_COUNT=$(bw_dest list items --session "$DEST_SESSION" | jq 'length')
EXPECTED_COUNT=$((OLD_COUNT + SRC_COUNT))

if [ "$AFTER_IMPORT_COUNT" -ne "$EXPECTED_COUNT" ]; then
  SYNC_DETAIL="$(t import_verify_fail "$AFTER_IMPORT_COUNT" "$EXPECTED_COUNT" "$OLD_COUNT" "$SRC_COUNT")"
  echo "$SYNC_DETAIL" >&2
  exit 1
fi
echo "$(t import_verify_ok "$AFTER_IMPORT_COUNT")"

echo "$(t step_delete_old)"
BW_APPDATA_DIR="$DEST_APPDATA" \
  SERVER_URL="$DEST_URL" \
  IDS_FILE="$OLD_ITEM_IDS_FILE" \
  node /app/delete-ciphers.js

while IFS= read -r folder_id; do
  [ -z "$folder_id" ] && continue
  bw_dest delete folder "$folder_id" --session "$DEST_SESSION" >/dev/null || true
done < <(jq -r '.[]' "$OLD_FOLDER_IDS_FILE")

bw_dest sync --force --session "$DEST_SESSION" >/dev/null
FINAL_COUNT=$(bw_dest list items --session "$DEST_SESSION" | jq 'length')
if [ "$FINAL_COUNT" -ne "$SRC_COUNT" ]; then
  SYNC_DETAIL="$(t final_verify_fail "$FINAL_COUNT" "$SRC_COUNT")"
  echo "$SYNC_DETAIL" >&2
  exit 1
fi
echo "$(t final_verify_ok "$FINAL_COUNT")"

CHANGE_JSON="$(build_change_summary "$SRC_META_FILE" "$DEST_OLD_META_FILE")"
ADDED_COUNT=$(jq -r '.added_count' <<<"$CHANGE_JSON")
REMOVED_COUNT=$(jq -r '.removed_count' <<<"$CHANGE_JSON")
CHANGED_COUNT=$(jq -r '.changed_count' <<<"$CHANGE_JSON")
UNCHANGED_COUNT=$(jq -r '.unchanged_count' <<<"$CHANGE_JSON")
ADDED_SAMPLE=$(jq -r '.added_sample' <<<"$CHANGE_JSON")
REMOVED_SAMPLE=$(jq -r '.removed_sample' <<<"$CHANGE_JSON")
CHANGED_SAMPLE=$(jq -r '.changed_sample' <<<"$CHANGE_JSON")

NET_CHANGE=$((FINAL_COUNT - OLD_COUNT))
if [ "$NET_CHANGE" -gt 0 ]; then
  NET_TXT="+$NET_CHANGE"
else
  NET_TXT="$NET_CHANGE"
fi

ADDED_LIST_TXT=""
REMOVED_LIST_TXT=""
CHANGED_LIST_TXT=""
if [ "$ADDED_COUNT" -gt 0 ]; then
  ADDED_LIST_TXT="$(t change_sample_added "$ADDED_SAMPLE")"$'\n'
fi
if [ "$REMOVED_COUNT" -gt 0 ]; then
  REMOVED_LIST_TXT="$(t change_sample_removed "$REMOVED_SAMPLE")"$'\n'
fi
if [ "$CHANGED_COUNT" -gt 0 ]; then
  CHANGED_LIST_TXT="$(t change_sample_changed "$CHANGED_SAMPLE")"$'\n'
fi

echo "$(t step_done)"
echo "$(t sync_ok)"
SYNC_RESULT="success"
SYNC_DETAIL="$(t detail_ok_changes \
  "$SRC_URL" "$DEST_URL" \
  "$OLD_COUNT" "$FINAL_COUNT" "$NET_TXT" \
  "$ADDED_COUNT" "$REMOVED_COUNT" "$CHANGED_COUNT" "$UNCHANGED_COUNT" \
  "$ADDED_LIST_TXT" "$REMOVED_LIST_TXT" "$CHANGED_LIST_TXT")"
