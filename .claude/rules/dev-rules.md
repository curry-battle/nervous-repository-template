# 開発ルール

## Branch 

Conventional Branch 規約に従う。  
原則Issueに紐づけてブランチを作成する。

## Commit 

Conventional Commits 規約に従う。

## PR

### Title

PR title は Conventional Commits 形式で書く。  
PR title は Squash merge の commit message にそのまま使われる。  
これは Release Please により、CHANGELOG の 1 行としても使われる。

### Body

- 本文に **`BREAKING CHANGE:` というリテラル文字列を書かない**
- 理由: squash 設定が "PR title and description" の場合、PR body がコミットメッセージに含まれ、Release Please が `BREAKING CHANGE:` footer として検出し breaking change 扱いにする
- 破壊的変更は title の `!` で表現する（例: `feat!:`）

## type 語彙

Conventional Commits/Branch, PR title, Release Please の type 語彙は 以下の 3 箇所で**同期している**。

1. `commit-check.toml`
  - `allow_commit_types`
2. `release-please-config.json`
  - `changelog-sections[].type`
3. `.github/workflows/pr-validation.yml`
  - `pr-title` ジョブの `types`

→ どれか変更したら **全部更新**。`scripts/check-vocab-sync.sh`（prek pre-commit hook、当該ファイル変更時のみ発火）が差分を検出する。
