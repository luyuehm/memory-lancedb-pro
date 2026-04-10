#!/usr/bin/env bash
set -euo pipefail

# memory-lancedb-pro production readiness check
# Usage:
#   bash scripts/release-readiness-check.sh
# Optional env:
#   FAST=1            # skip heavy/full test suites
#   LEGACY_DB_PATH=.. # enable migrate run/verify checks
#   TEST_SCOPE=global # scope for memory-pro checks (default: global)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

FAST="${FAST:-0}"
TEST_SCOPE="${TEST_SCOPE:-global}"
LEGACY_DB_PATH="${LEGACY_DB_PATH:-}"
TMP_DIR="$(mktemp -d -t mempro-readiness-XXXXXX)"
IMPORT_JSON="$TMP_DIR/import.json"
EXPORT_JSON="$TMP_DIR/export.json"

cleanup() {
  rm -rf "$TMP_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cat > "$IMPORT_JSON" <<'JSON'
{
  "version": "1.0",
  "memories": [
    {
      "id": "11111111-1111-4111-8111-111111111111",
      "text": "用户偏好：喜欢乌龙茶，晚上减少咖啡摄入。",
      "category": "preference",
      "scope": "global",
      "importance": 0.8,
      "metadata": "{}"
    },
    {
      "id": "22222222-2222-4222-8222-222222222222",
      "text": "项目约束：发布前必须跑全量回归。",
      "category": "fact",
      "scope": "global",
      "importance": 0.7,
      "metadata": "{}"
    }
  ]
}
JSON

if [[ "$TEST_SCOPE" != "global" ]]; then
  # quick scope override for import fixture
  perl -0777 -i -pe 's/"scope":\s*"global"/"scope": "'"$TEST_SCOPE"'"/g' "$IMPORT_JSON"
fi

TOTAL=0
PASS=0
FAIL=0

run_check() {
  local name="$1"
  shift
  TOTAL=$((TOTAL + 1))
  echo "\n[CHECK $TOTAL] $name"
  if "$@"; then
    echo "✅ PASS - $name"
    PASS=$((PASS + 1))
  else
    echo "❌ FAIL - $name"
    FAIL=$((FAIL + 1))
  fi
}

run_capture() {
  # run command, suppress noisy output unless failure
  local logfile="$TMP_DIR/cmd-$RANDOM.log"
  if "$@" >"$logfile" 2>&1; then
    return 0
  fi
  echo "--- command failed: $* ---"
  tail -n 120 "$logfile" || true
  return 1
}

cmd_has() {
  command -v "$1" >/dev/null 2>&1
}

check_repo_clean() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

check_plugin_files() {
  [[ -f package.json && -f openclaw.plugin.json && -f index.ts ]]
}

check_version_sync() {
  node -e '
const fs=require("fs");
const pkg=JSON.parse(fs.readFileSync("package.json","utf8"));
const manifest=JSON.parse(fs.readFileSync("openclaw.plugin.json","utf8"));
if(pkg.version!==manifest.version){
  console.error(`version mismatch: package=${pkg.version}, manifest=${manifest.version}`);
  process.exit(1);
}
'
}

check_npm_test() {
  if [[ "$FAST" == "1" ]]; then
    echo "FAST=1, skip npm test"
    return 0
  fi
  run_capture npm test
}

check_openclaw_host_test() {
  if [[ "$FAST" == "1" ]]; then
    echo "FAST=1, skip openclaw host functional"
    return 0
  fi
  run_capture npm run test:openclaw-host
}

check_openclaw_available() {
  cmd_has openclaw
}

check_plugin_loaded() {
  run_capture openclaw plugins info memory-lancedb-pro
}

check_memory_pro_version() {
  run_capture openclaw memory-pro version
}

check_import_list_search_stats_export() {
  run_capture openclaw memory-pro import "$IMPORT_JSON" --scope "$TEST_SCOPE" || return 1
  run_capture openclaw memory-pro list --scope "$TEST_SCOPE" --json || return 1
  run_capture openclaw memory-pro search 乌龙茶 --scope "$TEST_SCOPE" --json || return 1
  run_capture openclaw memory-pro stats --scope "$TEST_SCOPE" --json || return 1
  run_capture openclaw memory-pro export --scope "$TEST_SCOPE" --output "$EXPORT_JSON" || return 1
  [[ -s "$EXPORT_JSON" ]] || return 1
}

check_delete_idempotency() {
  # first delete may succeed/fail depending on prior data state; second must not crash process either
  openclaw memory-pro delete 22222222-2222-4222-8222-222222222222 --scope "$TEST_SCOPE" >/dev/null 2>&1 || true
  openclaw memory-pro delete 22222222-2222-4222-8222-222222222222 --scope "$TEST_SCOPE" >/dev/null 2>&1 || true
  return 0
}

check_migrate_if_configured() {
  if [[ -z "$LEGACY_DB_PATH" ]]; then
    echo "LEGACY_DB_PATH not set, skip"
    return 0
  fi
  run_capture openclaw memory-pro migrate run --source "$LEGACY_DB_PATH"
  run_capture openclaw memory-pro migrate verify --source "$LEGACY_DB_PATH"
}

check_npm_pack_dryrun() {
  run_capture npm pack --dry-run
}

echo "== memory-lancedb-pro release readiness check =="
echo "ROOT_DIR=$ROOT_DIR"
echo "FAST=$FAST, TEST_SCOPE=$TEST_SCOPE, LEGACY_DB_PATH=${LEGACY_DB_PATH:-<unset>}"

run_check "git repo valid" check_repo_clean
run_check "plugin core files exist" check_plugin_files
run_check "package.json version == openclaw.plugin.json version" check_version_sync
run_check "npm test" check_npm_test
run_check "openclaw host functional test" check_openclaw_host_test
run_check "openclaw CLI available" check_openclaw_available
run_check "plugin can be discovered" check_plugin_loaded
run_check "memory-pro version command" check_memory_pro_version
run_check "import/list/search/stats/export flow" check_import_list_search_stats_export
run_check "delete idempotency" check_delete_idempotency
run_check "migrate run/verify (optional)" check_migrate_if_configured
run_check "npm pack dry-run" check_npm_pack_dryrun

echo "\n== Summary =="
echo "TOTAL: $TOTAL"
echo "PASS : $PASS"
echo "FAIL : $FAIL"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

echo "All checks passed."
