# nervous-repository-template

神経質気味な人のためのリポジトリテンプレート

含まれるもの：
- Conventional Commits を軸に commit / branch / PR / リリースを規約で統一
- 外部依存 (GitHub Actions / pre-commit hook / mise tools) の SHA と checksum の固定を CI で強制
- Renovateによるライブラリ更新

## 包含されるもの

### 開発フロー

#### Conventional 規約の強制

| 目的 | ツール | チェックするタイミング |
|---|---|---|
| commit / branch name を Conventional で強制 | [commit-check](https://github.com/commit-check/commit-check) | commit-msg hook<br />pre-push hook |
| PR title を Conventional で強制 | [action-semantic-pull-request](https://github.com/amannn/action-semantic-pull-request) | PR（CI） |

#### リリース自動化

| 目的 | ツール | チェックするタイミング |
|---|---|---|
| リリースノート / semver を自動生成 | [release-drafter](https://github.com/release-drafter/release-drafter) | main への push（CI） |

Squash マージを前提にしているため、PR title はそのまま `main` のコミットメッセージになり、
release-drafter がそれをリリースノートの 1 行として拾う。
この「PR title → `main` コミット → リリースノート」を一本に通すため、
commit / branch / PR title / リリース分類のすべてを
Conventional Commits の type（`feat` / `fix` …）で統一している。

### セキュリティ・環境

#### サプライチェーン・セキュリティ

| 目的 | ツール | チェックするタイミング |
|---|---|---|
| Actions を SHA 固定 | [pinact](https://github.com/suzuki-shunsuke/pinact) | pre-commit hook<br />PR（CI） |
| workflow のセキュリティ lint | [ghalint](https://github.com/suzuki-shunsuke/ghalint) | pre-commit hook<br />PR（CI） |
| 依存更新（Actions / hook / mise / Docker / npm / Cargo） | [Renovate](https://docs.renovatebot.com/) | 定期（Renovate スケジュール） |
| npm 依存の脆弱性監査（install せず lockfile + advisory API） | [pnpm audit](https://pnpm.io/cli/audit) | PR（CI） |
| Rust 依存の監査（advisories / licenses / bans / sources） | [cargo-deny](https://github.com/EmbarkStudios/cargo-deny) | pre-commit hook<br />PR（CI） |
| secret の検出 | [gitleaks](https://github.com/gitleaks/gitleaks) | pre-commit hook<br />PR（CI） |
| ファイルシステムの脆弱性 / 誤設定スキャン | [trivy](https://github.com/aquasecurity/trivy) | pre-commit hook<br />PR（CI） |

#### Docker

| 目的 | ツール | チェックするタイミング |
|---|---|---|
| Dockerfile lint + base image の digest 固定 | [hadolint](https://github.com/hadolint/hadolint) + 自前チェック（`examples/docker-node/`・`examples/docker-rust/` がサンプル） | pre-commit hook<br />PR（CI） |

#### 開発環境

| 目的 | ツール | チェックするタイミング |
|---|---|---|
| CLI ツールのバージョン・checksum 固定 | [aqua](https://aquaproj.github.io/)（prek / pinact / ghalint / gitleaks / cargo-deny / trivy / pnpm の 7 ツール） | aqua install 時<br />PR（CI で aqua-checksums 検証） |
| aqua バイナリ自身の bootstrap | [mise](https://mise.jdx.dev/) | mise install 時 |

hadolint は他ツールと別経路：CI は `hadolint/hadolint-action` (SHA pin)、ローカルは `.pre-commit-config.yaml` の remote hook (`rev` を full commit SHA で固定) で取得・実行する。aqua には載せない。

## クイックスタート

```bash
mise install   # mise.lock の checksum で aqua バイナリを取得
aqua install   # aqua-checksums.json の checksum で各 CLI を取得
prek install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push
# tool を追加/変更したら: aqua.yaml を編集して `aqua update-checksum` で aqua-checksums.json を更新
```

1. Squash merge のみ有効化（+ "Default to PR title for squash commits"）
2. `main` の Branch protection で次を required にする:
   `Validate PR title` / `Verify actions are SHA-pinned` /
   `Verify hooks are SHA-pinned` / `Verify aqua checksums are current` /
   `Verify pnpm packageManager == aqua.yaml` /
   `Verify Docker (lint / digest-pinned / compose)` /
   `Lint workflows (ghalint)` / `Scan for secrets (gitleaks)` /
   `Audit Rust deps (cargo-deny)` / `Scan filesystem (trivy)` / `Audit npm deps (pnpm audit)`
   さらに `aqua.yaml` / `aqua-checksums.json` を maintainer レビュー必須にするため
   `CODEOWNERS` を有効化（"Require review from Code Owners" を ON）。
3. [Renovate App](https://github.com/apps/renovate) を有効化
4. `bash create-labels.sh` でラベルを作成

## このリポジトリの要素を自分のリポジトリに取り入れる

このテンプレートは全部入りだが、一部だけ（例: リリース自動化、サプライチェーン対策）を既存リポジトリへ移植することもできる。

移植は **AI エージェント（Claude / Codex 等）に任せる**のが楽。[docs/adoption-guide.md](./docs/adoption-guide.md) が LLM 向けのプレイブックで、エージェントに次のように頼むと、必要なモジュールと設定値を AskUser で確認しながら移植してくれる。

> このリポジトリの docs/adoption-guide.md に従って、リリース自動化を私のリポジトリに取り入れて

手で移植する場合も、モジュール一覧（区分 / 依存 / 参照ファイル）と落とし穴チェックリストの索引として使える。

## ドキュメント

3 層構成。深いほど具体的になる。

- [docs/design.md](./docs/design.md)：**設計の背景**：思想、type 語彙、リリースの流れ、サプライチェーン対策、運用ルール
- [docs/adoption-guide.md](./docs/adoption-guide.md)：**LLM 向け移植プレイブック (index)**：モジュール選択 → 設定値 AskUser → 適用の 4 ステップ
- [docs/adoption/](./docs/adoption/)：**モジュール詳細**：14 モジュール各々の「参照 / 抜き出すもの / AskUser / 生成 / 注意 / 検証 / GitHub 手動設定 / 依存」
