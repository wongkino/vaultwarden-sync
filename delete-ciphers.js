#!/usr/bin/env node
/**
 * Permanently delete ciphers by ID via Vaultwarden/Bitwarden API.
 * 透過 Vaultwarden/Bitwarden API 依 ID 永久刪除項目：
 * POST /api/ciphers/delete { ids: [...] }
 *
 * Env / 環境變數:
 *   BW_APPDATA_DIR  - Bitwarden CLI data dir (data.json) / CLI 資料目錄
 *   SERVER_URL      - Vaultwarden base URL / 伺服器網址
 *   IDS_FILE        - JSON array of cipher IDs / 項目 ID 陣列檔
 */
const fs = require("fs");
const path = require("path");

function fail(msg) {
  console.error(msg);
  process.exit(1);
}

function pickAccessToken(entry) {
  if (!entry) return null;
  if (typeof entry === "string") return entry;
  if (typeof entry.accessToken === "string") return entry.accessToken;
  if (entry.data && typeof entry.data.accessToken === "string") return entry.data.accessToken;
  return null;
}

const appData = process.env.BW_APPDATA_DIR;
const serverUrl = (process.env.SERVER_URL || "").replace(/\/$/, "");
const idsFile = process.env.IDS_FILE;

if (!appData) fail("BW_APPDATA_DIR is required");
if (!serverUrl) fail("SERVER_URL is required");
if (!idsFile) fail("IDS_FILE is required");

let ids;
try {
  ids = JSON.parse(fs.readFileSync(idsFile, "utf8"));
} catch (err) {
  fail(`Failed to read IDS_FILE: ${err.message}`);
}
if (!Array.isArray(ids)) fail("IDS_FILE must contain a JSON array");
ids = ids.filter((id) => typeof id === "string" && id.length > 0);

if (ids.length === 0) {
  console.log("No cipher IDs to delete.");
  process.exit(0);
}

const data = JSON.parse(fs.readFileSync(path.join(appData, "data.json"), "utf8"));
const userId = data.global_account_activeAccountId;
if (!userId) fail("No active account in CLI data.json");

const accessToken = pickAccessToken(data[`user_${userId}_token_accessToken`]);
if (!accessToken) fail("accessToken not found in CLI data.json");

(async () => {
  // Vaultwarden: POST /ciphers/delete = hard (permanent) multi-delete
  // Vaultwarden：POST /ciphers/delete 為永久批次刪除
  const res = await fetch(`${serverUrl}/api/ciphers/delete`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ ids }),
  });
  if (!res.ok) {
    const body = await res.text();
    fail(`Delete ciphers failed: HTTP ${res.status} ${body.slice(0, 300)}`);
  }
  console.log(`Deleted ${ids.length} old cipher(s).`);
})().catch((err) => fail(String(err && err.stack ? err.stack : err)));
