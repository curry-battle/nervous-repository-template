# 設計ドキュメント

概要は [README](../README.md)。ここでは設計判断と運用上の注意だけをまとめる。

## 思想

1. **語彙を 1 つに統一** — Conventional Commits の type を唯一の正とし、branch / commit / PR title / リリース分類を全部そこに揃える。
2. **機械で縛る** — 規約は CI とローカルフック（prek）で強制。違反はマージ前に弾く。
3. **自動で安全に保つ** — リリースは規約から自動生成。外部 Actions は SHA 固定、依存更新は cooldown 付き。

**Squash マージ前提**。PR title = `main` コミット = リリースノートの 1 行になる。

## type 語彙（Single Source of Truth）

| type | リリースノートの章 | semver |
|---|---|---|
| `feat` | 🚀 Features | minor |
| `fix` | 🐛 Bug Fixes | patch |
| `perf` | ⚡ Performance | patch |
| `refactor` | ♻️ Refactoring | patch |
| `docs` / `test` / `build` / `ci` / `chore` / `revert` | 🧰 Maintenance | patch |
| `feat!:` / `fix!:` / `BREAKING CHANGE:` | 💥 Breaking Changes | major |

- scope は任意・自由記述（`feat(api):` も可）。default semver は patch。
- **type 語彙を変えるときは 4 箇所すべて更新**：`release-drafter.yml`(autolabeler) ／ `commit-check.toml`(allow_commit_types / allow_branch_types) ／ `pr-validation.yml`(semantic-pull-request の types)。ツールごとに設定が独立しており DRY 化できないが、**prek hook（`scripts/check-vocab-sync.sh`、当該ファイルを編集した commit でのみ発火）が 4 箇所の一致を検証**するためドリフトは検知される（CI では回さない＝毎 PR 実行は過剰なため）。

## 仕組み

```
   branch 名        各 commit        PR title        (squash で main の commit)
   feat/xxx         feat: ...        feat: ...   ──► PR title がそのまま履歴に
      │                │                │
   commit-check    commit-check    semantic-pr     release-drafter:
   (branch)        (message)       required        autolabeler が
   prek + CI       prek のみ        check           PR title → label → 分類 / semver
```

- **commit-check**：branch はローカル + CI、commit message はローカル(prek)のみ。
- **release-drafter**：分類キーは「ラベル」。`autolabeler` が PR title から `feat:` → `feature` ラベルを付与し、categories と version-resolver がラベルで分類・semver 判定する。

## リリースの流れ

1. Conventional な title の PR を `main` に **Squash** マージ
2. `release-drafter` が push:main で **ドラフト Release** を更新（version / notes を算出）
3. ドラフトを **publish** → その瞬間に tag（`v$RESOLVED_VERSION`）が打たれる

> 初回だけ既存 tag が無いと基準を取れないので、手動で `v0.1.0` を作る。

## サプライチェーン対策

- **依存更新（`renovate.json5`）**：cooldown（`minimumReleaseAge: 7d` + `internalChecksFilter: strict`、major は 14d）／ `pinDigests` で Actions・hook を SHA 維持 ／ `automerge: false`（人がレビュー）／ 脆弱性のみ cooldown なしで早期取り込み。
- **CI workflow**：checkout は `persist-credentials: false` ／ `contents: read` 起点・secret なし・`pull_request_target` 不使用 ／ 各ジョブに `timeout-minutes`。
- **workflow のセキュリティ lint（ghalint）**：`gha-lint` ジョブ（固定版を checksum 検証して実行）＋ prek hook。permissions 最小化・`timeout-minutes` 必須・SHA 固定などのポリシーを強制（pinact と同じ作者で思想一致。pinact=pin / ghalint=lint）。
- **secret スキャン（gitleaks）**：`gitleaks` ジョブ（固定版を checksum 検証 → `gitleaks dir .` で作業ツリー全体）＋ prek hook（commit 前に staged 差分を `gitleaks git --staged`）。ハードコードされた secret をマージ前・commit 前に検出。
- **外部依存の SHA・checksum 固定を CI で強制**（4 経路すべて）：

  | 経路 | pin する | 強制（CI ジョブ） |
  |---|---|---|
  | GitHub Actions (`uses:`) | pinact / Renovate(`pinGitHubActionDigests`) | `pin-actions`（pinact-action `fix:false`） |
  | pre-commit hook (`rev`) | 手動 / Renovate | `pin-hooks`（`rev` が 40 桁 SHA か検証） |
  | mise ツール | `mise lock` → `mise.lock` | `mise-locked`（mise.toml の各 tool が mise.lock に checksum 付きで存在するか**静的に**検証） |
  | Docker ベースイメージ (`FROM`) | Renovate(`docker:pinDigests`) | `docker`（全 `FROM` が `@sha256:` か検証 + hadolint(recursive) + compose 構文） |

  検査ロジックは `scripts/check-*.sh` に集約し、CI と prek hook が同じ実装を共有する（挙動差・修正漏れ防止）。
