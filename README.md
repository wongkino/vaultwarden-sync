# Vaultwarden → Vaultwarden auto-sync
# Vaultwarden → Vaultwarden 自動同步

Daily sync of a **personal** Vaultwarden vault to another Vaultwarden server (e.g. off-site backup) via password-protected encrypted JSON.
每日以來源 Vaultwarden **個人密碼庫**，透過密碼保護的加密 JSON，同步到另一台 Vaultwarden（例如異地備份帳號）。

Uses the official Bitwarden CLI (Vaultwarden is API-compatible).
底層使用官方 Bitwarden CLI（Vaultwarden 相容其 API）。

License / 授權：[MIT License](LICENSE) · Version / 版本：見 [`VERSION`](VERSION) 與 [`CHANGELOG.md`](CHANGELOG.md)

## Versioning / 版本機制

- Current / 目前：`v1.0.0`
- Every push to `main` automatically：bump patch (`1.0.0` → `1.0.1` …)、prepend commit subjects into `CHANGELOG.md`、create tag `vX.Y.Z`、build & push **linux/amd64** image to GHCR
  每次推送到 `main` 會自動：遞增 patch、把提交訊息寫入 `CHANGELOG.md`、建立 tag、建置並推送 **linux/amd64** 映像至 GHCR
- Image tags / 映像標籤：`latest`、`1.0.0`、`v1.0.0`、`sha-…`

## Files / 檔案清單

| File | EN | 中文 |
|------|----|------|
| `sync.sh` | Export → import → delete-old sync script | 核心匯出／匯入／刪舊腳本 |
| `i18n.sh` | EN/ZH messages (`LANG=en\|zh`; default **en**) | 中／英文訊息（`LANG=en\|zh`；未設定預設 **en**） |
| `delete-ciphers.js` | Hard-delete old ciphers via API | 以 API 批次永久刪除匯入前的舊項目 |
| `entrypoint.sh` | Initial sync + scheduler | 首次同步與排程啟動 |
| `crontab` | supercronic schedule (daily 03:00) | supercronic 排程（每日 03:00） |
| `Dockerfile` | Non-root + pinned Bitwarden CLI (`2026.7.0`) | 非 root + 釘住 Bitwarden CLI（`2026.7.0`） |
| `docker-compose.yml` | Service definition (reads `.env`) | 服務定義（從 `.env` 讀取密鑰） |
| `.env.example` | Environment variable template | 環境變數範本 |
| `VERSION` | Current semver | 目前語意化版本 |
| `CHANGELOG.md` | Release notes (auto-updated) | 更新詳情（自動更新） |
| `scripts/bump-version.sh` | Version bump + changelog helper | 升版與更新日誌腳本 |
| `.github/workflows/docker-publish.yml` | Auto release + GHCR AMD64 build | 自動發布 + GHCR AMD64 建置 |

## Limits / 限制

- Syncs **personal vault** items only (logins, cards, notes, identities) / 只同步**個人密碼庫**項目（登入、卡片、記事、身分）
- **No** attachments or organization vaults / **不含**附件與組織密碼庫
- Flow is **import + verify, then delete old**; on import failure, old data is kept (temporary duplicates possible) / **先匯入並驗證，再刪舊**；匯入失敗則保留舊資料（可能暫時重複）
- Source and destination must be **different servers/accounts**; treat destination as backup / 來源與目的地須為**不同伺服器／帳號**；目的地請當備份用

## Deploy / 部署步驟

1. Copy the env template and fill in credentials / 複製環境變數範本並填入真實憑證：

   ```bash
   cp .env.example .env
   ```

2. Edit `.env`: source & destination Vaultwarden URLs, API keys (`client_id` / `client_secret`), master passwords, and `APPRISE_URL`.
   編輯 `.env`：來源／目的地網址、API Key、主密碼，以及 `APPRISE_URL`。

   - `TZ` — timezone (default `Asia/Hong_Kong`) / 時區（預設香港）
   - `LANG` — `en` or `zh` for logs & Apprise; **omit or leave empty for English** / 日誌與通知語言；**不填則預設英文**
   - API keys: Web vault → Account Settings → Security → API Key / 網頁版「帳戶設定 → 安全性 → API Key」

3. Start (either) / 啟動（二選一）：

   **Local build / 本機建置：**

   ```bash
   docker compose up -d --build
   ```

   **Pull from GHCR / 拉取 GitHub 映像：**

   ```bash
   docker pull ghcr.io/wongkino/vaultwarden-sync:latest
   docker compose up -d
   ```

   If the package is private, log in first / 若套件為 Private，需先登入：

   ```bash
   echo YOUR_GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
   ```

4. Logs / 查看日誌：

   ```bash
   docker compose logs -f
   ```

Default schedule: daily **03:00** (per `TZ`, default HKT). An initial sync also runs on container start. Runs as non-root `node` (uid 1000).
預設每日 **03:00**（依 `TZ`，預設 HKT）執行；容器啟動時也會立刻同步一次。以非 root 使用者 `node`（uid 1000）執行。

On each sync end (success or failure), POSTs `title` / `body` / `type` to `APPRISE_URL`. Skipped if unset.
每次同步結束會 `curl` POST 到 `APPRISE_URL`；未設定則略過。

Pushing to `main` auto-bumps the version, updates `CHANGELOG.md`, tags `vX.Y.Z`, and publishes:
推送到 `main` 會自動升版、更新 `CHANGELOG.md`、打 `vX.Y.Z` tag，並發布：

`ghcr.io/wongkino/vaultwarden-sync` (`latest` / `vX.Y.Z`，**linux/amd64**)

## Security / 安全提醒

- Do not commit a filled `.env` (listed in `.gitignore`) / 不要把填好密鑰的 `.env` 提交到 Git
- Prefer an `EXPORT_PASSWORD` different from master passwords / `EXPORT_PASSWORD` 建議與主密碼不同
- Treat the destination as backup; avoid day-to-day edits that will be overwritten / 目的地應視為備份，避免日常新增會被覆寫的項目
