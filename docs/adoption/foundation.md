# foundation（共通基盤: prek + aqua、mise は aqua bootstrap 用）

- 参照: `.pre-commit-config.yaml`、`aqua.yaml`、`aqua-checksums.json`、`mise.toml`、`mise.lock`
- 抜き出すもの: `.pre-commit-config.yaml` の骨組み（`repos:` と各モジュールの hook を足す器）、`aqua.yaml` の `packages[]`（各モジュールが使う CLI）と `registries` / `checksum` ブロック、`mise.toml`（aqua バイナリの 1 エントリのみ）と `[settings]`。
- AskUser: なし（基盤のため選択肢なし）
- 生成（bootstrap 順序に注意）:
  - `mise.toml` に aqua 1 行を宣言する（CLI ツールは `aqua.yaml` 側に列挙する）。このとき `[settings] locked` は**省略 or `false`** にしておく（`mise.lock` が無い状態で `locked=true` だと `mise install` が失敗する）。
  - `mise install` → `mise lock --platform linux-x64,macos-arm64` で `mise.lock` を生成してコミット → そのうえで `[settings]` に `lockfile=true` / `locked=true` を有効化する。
  - `aqua.yaml` を作り、`aqua update-checksum` で `aqua-checksums.json` を生成してコミット（**手書き禁止**）。`aqua install` が `linux/amd64` と `darwin/arm64` の両方で通ることを確認（= `aqua-checksum-pin`）。
  - `aqua exec -- prek install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push` で hook を有効化。**pre-commit を必ず含める**（pinact / ghalint / gitleaks / hadolint / vocab / check-pnpm-aqua-sync は pre-commit ステージ。これを外すと `actions-sha-pin` / `workflow-lint` / `secret-scan` / `docker-hardening` / `vocab-self-test` / `dependency-audit` のローカルフックが発火しない）。
- 注意: 基盤なしで「CI ジョブのみ」運用も可能だが、その場合ローカルフックは付かない（commit 前の早期検知が無くなる）。aqua 未 bootstrap な開発機では各ローカル CLI hook は `command -v aqua` で skip メッセージを出して commit はブロックしない（CI が強制する）。
- 検証: `mise install && aqua install` が通る / `prek install` 後に hook が登録される
- GitHub 手動設定: なし
- 依存: なし
