#!/bin/bash
# Shared i18n helpers. LANG=en|zh (default: en when unset/empty)
# 共用多語訊息。LANG=en|zh（未設定時預設英文）

normalize_lang() {
  # Explicit Chinese only; everything else (empty, en, C.UTF-8, …) → English
  # 僅明確指定中文時用 zh；其餘（空值、en、系統 locale 等）→ 英文
  case "${1:-}" in
    zh|ZH|zh_*|zh-*|chinese|Chinese|中文) printf '%s' "zh" ;;
    *) printf '%s' "en" ;;
  esac
}

UI_LANG="$(normalize_lang "${LANG:-}")"
export UI_LANG

# Usage: t KEY [printf_args...]
t() {
  local key="$1"
  shift || true
  local template=""

  case "${UI_LANG}:${key}" in
    # --- sync.sh ---
    zh:step_env) template='=== [1/6] 檢查與設定環境變數 ===' ;;
    en:step_env) template='=== [1/6] Checking environment variables ===' ;;

    zh:missing_env) template='缺少必要環境變數: %s' ;;
    en:missing_env) template='Missing required environment variable: %s' ;;

    zh:apprise_skip) template='APPRISE_URL 未設定，略過通知' ;;
    en:apprise_skip) template='APPRISE_URL is not set; skipping notification' ;;

    zh:apprise_sending) template='=== 發送 Apprise 通知 (%s) ===' ;;
    en:apprise_sending) template='=== Sending Apprise notification (%s) ===' ;;

    zh:apprise_failed) template='⚠️ Apprise 通知發送失敗' ;;
    en:apprise_failed) template='⚠️ Failed to send Apprise notification' ;;

    zh:cleanup) template='=== [清理] 刪除暫存檔與登出 ===' ;;
    en:cleanup) template='=== [Cleanup] Removing temp files and logging out ===' ;;

    zh:notify_ok_title) template='Vaultwarden Sync 成功' ;;
    en:notify_ok_title) template='Vaultwarden Sync succeeded' ;;

    zh:notify_fail_title) template='Vaultwarden Sync 失敗' ;;
    en:notify_fail_title) template='Vaultwarden Sync failed' ;;

    zh:notify_fail_body) template='[%s] %s (exit=%s)' ;;
    en:notify_fail_body) template='[%s] %s (exit=%s)' ;;

    zh:notify_ok_body) template='[%s] %s' ;;
    en:notify_ok_body) template='[%s] %s' ;;

    zh:detail_early_end) template='同步在完成前結束' ;;
    en:detail_early_end) template='Sync ended before completion' ;;

    zh:step_export) template='=== [2/6] 從來源 Vaultwarden 導出（密碼保護加密 JSON）===' ;;
    en:step_export) template='=== [2/6] Exporting from source Vaultwarden (password-protected encrypted JSON) ===' ;;

    zh:export_empty) template='導出檔案不存在或為空，已中止同步' ;;
    en:export_empty) template='Export file missing or empty; aborting sync' ;;

    zh:export_ok) template='來源導出成功（%s 個項目）' ;;
    en:export_ok) template='Source export succeeded (%s item(s))' ;;

    zh:step_dest_login) template='=== [3/6] 登入目的地 Vaultwarden ===' ;;
    en:step_dest_login) template='=== [3/6] Logging in to destination Vaultwarden ===' ;;

    zh:step_snapshot) template='快照目的地既有項目 ID（匯入失敗時不會刪除舊資料）...' ;;
    en:step_snapshot) template='Snapshotting existing destination item IDs (old data kept if import fails)...' ;;

    zh:snapshot_done) template='已記錄 %s 個舊項目' ;;
    en:snapshot_done) template='Recorded %s existing item(s)' ;;

    zh:step_import) template='=== [4/6] 匯入加密資料到目的地（先匯入、後刪舊）===' ;;
    en:step_import) template='=== [4/6] Importing into destination (import first, delete old later) ===' ;;

    zh:import_verify_fail) template='匯入驗證失敗：目前 %s 項，預期 %s 項（舊 %s + 新 %s）。已保留舊資料並中止刪除。' ;;
    en:import_verify_fail) template='Import verification failed: have %s item(s), expected %s (old %s + new %s). Keeping old data; skip delete.' ;;

    zh:import_verify_ok) template='匯入驗證通過（目前共 %s 項）' ;;
    en:import_verify_ok) template='Import verified (%s item(s) present)' ;;

    zh:step_delete_old) template='=== [5/6] 刪除匯入前的舊項目 ===' ;;
    en:step_delete_old) template='=== [5/6] Deleting pre-import (old) items ===' ;;

    zh:final_verify_fail) template='最終驗證失敗：目的地 %s 項，來源 %s 項' ;;
    en:final_verify_fail) template='Final verification failed: destination has %s item(s), source has %s' ;;

    zh:final_verify_ok) template='最終驗證通過（目的地 %s 項）' ;;
    en:final_verify_ok) template='Final verification passed (destination %s item(s))' ;;

    zh:step_done) template='=== [6/6] 完成 ===' ;;
    en:step_done) template='=== [6/6] Done ===' ;;

    zh:sync_ok) template='每日同步成功結束！（僅同步個人密碼庫項目，不含附件與組織資料）' ;;
    en:sync_ok) template='Daily sync completed successfully! (personal vault items only; attachments and organization data excluded)' ;;

    zh:detail_ok_changes) template='已同步：%s → %s
目的地項目：%s → %s（淨變動 %s）
比對結果：新增 %s、刪除 %s、變更 %s、不變 %s
%s%s%s' ;;
    en:detail_ok_changes) template='Synced: %s → %s
Destination items: %s → %s (net %s)
Diff: added %s, removed %s, changed %s, unchanged %s
%s%s%s' ;;

    zh:change_sample_added) template='新增：%s' ;;
    en:change_sample_added) template='Added: %s' ;;

    zh:change_sample_removed) template='刪除：%s' ;;
    en:change_sample_removed) template='Removed: %s' ;;

    zh:change_sample_changed) template='變更：%s' ;;
    en:change_sample_changed) template='Changed: %s' ;;

    # --- entrypoint.sh ---
    zh:tz_info) template='=== 容器時區: %s (%s) ===' ;;
    en:tz_info) template='=== Container timezone: %s (%s) ===' ;;

    zh:lang_info) template='=== 介面語言: %s ===' ;;
    en:lang_info) template='=== UI language: %s ===' ;;

    zh:first_sync) template='=== 容器啟動：即時執行首次同步 ===' ;;
    en:first_sync) template='=== Container start: running initial sync now ===' ;;

    zh:first_sync_fail) template='⚠️ 首次同步失敗，請檢查 API Key、密碼與伺服器網址設定' ;;
    en:first_sync_fail) template='⚠️ Initial sync failed; check API keys, passwords, and server URLs' ;;

    zh:cron_start) template='=== 啟動排程 (每日 %s 03:00，非 root / supercronic) ===' ;;
    en:cron_start) template='=== Starting scheduler (daily 03:00 %s, non-root / supercronic) ===' ;;

    *) template="[${key}]" ;;
  esac

  # shellcheck disable=SC2059
  printf "${template}\n" "$@"
}
