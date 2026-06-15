#!/usr/bin/env bash
# .pre-commit-config.yaml の全 hook rev が full commit SHA で固定されているか検証する。
# CI（pin-hooks ジョブ）とローカル prek hook の両方から呼ばれる。
set -euo pipefail

awk '
  /^[[:space:]]*rev:/ {
    v = $2; gsub(/["'\'']/, "", v)
    if (v !~ /^[0-9a-f]{40}$/) { print "rev not SHA-pinned -> " $0; bad = 1 }
  }
  END { if (bad) exit 1; else print "all hook revs are SHA-pinned." }
' .pre-commit-config.yaml
