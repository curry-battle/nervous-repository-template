# renovate（依存更新）

- 参照: `renovate.json5`
- 抜き出すもの: `renovate.json5` から、有効化する manager（github-actions / pre-commit / mise / docker / npm / cargo 等）と該当する設定ブロック（`minimumReleaseAge` / `packageRules` / `pinDigests` 等）だけを対象リポの Renovate 設定にマージ。使わない manager のルールは持ち込まない。
- AskUser:
  - **実行方式**: Mend ホスト型 App / self-hosted(GHA)。self-hosted は `GITHUB_TOKEN` だと PR が CI を発火しないため**別アイデンティティのトークン必須**
  - **cooldown 日数**: `minimumReleaseAge`（既定 7d、major 14d 等）
  - **automerge**: しない / digest / patch のみ限定解禁
- 生成: なし
- 注意: 更新対象（Actions / pre-commit / mise / Docker / npm / cargo 等）が存在しなければモジュール不要。Dependabot と同 ecosystem で併走させない。pre-commit / mise / docker manager を有効化。`@types/node` 等は runtime メジャーに合わせる `allowedVersions` を検討。
- 検証: `npx --package renovate -- renovate-config-validator renovate.json5`（validator はこのテンプレに含まれないため npx 経由で取得）
- GitHub 手動設定: [Renovate App](https://github.com/apps/renovate) を有効化（self-hosted なら別アイデンティティのトークンを用意）
- 依存: なし