- **mise-locked は `mise install` を実行しない**：PR 側の mise.toml/mise.lock で任意 installer を走らせる経路を断つため、lockfile を**静的に検証**するだけにしている。`mise.lock` が無ければ失敗（検証の迂回を防ぐ）。実際の install（実行）はローカル開発時のみ。
- **mise の lockfile**：`mise.toml` に `lockfile=true` / `locked=true` を設定し、**`mise.lock`（linux-x64 / macos-arm64 の checksum）をコミット済み**。tool を追加/変更したら `mise lock --platform linux-x64,macos-arm64` で更新する。
- **（推奨・補強・要手動）GitHub 純正 [Enforce SHA pinning](https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/)**：org/repo の allowed actions ポリシーで有効化すると、未 pin の action を含む workflow を **実行時にブロック**（迂回不可）。リポ外設定なので**手動で有効化する**:
  - Repo: Settings → Actions → General → Allowed actions の下の「Require actions to be pinned to a full-length commit SHA」を ON
  - Org: Organization Settings → Actions → Policies で同様に ON（配下リポへ一括適用）
  - 「弾く」だけで pin はしない（tag→SHA 変換は pinact/Renovate）。reusable workflow は tag 参照のまま許容される点に注意。
- **（推奨・要手動・ワンショット）[StepSecurity secure-repo](https://app.stepsecurity.io/securerepo) で一度監査**：push 後に対象リポを通すと、未ハードニング箇所（未 pin action・過剰権限など）を検出し修正 PR を提案。本テンプレは既に大半を満たすため、主に取りこぼし確認用。
- **Renovate は Mend ホスト型 App 前提**。`GITHUB_TOKEN` の self-hosted だと Renovate PR が CI/autolabeler を発火しない。
- **依存更新 PR ≒ 安全**：CI は依存の install/build/test をしない（hook・mise は CI 非実行）。実行され得るのは `uses:` の Action のみで、cooldown・最小権限・secret なしで緩和済み。アプリコードを足して CI で依存を実行し始めたら別途要対策。

## 運用上の注意

`autolabeler` は **ラベルを加算するだけで、外さない**（title 編集に再反応はするが加算のまま）。

> PR title の type を後から書き換えたら（例 `feat:`→`fix:`）、**古いラベルを手動で外す**。

pin している release-drafter v6 は `categories[].exclusive` 非対応のため、二重分類は **autolabeler の type 正規表現を排他化**して防いでいる（type 規則は `!` を含めず、`feat!:`/`fix!:` は breaking のみに一致）。例外として `feat:` + 本文 `BREAKING CHANGE` フッター併用時は feature+breaking の二重ラベルになり得る（semver は major で正しく、表示のみ重複）。なお stale ラベルを放置すると version-resolver が最大を採って semver がズレる点は同様に手動対応。

## ファイル一覧

| ファイル | 役割 |
|---|---|
| `.github/release-drafter.yml` | categories / autolabeler / version-resolver |
| `.github/workflows/release-drafter.yml` | push:main でドラフト更新、PR で autolabel |
| `.github/workflows/pr-validation.yml` | PR title・branch 名・Actions の SHA 固定を検証 |
| `renovate.json5` | 依存更新（cooldown + digest 固定） |
| `commit-check.toml` | commit / branch の規則 |
| `.pre-commit-config.yaml` | prek フック（commit-check + pinact、`rev` も SHA 固定） |
| `mise.toml` / `mise.lock` | 開発 CLI（prek / pinact / hadolint / ghalint / gitleaks）の version・checksum 固定 |
| `create-labels.sh` | autolabeler 用ラベルの作成/更新 |
| `scripts/check-*.sh` | CI と prek が共有する検査（hook rev / Docker digest / mise lock の静的検証） |
| `examples/node-app/` | サンプル（Node + pnpm + TypeScript。`pnpm-lock.yaml`・corepack `packageManager` 固定、`pnpm-workspace.yaml` で supply-chain 設定、multi-stage(tsc build) + digest 固定 Dockerfile + compose）。`docker` ジョブの検証対象。README あり |

## ラベル作成

`autolabeler` 用ラベルを [`create-labels.sh`](../create-labels.sh)（要 `gh`）で作る。`--force` で冪等。

```bash
bash create-labels.sh                 # カレントリポジトリ
REPO=owner/name bash create-labels.sh # 指定
```

> ラベル名は `release-drafter.yml` と一致させること。特に `feat:` → ラベルは **`feature`**。

## 参考

[release-drafter](https://github.com/release-drafter/release-drafter) ／ [commit-check](https://github.com/commit-check/commit-check) ／ [action-semantic-pull-request](https://github.com/amannn/action-semantic-pull-request) ／ [pinact](https://github.com/suzuki-shunsuke/pinact) ／ [Renovate](https://docs.renovatebot.com/)（[cooldown](https://docs.renovatebot.com/key-concepts/minimum-release-age/)）／ [mise](https://mise.jdx.dev/) ／ [prek](https://github.com/j178/prek) ／ [Conventional Commits](https://www.conventionalcommits.org/) ／ [Conventional Branch](https://conventional-branch.github.io/)
