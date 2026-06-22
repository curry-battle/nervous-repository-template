# conventional-commits（commit / branch の Conventional 強制）

- 参照: `commit-check.toml`、`.pre-commit-config.yaml`(commit-check リポフック + `check-hook-rev-sha`)、`mise.toml`(prek)
- 抜き出すもの: `commit-check.toml` 全体 + `.pre-commit-config.yaml` の `commit-check` リポブロック（`check-message`=commit-msg / `check-branch`=pre-push）。
- AskUser:
  - **type 語彙**（横断・最初に確定）: 標準セット(feat/fix/docs/refactor/perf/test/build/ci/chore/revert) / 最小 / その他
  - **branch 語彙**: Conventional Commits 系(`feat/...`、type 語彙をそのまま branch prefix に流用) / Conventional Branch・Git-Flow(`feature/...`、type とは別語彙)。後者を選ぶ場合は `commit-check.toml` の `[branch] allow_branch_types`（または `conventional_branch`）を `feature`/`hotfix` 等に置き換える。type 語彙（feat/fix…）の単一の正とは**別系統の語彙になる**点を明示する（`vocab-self-test` は commit/PR/リリースの type を対象にし、branch 語彙は別管理）。
- 生成: なし
- 注意: commit / branch とも **commit-msg / pre-push hook（prek、ローカル）でのみ検証**。このテンプレに CI 検証ジョブは無い（branch 名は squash で main に残らないため）。CI でも強制したい場合は commit-check-action 等を別途追加する必要があり、このテンプレには**含まれない**。既定ブランチ(`main`)は `allow_branch_names` で除外。bot は `ignore_authors`。
- 検証: 規約違反の commit message と branch 名がローカルで弾かれる（負例で確認）
- GitHub 手動設定: なし（ローカルフックのみ）
- 依存: `foundation`
