# release-drafter（リリース自動化）

- 参照: `.github/release-drafter.yml`、`.github/workflows/release-drafter.yml`、`create-labels.sh`
- 抜き出すもの: `release-drafter.yml`(設定) + `workflows/release-drafter.yml`(push:main でドラフト更新、PR で autolabel) + `create-labels.sh`。3 点セットで持ち込む。
- AskUser:
  - **章構成**: 集約型 / 主要のみ表示
  - **version-resolver**: default patch / default no-bump
  - **破壊的変更検出**: title `!` + body footer / `!` のみ
  - **fork PR ラベリング**: `pull_request` のみ（fork からの PR は `GITHUB_TOKEN` が read-only になりラベル付与が失敗しうる。fork 非対応で割り切る） / `pull_request_target` または GitHub App。autolabel は PR title しか見ないので **PR のコードは checkout しない**（ラベル操作のみ）。`pull_request_target` で untrusted な PR head を checkout してビルド/スクリプトを走らせるのが最も危険なパターンなので避ける。やむを得ず checkout する場合もビルド・任意コード実行をジョブに入れず、付与権限は `pull-requests: write` 最小、`persist-credentials: false`
- 生成: なし
- 注意（落とし穴）:
  - **`categories[].exclusive` は v6 系では非対応**。二重分類防止は **autolabeler 側で type 正規表現を排他化**（type 規則は `!` を含めず `:` で終端、`feat!:` は breaking のみ）で行う。
  - autolabeler は**加算のみ**（stale ラベルを外さない）。
  - ラベルは `create-labels.sh` で作る（`feat:`→ラベルは **`feature`**）。
  - 初回は基準 tag が無いと semver 算出不可。手動で `v0.1.0` を作る。
- 検証: `create-labels.sh` 後にラベルが揃う / テスト PR で autolabel が付く
- GitHub 手動設定: Squash merge のみ有効化 + "Default to PR title for squash commits" / `bash create-labels.sh` でラベル作成 / 初回の基準 tag `v0.1.0` を手動作成
- 依存: `conventional-commits` / `pr-title`（語彙）
