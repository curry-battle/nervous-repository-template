# repo-scaffolding（リポ整備）

- 参照: `.github/ISSUE_TEMPLATE/*`、`.github/pull_request_template.md`、`LICENSE`、`.gitignore`
- 抜き出すもの: 各テンプレ、`LICENSE`、`.gitignore` を対象リポにそのまま配置（プロジェクト固有値は埋め直し）。
- AskUser:
  - **ライセンス種別**: MIT / Apache-2.0 / BSD-3-Clause / 独自（既存ライセンスがあればそれに合わせる）
  - **PR テンプレ / issue テンプレ**: 採用 / 既存を保持
- 生成: なし
- 注意（落とし穴）: PR テンプレ本文に **`BREAKING CHANGE:` という文字列を書かない**（`release-drafter` の body autolabeler に一致して全 PR が breaking 扱いになる）。"!" を使う旨の表現にする。
- 検証: テンプレが反映されているか目視（PR / issue 作成画面で確認）
- GitHub 手動設定: なし
- 依存: なし
