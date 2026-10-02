# Changelog / 更新日誌

All notable changes to this project are documented here.
本專案的重要變更都會記錄在此。

Format / 格式: based on [Keep a Changelog](https://keepachangelog.com/).
Versioning / 版本: [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`).
Automation / 自動化: every push to `main` bumps the patch version, prepends release notes from commits since the previous tag, then builds & pushes the `linux/amd64` image to GHCR.
每次推送到 `main` 會自動遞增 patch、依提交紀錄寫入更新詳情，並建置推送 `linux/amd64` 映像至 GHCR。

## [1.0.0] - 2026-10-02

### Added / 新增

- Vaultwarden → Vaultwarden daily sync via password-protected encrypted JSON
  Vaultwarden → Vaultwarden 每日同步（密碼保護加密 JSON）
- Safer replace flow: import + verify, then delete old items (keep old data if import fails)
  較安全的取代流程：先匯入並驗證，再刪舊（匯入失敗則保留舊資料）
- Non-root container (`node` uid 1000) with supercronic scheduler (daily 03:00)
  非 root 容器 + supercronic 排程（每日 03:00）
- Bilingual logs & Apprise notifications (`LANG=en|zh`, default English)
  中英日誌與 Apprise 通知（`LANG=en|zh`，預設英文）
- Change summary in notifications: added / removed / changed / unchanged
  通知內變更摘要：新增／刪除／變更／不變
- Configurable `TZ`, `APPRISE_URL`, pinned Bitwarden CLI `2026.7.0`
  可設定 `TZ`、`APPRISE_URL`，釘住 Bitwarden CLI `2026.7.0`
- GHCR publish workflow for `linux/amd64`
  GHCR 發布流程（`linux/amd64`）
- MIT License
