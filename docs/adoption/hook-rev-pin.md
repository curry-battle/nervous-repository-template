# hook-rev-pin（pre-commit hook rev の SHA 固定）

- 参照: `scripts/check-hook-rev-sha.sh`、`pin-hooks`ジョブ、`.pre-commit-config.yaml`
- 抜き出すもの: `pr-validation.yml` の `pin-hooks` ジョブ + `scripts/check-hook-rev-sha.sh`。
- AskUser: なし（採用 or 不採用のみ。`renovate` があれば更新は自動）
- 生成: `.pre-commit-config.yaml` の各 `rev:` を full SHA に固定する。`aqua exec -- prek auto-update --freeze` でタグ→SHA に凍結できる（pre-commit を使う場合は `pre-commit autoupdate --freeze`。サブコマンド名が prek=`auto-update` / pre-commit=`autoupdate` で異なる点に注意）。
- 注意: なし
- 検証: `bash scripts/check-hook-rev-sha.sh`
- GitHub 手動設定: `pin-hooks` ジョブを `main` の Branch protection で required check 化（任意・運用次第）
- 依存: `foundation`（`.pre-commit-config.yaml` が前提）
