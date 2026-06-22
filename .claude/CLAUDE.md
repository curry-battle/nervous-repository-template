テンプレート集リポジトリ

再利用される前提で、実装とドキュメントは常に一貫した内容である必要がある。

## 重要なドキュメント

- [docs/design.md](../docs/design.md)：設計の背景（type 語彙、リリースの流れ、運用ルール）
- [docs/adoption-guide.md](../docs/adoption-guide.md)：LLM 向け移植プレイブック (index)
- [docs/adoption/](../docs/adoption/)：モジュール詳細 14 ファイル

## ルール

- `pinact` / `ghalint` 等を直接呼ばず、 `aqua exec -- <tool>` を利用すること

- `docs/adoption/*.md`
  - `rules/docs-conventions.md`
- *後方互換性 / 段階移行は基本不要
  - テンプレなので利用者が一括コピー前提。
  - 古いパスや旧名のリダイレクトを残さない（必要時はユーザに確認）
