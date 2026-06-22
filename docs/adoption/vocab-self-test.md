# vocab-self-test（type 語彙の自己テスト）

- 参照: `scripts/check-vocab-sync.sh`、`.pre-commit-config.yaml`（**pre-commit hook のみ。CI には載せない**＝毎 PR 実行は過剰。当該ファイル変更時のみ発火）
- 抜き出すもの: `scripts/check-vocab-sync.sh` + `.pre-commit-config.yaml` の check-vocab-sync ローカル hook。
- AskUser: なし（採用 or 不採用のみ）
- 生成: なし
- 注意: `conventional-commits` / `pr-title` / `release-drafter` を入れた場合のみ意味を持つ。スクリプトは語彙の抽出元（4 箇所）が対象リポの構成と一致しているか調整する。
- 検証: `bash scripts/check-vocab-sync.sh`（語彙の抽出元 4 箇所が一致）
- GitHub 手動設定: なし
- 依存: `foundation` + `conventional-commits` / `pr-title` / `release-drafter`
