#!/usr/bin/env bash
# aqua.yaml の pnpm version と examples/docker-node/package.json の packageManager が
# 一致しているかを pure-shell (grep/sed) で検証する。
# - ランタイム (node) を Non-Goal にしているため、node 非依存で実装する。
# - パース失敗 (どちらかが空) も fail させ、フォーマット変化で検査がすり抜けるのを防ぐ。
# CI (pnpm-aqua-sync ジョブ) とローカル prek hook の両方から呼ばれる。
set -euo pipefail

PKG_JSON="${PKG_JSON:-examples/docker-node/package.json}"
AQUA_YAML="${AQUA_YAML:-aqua.yaml}"

# "packageManager": "pnpm@11.6.0" → 11.6.0
pkg_version=$(sed -n 's/.*"packageManager"[[:space:]]*:[[:space:]]*"pnpm@\([0-9][0-9.]*\)".*/\1/p' \
  "$PKG_JSON")
# - name: pnpm/pnpm@v11.6.0   (v は任意)  → 11.6.0
aqua_version=$(sed -n 's#.*pnpm/pnpm@v\{0,1\}\([0-9][0-9.]*\).*#\1#p' "$AQUA_YAML")

if [ -z "$pkg_version" ] || [ -z "$aqua_version" ]; then
  echo "::error::could not parse pnpm version (pkg='$pkg_version' aqua='$aqua_version')"
  exit 1
fi

if [ "$pkg_version" != "$aqua_version" ]; then
  echo "::error::pnpm packageManager ($pkg_version) does not match aqua.yaml ($aqua_version)"
  exit 1
fi

echo "pnpm version is in sync: $pkg_version"
