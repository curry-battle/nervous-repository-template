# workflow-lint（workflow セキュリティ lint: ghalint）

- 参照: `security-audit.yml`(gha-lint ジョブ)、`.pre-commit-config.yaml`、`aqua.yaml`
- 抜き出すもの: `security-audit.yml` の `gha-lint` ジョブ（base-branch overlay step 込み）+ `.pre-commit-config.yaml` の ghalint ローカル hook + `aqua.yaml` の `suzuki-shunsuke/ghalint` 行。
- AskUser: なし
- 生成: なし
- 注意:
  - ghalint のポリシー（`permissions` 最小化、`timeout-minutes` 必須、SHA 固定）に合わせて**既存 workflow の修正が必要**になる。
  - SHA 固定を要求するため、**未 pin の action が残っていると落ちる**（`actions-sha-pin` を先に適用するか、対象 workflow を pin する）。CI は **aqua-installer で aqua 自身を SHA pin し、`aqua exec -- ghalint run` を実行**（PR の aqua 設定差し替えは base-branch overlay でブロック）。
- 検証: `aqua exec -- ghalint run`（違反なら既存 workflow を修正）
- GitHub 手動設定: `gha-lint` ジョブを `main` の Branch protection で required check 化（任意・運用次第）
- 依存: `foundation`、`actions-sha-pin` 推奨（未 pin と衝突）
