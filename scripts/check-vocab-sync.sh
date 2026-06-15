#!/usr/bin/env bash
# Conventional Commits の type 語彙が 4 箇所で一致しているか検証する（手動同期のドリフト防止）。
#   1) commit-check.toml  allow_commit_types
#   2) commit-check.toml  allow_branch_types
#   3) pr-validation.yml  semantic-pull-request の types
#   4) release-drafter.yml autolabeler の type 正規表現（/^<type>(...）
set -euo pipefail

RD=.github/release-drafter.yml
PRV=.github/workflows/pr-validation.yml
CC=commit-check.toml

commit_types=$(grep -E '^allow_commit_types' "$CC" | grep -oE '"[a-z]+"' | tr -d '"' | sort -u)
branch_types=$(grep -E '^allow_branch_types' "$CC" | grep -oE '"[a-z]+"' | tr -d '"' | sort -u)

pr_types=$(awk '
  /types: \|/        { f = 1; next }
  f && /requireScope/ { f = 0 }
  f && /^[[:space:]]+[a-z]+[[:space:]]*$/ { gsub(/[[:space:]]/, ""); print }
' "$PRV" | sort -u)

# autolabeler の `/^feat(` のような type 正規表現から type 名を抽出（breaking の \w+ は除外）
rd_types=$(grep -oE "/\^[a-z]+\(" "$RD" | sed -E 's#/\^([a-z]+)\(#\1#' | sort -u)

fail=0
ref="$commit_types"
for name in branch_types pr_types rd_types; do
  val="${!name}"
  if [ "$val" != "$ref" ]; then
    echo "::error::type vocabulary mismatch: ${name} が allow_commit_types と異なります"
    echo "--- allow_commit_types ---"; echo "$ref" | tr '\n' ' '; echo
    echo "--- ${name} ---";            echo "$val" | tr '\n' ' '; echo
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "type vocabulary is in sync across all 4 sources:"
  echo "$ref" | tr '\n' ' '; echo
fi
exit "$fail"
