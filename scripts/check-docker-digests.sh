#!/usr/bin/env bash
# 全 Dockerfile の FROM が full digest（@sha256:...）で固定されているか検証する。
# ステージ参照（FROM <stage>）と scratch は除外。FROM --platform=... のフラグも考慮。
# CI（docker ジョブ）とローカル prek hook の両方から呼ばれる。
#
# 代替: azu/dockerfile-pin（https://github.com/azu/dockerfile-pin）等の OSS があるが、
# 依存を追加したくない（追加すればそれ自体が pin 対象になる）ため自前で実装している。
set -euo pipefail

mapfile -t files < <(find . -path ./node_modules -prune -o -type f \
  \( -name Dockerfile -o -name 'Dockerfile.*' -o -name '*.Dockerfile' \) -print)

if [ ${#files[@]} -eq 0 ]; then
  echo "no Dockerfiles found"
  exit 0
fi

awk '
  FNR==1 { split("", stages) }            # ファイルごとに stage 集合をリセット
  toupper($1) == "FROM" {
    img = ""
    for (i = 2; i <= NF; i++) {           # --platform 等のフラグを飛ばして image を取る
      if ($i ~ /^--/) continue
      img = $i
      break
    }
    for (i = 2; i <= NF; i++) {           # "AS <name>" のステージ名を記録
      if (toupper($i) == "AS") stages[$(i + 1)] = 1
    }
    if (img == "scratch" || (img in stages)) next
    if (img !~ /@sha256:[0-9a-f]{64}/) {
      print "::error file=" FILENAME "::FROM not digest-pinned -> " $0
      bad = 1
    }
  }
  END { if (bad) exit 1; else print "all FROM are digest-pinned." }
' "${files[@]}"
