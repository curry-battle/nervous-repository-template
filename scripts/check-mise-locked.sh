#!/usr/bin/env bash
# mise.toml の [tools] に列挙された全ツールが mise.lock に checksum 付きで固定されているか
# 「静的に」検証する（mise install は実行しない＝PR の任意コード実行を避ける）。
# mise.lock が無い場合は明示的に失敗させる（検証の迂回を防ぐ）。
set -euo pipefail

if [ ! -f mise.lock ]; then
  echo "::error::mise.lock is missing (run 'mise lock' and commit it)"
  exit 1
fi

# [tools] テーブルのツール名を抽出
tools=$(awk '
  /^\[tools\]/ { intools = 1; next }
  /^\[/        { intools = 0 }
  intools && /=/ {
    line = $0; sub(/[[:space:]]*=.*/, "", line); gsub(/[[:space:]"]/, "", line)
    if (line != "") print line
  }
' mise.toml)

if [ -z "$tools" ]; then
  echo "no tools in mise.toml"
  exit 0
fi

echo "$tools" | awk '
  NR == FNR { want[$0] = 1; next }                  # 第1引数（tools 一覧）を読む
  /^\[\[tools\./ {
    name = $0; sub(/^\[\[tools\./, "", name); sub(/\]\].*/, "", name)
    seen[name] = 1
  }
  /checksum/ && name != "" { haschk[name] = 1 }
  END {
    for (t in want) {
      if (!(t in seen))      { print "::error::tool \"" t "\" is not locked in mise.lock"; bad = 1 }
      else if (!(t in haschk)) { print "::error::tool \"" t "\" has no checksum in mise.lock"; bad = 1 }
    }
    if (bad) exit 1; else print "all mise tools are locked with checksum."
  }
' - mise.lock
