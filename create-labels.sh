#!/usr/bin/env bash
set -euo pipefail
# autolabeler が参照するラベルを作成/更新する。
# ラベル名は .github/release-drafter.yml と一致させること
# （特に feat: に対応するラベルは "feature"。"feat" ではない）。
#
# 必要: gh CLI（gh auth login 済み）
# 使い方:
#   bash create-labels.sh                 # カレントディレクトリのリポジトリ
#   REPO=owner/name bash create-labels.sh # リポジトリを明示指定

repo_flag=()
[ -n "${REPO:-}" ] && repo_flag=(--repo "$REPO")

# name|color(hex, # なし)|description
labels=(
  "breaking|b60205|💥 Breaking change (major)"
  "feature|0e8a16|🚀 New feature (minor)"
  "fix|d73a4a|🐛 Bug fix (patch)"
  "perf|fbca04|⚡ Performance (patch)"
  "refactor|1d76db|♻️ Refactoring (patch)"
  "docs|0075ca|📝 Documentation"
  "test|c5def5|✅ Tests"
  "build|c2e0c6|📦 Build / dependencies"
  "ci|bfdadc|🔧 CI configuration"
  "chore|ededed|🧰 Chore"
  "revert|e99695|⏪ Revert"
  "skip-changelog|cccccc|リリースノートから除外する"
  "security|b60205|🔒 Security fix (Renovate vulnerabilityAlerts)"
)

for entry in "${labels[@]}"; do
  IFS='|' read -r name color desc <<< "$entry"
  # --force: 既存ラベルがあれば色・説明を上書き更新する（冪等）
  gh label create "$name" --color "$color" --description "$desc" --force "${repo_flag[@]}"
done

echo "✅ ${#labels[@]} 個のラベルを作成/更新しました"
