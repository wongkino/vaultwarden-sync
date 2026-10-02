#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
. /app/i18n.sh

# Default TZ: Asia/Hong_Kong (override with TZ). Non-root: TZ only, no /etc/localtime.
# 預設香港時間，可用 TZ 覆寫（非 root 僅依賴 TZ，不改 /etc/localtime）
TZ="${TZ:-Asia/Hong_Kong}"
export TZ

# Normalize and rewrite LANG=en|zh (default en when unset)
# 正規化並回寫 LANG=en|zh（未設定時預設 en）
LANG="$UI_LANG"
export LANG

echo "$(t tz_info "$TZ" "$(date '+%Y-%m-%d %H:%M:%S %Z')")"
echo "$(t lang_info "$LANG")"
echo "$(t first_sync)"
if ! /app/sync.sh; then
  echo "$(t first_sync_fail)" >&2
fi

echo "$(t cron_start "$TZ")"
# supercronic inherits Docker env; no /etc/environment needed
# supercronic 繼承 Docker 環境變數，無需再寫 /etc/environment
exec supercronic /app/crontab
