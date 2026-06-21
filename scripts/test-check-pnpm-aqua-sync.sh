#!/usr/bin/env bash
# scripts/check-pnpm-aqua-sync.sh の最小テスト。
# 一致時 pass / 不一致時 fail / パース失敗時 fail の 3 ケースを確認する。
# このリポには専用テストフレームワークが無いため shell の自己完結テストとして書く。
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET="$SCRIPT_DIR/check-pnpm-aqua-sync.sh"

if [ ! -f "$TARGET" ]; then
  echo "::error::target script not found: $TARGET"
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

mk_pkg() {
  # $1: pnpm version (例: 11.6.0) — 空文字なら packageManager フィールドを出さない
  mkdir -p "$WORK/examples/docker-node"
  if [ -z "${1:-}" ]; then
    cat > "$WORK/examples/docker-node/package.json" <<'JSON'
{
  "name": "x",
  "version": "0.0.0",
  "private": true
}
JSON
  else
    cat > "$WORK/examples/docker-node/package.json" <<JSON
{
  "name": "x",
  "version": "0.0.0",
  "private": true,
  "packageManager": "pnpm@$1"
}
JSON
  fi
}

mk_aqua() {
  # $1: pnpm version (例: 11.6.0) — 空文字なら pnpm 行を出さない
  if [ -z "${1:-}" ]; then
    cat > "$WORK/aqua.yaml" <<'YAML'
---
registries:
  - type: standard
    ref: v4.x.y
packages:
  - name: gitleaks/gitleaks@v8.30.1
YAML
  else
    cat > "$WORK/aqua.yaml" <<YAML
---
registries:
  - type: standard
    ref: v4.x.y
packages:
  - name: pnpm/pnpm@v$1
YAML
  fi
}

run_target() {
  # $1: expected exit code (0 = pass, 非 0 = fail)
  set +e
  PKG_JSON="$WORK/examples/docker-node/package.json" AQUA_YAML="$WORK/aqua.yaml" \
    bash "$TARGET" > "$WORK/out" 2>&1
  rc=$?
  set -e
  if [ "$rc" -ne "$1" ]; then
    echo "::error::expected exit $1 but got $rc"
    sed 's/^/  | /' "$WORK/out"
    exit 1
  fi
}

echo "--- case 1: matching versions should pass"
mk_pkg "11.6.0"; mk_aqua "11.6.0"
run_target 0

echo "--- case 2: matching versions without v prefix in aqua.yaml should pass"
mk_pkg "11.6.0"
cat > "$WORK/aqua.yaml" <<'YAML'
packages:
  - name: pnpm/pnpm@11.6.0
YAML
run_target 0

echo "--- case 3: mismatched versions should fail"
mk_pkg "11.6.0"; mk_aqua "11.6.1"
run_target 1

echo "--- case 4: missing packageManager should fail (parse)"
mk_pkg ""; mk_aqua "11.6.0"
run_target 1

echo "--- case 5: missing pnpm in aqua.yaml should fail (parse)"
mk_pkg "11.6.0"; mk_aqua ""
run_target 1

echo "all tests passed."
