# repository-template

汎用的に利用されることを目指したリポジトリテンプレート

- Conventional Commits を軸に commit / branch / PR / リリースを規約で統一
- GitHub Actions のサプライチェーンを固めたリポジトリテンプレート
- 外部依存（GitHub Actions / pre-commit hook / mise ツール）の **SHA・checksum 固定を CI で強制**
- Renovateによるライブラリ更新を包含

## 何が入っているか

### 1. Conventional 規約の強制

| 目的 | ツール |
|---|---|
| commit / branch name を Conventional で強制 | [commit-check](https://github.com/commit-check/commit-check)（prek のみ。過剰なので CI では検証しない） |
| PR title を Conventional で強制 | [action-semantic-pull-request](https://github.com/amannn/action-semantic-pull-request)（required check） |

### 2. リリース自動化

| 目的 | ツール |
|---|---|
| リリースノート / semver を自動生成 | [release-drafter](https://github.com/release-drafter/release-drafter)（分類を type に対応） |

### 3. サプライチェーン・セキュリティ

| 目的 | ツール |
|---|---|
| Actions を SHA 固定 | [pinact](https://github.com/suzuki-shunsuke/pinact) |
| workflow のセキュリティ lint | [ghalint](https://github.com/suzuki-shunsuke/ghalint)（permissions 最小化・timeout 必須等） |
| 依存更新（Actions / hook / mise / Docker） | [Renovate](https://docs.renovatebot.com/)（cooldown + digest 固定） |
| secret の検出 | [gitleaks](https://github.com/gitleaks/gitleaks)（prek で commit 前 + CI で全体スキャン） |

### 4. Docker

| 目的 | ツール |
|---|---|
| Dockerfile lint + base image の digest 固定 | [hadolint](https://github.com/hadolint/hadolint) + 自前チェック（`examples/node-app/` がサンプル） |

### 5. 開発環境

| 目的 | ツール |
|---|---|
| 開発 CLI のバージョン固定 | [mise](https://mise.jdx.dev/)（prek / pinact / hadolint / ghalint / gitleaks） |

すべて Conventional Commits の type（`feat` / `fix` …）1 つに揃え、Squash マージ前提で
PR title = `main` コミット = リリースノートの 1 行、になるよう設計している。

## クイックスタート

```bash
mise install   # mise.lock の checksum で検証してインストール
prek install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push
# tool を追加/変更したら: mise lock --platform linux-x64,macos-arm64 で mise.lock を更新
```

1. Squash merge のみ有効化（+ "Default to PR title for squash commits"）
2. `main` の Branch protection で次を required にする:
   `Validate PR title` / `Verify actions are SHA-pinned` /
   `Verify hooks are SHA-pinned` / `Verify mise tools are locked` / `Verify Docker (lint / digest-pinned / compose)` /
   `Lint workflows (ghalint)` / `Scan for secrets (gitleaks)`
3. [Renovate App](https://github.com/apps/renovate) を有効化
4. `bash create-labels.sh` でラベルを作成

## ドキュメント

- [docs/design.md](./docs/design.md) — 思想・仕組み・type 語彙・リリースの流れ・サプライチェーン対策・運用ルール
- [docs/adoption-guide.md](./docs/adoption-guide.md) — このリポの一部/全部を他リポへ取り込むときの **LLM 向けプレイブック**（AskUser でモジュール選択 → 設定内容を決定 → 適用・検証）
