# pr-title（PR title の Conventional 強制）

- 参照: `.github/workflows/pr-validation.yml`(pr-title ジョブ)
- 抜き出すもの: `pr-validation.yml` の `pr-title` ジョブのみ（`permissions: pull-requests: read` も一緒に）。対象リポに workflow が無ければ pr-title ジョブだけの新規 workflow を作る。
- AskUser:
  - **scope**: 任意・自由記述 / 必須・allowlist / 禁止
  - **subject 厳格度**: 最小(type形式のみ) / 整形ルール追加
  - **required check 化**するか（横断の Branch protection チェックリストへ）
- 生成: なし
- 注意: types は **`conventional-commits` の type 語彙と一致**させる。マージ戦略は横断決定（Squash 専用）に従う。
- 検証: 不正な PR title で `pr-title` ジョブが fail する
- GitHub 手動設定: `pr-title` ジョブを `main` の Branch protection で required check 化（任意・運用次第）
- 依存: `conventional-commits`（type 語彙）
