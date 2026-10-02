#!/usr/bin/env bash
# Bump VERSION and prepend CHANGELOG from commits since the last tag.
# 遞增 VERSION，並依距上一 tag 的提交寫入 CHANGELOG。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION_FILE="$ROOT/VERSION"
CHANGELOG_FILE="$ROOT/CHANGELOG.md"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "1.0.0" > "$VERSION_FILE"
fi

current="$(tr -d '[:space:]' < "$VERSION_FILE")"
if [[ ! "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid VERSION: $current" >&2
  exit 1
fi

IFS=. read -r major minor patch <<< "$current"
last_tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"
today="$(date -u '+%Y-%m-%d')"

if [[ -z "$last_tag" ]]; then
  # First release: keep VERSION (expected 1.0.0); do not duplicate CHANGELOG if present.
  # 首次發布：沿用 VERSION；若 CHANGELOG 已有該版本則不重複寫入。
  new_version="$current"
  echo "First release — using VERSION ${new_version}" >&2

  if ! grep -qE "^## \[${new_version}\]" "$CHANGELOG_FILE" 2>/dev/null; then
    {
      echo "## [${new_version}] - ${today}"
      echo
      echo "### Changes / 變更"
      echo
      echo "- Initial release / 初始發布"
      echo
    } > /tmp/changelog_section.md

    if [[ -f "$CHANGELOG_FILE" ]] && grep -qE '^## \[' "$CHANGELOG_FILE"; then
      awk 'BEGIN{done=0} /^## \[/ && !done {
        while ((getline line < "/tmp/changelog_section.md") > 0) print line
        close("/tmp/changelog_section.md"); done=1
      } {print}' "$CHANGELOG_FILE" > /tmp/changelog_out.md
      mv /tmp/changelog_out.md "$CHANGELOG_FILE"
    else
      cat /tmp/changelog_section.md >> "$CHANGELOG_FILE"
    fi
  fi
else
  new_version="${major}.${minor}.$((patch + 1))"
  echo "Bumping ${current} → ${new_version} (since ${last_tag})" >&2

  mapfile -t commits < <(
    git log "${last_tag}..HEAD" --pretty=format:'%s' --no-merges \
      | grep -vE '^chore\(release\)' \
      || true
  )

  {
    echo "## [${new_version}] - ${today}"
    echo
    echo "### Changes / 變更"
    echo
    if [[ ${#commits[@]} -eq 0 ]]; then
      echo "- Release packaging / 發布打包"
    else
      for msg in "${commits[@]}"; do
        [[ -z "$msg" ]] && continue
        echo "- ${msg}"
      done
    fi
    echo
  } > /tmp/changelog_section.md

  awk 'BEGIN{done=0} /^## \[/ && !done {
    while ((getline line < "/tmp/changelog_section.md") > 0) print line
    close("/tmp/changelog_section.md"); done=1
  } {print}' "$CHANGELOG_FILE" > /tmp/changelog_out.md
  mv /tmp/changelog_out.md "$CHANGELOG_FILE"

  printf '%s\n' "$new_version" > "$VERSION_FILE"
fi

# Always print the version alone on the last line for CI capture
# 最後一行只輸出版本號，供 CI 擷取
echo "$new_version"
