# 設計ドキュメント

概要は [README](../README.md)。ここでは設計判断と運用上の注意だけをまとめる。

## 思想

1. **語彙を 1 つに統一**：Conventional Commits の type を唯一の正とし、branch / commit / PR title / リリース分類を全部そこに揃える。
2. **機械で縛る**：規約は CI とローカルフック（prek）で強制。違反はマージ前に弾く。
3. **自動で安全に保つ**：リリースは規約から自動生成。外部 Actions は SHA 固定、依存更新は cooldown 付き。

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

- scope は任意で自由記述（`feat(api):` も可）。default semver は patch。
- **type 語彙を変えるときは 4 箇所すべて更新**：`release-drafter.yml`(autolabeler) ／ `commit-check.toml`(allow_commit_types / allow_branch_types) ／ `pr-validation.yml`(semantic-pull-request の types)。ツールごとに設定が独立しており DRY 化できないが、**prek hook（`scripts/check-vocab-sync.sh`、当該ファイルを編集した commit でのみ発火）が 4 箇所の一致を検証**するためドリフトは検知される（CI では回さない＝毎 PR 実行は過剰なため）。

## 仕組み

```
   branch           commit msg       PR title         (squash で main の commit)
   feat/xxx         feat: ...        feat: ...  ──► PR title がそのまま履歴に
      │                │                │
   commit-check     commit-check     semantic-pr     release-drafter:
   pre-push hook    commit-msg hook  required         autolabeler が
   (prek, local)    (prek, local)    check            PR title → label → 分類 / semver
```

- **commit-check**：branch 名は pre-push hook、commit message は commit-msg hook で検証（ともに prek、ローカルのみ）。CI では検証しない（branch 名は squash で main に残らずリリースノートにも影響しないため、CI で必須化するほどの保護対象ではない）。
- **release-drafter**：分類キーは「ラベル」。`autolabeler` が PR title から `feat:` → `feature` ラベルを付与し、categories と version-resolver がラベルで分類し semver を判定する。

## リリースの流れ

1. Conventional な title の PR を `main` に **Squash** マージ
2. `release-drafter` が push:main で **ドラフト Release** を更新（version / notes を算出）
3. ドラフトを **publish** → その瞬間に tag（`v$RESOLVED_VERSION`）が打たれる

> 初回だけ既存 tag が無いと基準を取れないので、手動で `v0.1.0` を作る。

## サプライチェーン対策

### 依存更新（Renovate）

- **依存更新（`renovate.json5`）**：cooldown（`minimumReleaseAge: 7d` + `internalChecksFilter: strict`、major は 14d）／ `pinDigests` で Actions と hook を SHA 維持 ／ `automerge: false`（人がレビュー）／ 脆弱性のみ cooldown なしで早期取り込み。
- **Renovate は Mend ホスト型 App 前提**。`GITHUB_TOKEN` の self-hosted だと Renovate PR が CI/autolabeler を発火しない。
- **依存更新 PR ≒ 安全**：CI は依存の install/build/test をしない（hook と mise は CI 非実行）。実行され得るのは `uses:` の Action のみで、cooldown、最小権限、secret なしで緩和済み。アプリコードを足して CI で依存を実行し始めたら別途要対策。

### 依存の監査（cargo-deny / trivy / pnpm audit）

依存の既知脆弱性・ライセンス・誤設定を検出する。**いずれも「依存コードをビルド/実行しない」**よう設計し、CI から PR の依存コードを走らせない原則（上記「依存更新 PR ≒ 安全」）を保つ。

- **Rust 依存の監査（cargo-deny）**：`Audit Rust deps (cargo-deny)` ジョブ（固定版を checksum 検証して実行）＋ pre-commit hook。`deny.toml` の advisories（RUSTSEC・unmaintained・yanked）／ licenses（permissive のみ allowlist）／ bans（複数版・wildcard）／ sources（crates.io のみ）を検査する。**`cargo metadata` のみ**を使い build script を走らせない。
- **ファイルシステムスキャン（trivy）**：`Scan filesystem (trivy)` ジョブ（固定版を checksum 検証 → `trivy fs --scanners vuln,misconfig .`）＋ pre-commit hook。lockfile / 設定ファイルの**静的スキャン**（`trivy image` ではないのでイメージのビルド・実行は不要）。
- **npm 依存の監査（pnpm audit）**：`Audit npm deps (pnpm audit)` ジョブ。pnpm は他の監査ツールと同じく aqua 管理（`aqua.yaml` + `aqua-checksums.json` で version と checksum を固定。corepack は使わない＝PR の `packageManager` に CI 実行の pnpm を差し替えさせない）、`examples/docker-node` で `pnpm audit --audit-level high`。**install せず** lockfile を読んで registry の advisory API を問い合わせるだけ。
- **npm 側と Rust 側は守りの置き場所が違う（意図的な非対称）**：`pnpm audit` は**脆弱性（advisory）監査のみ**で、cargo-deny の licenses / bans 相当は持たない。npm 側の広い守りは代わりに**install 時**の `examples/docker-node/pnpm-workspace.yaml` に置いている（cooldown=`minimumReleaseAge`／非標準サブ依存ブロック=`blockExoticSubdeps`（sources 相当を部分カバー）／postinstall 等ライフサイクルスクリプトのブロック=`allowBuilds:{}`／lockfile 整合の fail-closed 検証=`verifyDepsBeforeRun:error`）。一方 Rust 側は cargo がライフサイクルスクリプトの概念が弱く install 時ハードニングが薄いぶん、**audit 時**の `deny.toml` で licenses（許可ライセンス外を CI fail）／ bans（複数版・wildcard）を強制する。結果として **npm 側にはライセンス強制と重複版 bans が無い**（必要なら license-checker 系の CI ステップや `pnpm dedupe --check` を足せる）。`vulnerabilities` は両者で対等。
- ghalint / gitleaks / cargo-deny / trivy / pnpm の 5 監査ツールと、ローカル開発用の prek / pinact を含めた計 7 ツールを aqua で version と checksum を統一管理する（`aqua.yaml` + `aqua-checksums.json` が唯一の SoT）。CI は `aquaproj/aqua-installer` で aqua 自身を SHA pin した上で `aqua install` → `aqua exec -- <tool>` する。Renovate の `aqua-renovate-config` preset が version 追従、`aquaproj/update-checksum-action` が checksum 再生成を担うため、手動 sha256 更新は発生しない。**hadolint は aqua の対象外**：CI は `hadolint/hadolint-action`（SHA pin）、ローカルは `.pre-commit-config.yaml` の remote hook（`rev` SHA pin）で取得・実行する。aqua に載せると 2 経路で管理が分裂するため意図的に除外する。
- **pnpm の二重化（packageManager と aqua.yaml）**: pnpm は CI 監査用 (`aqua.yaml`) と Node example 自身のパッケージマネージャ宣言 (`examples/docker-node/package.json` の `packageManager`) の 2 系統に残る (別 consumer なので両方必要)。両者のドリフトは `scripts/check-pnpm-aqua-sync.sh` (CI ジョブ `pnpm-aqua-sync` + pre-commit hook) で検出して fail させる。

### CI ワークフローのハードニング

- **CI workflow**：checkout は `persist-credentials: false` ／ `contents: read` 起点、secret なし、`pull_request_target` 不使用 ／ 各ジョブに `timeout-minutes`。
- **workflow のセキュリティ lint（ghalint）**：`gha-lint` ジョブ（固定版を checksum 検証して実行）＋ pre-commit hook。permissions 最小化、`timeout-minutes` 必須、SHA 固定などのポリシーを強制（pinact と同じ作者で思想一致。pinact=pin / ghalint=lint）。
- **secret スキャン（gitleaks）**：`gitleaks` ジョブ（固定版を checksum 検証 → `gitleaks dir .` で作業ツリー全体）＋ pre-commit hook（commit 前に staged 差分を `gitleaks git --staged`）。ハードコードされた secret をマージ前と commit 前に検出。

### 外部依存の SHA と checksum 固定（4 経路）

- **外部依存の SHA と checksum の固定を CI で強制**（5 経路すべて）：

  | 経路 | pin する | 強制（CI ジョブ） |
  |---|---|---|
  | GitHub Actions (`uses:`) | pinact / Renovate(`pinGitHubActionDigests`) | `pin-actions`（pinact-action `fix:false`） |
  | pre-commit hook (`rev`) | 手動 / Renovate | `pin-hooks`（`rev` が 40 桁 SHA か検証） |
  | aqua 管理 CLI ツール | `aqua-checksums.json`（`aqua update-checksum` で生成） | `aqua-checksums`（aqua v2 に `--check` は無いため `aqua update-checksum -prune` 後 `git diff --exit-code aqua-checksums.json` で aqua.yaml との整合と未使用 checksum を検出）／security-audit の各 job は base-branch overlay で信頼済み aqua 設定を実行 |
  | aqua 自身の bootstrap | `mise lock` → `mise.lock`（aqua 1 エントリのみ） | （CI では aqua-installer で別経路 pin。ローカルは `mise install` の locked 検証） |
  | Docker ベースイメージ (`FROM`) | Renovate(`docker:pinDigests`) | `docker`（全 `FROM` が `@sha256:` か検証 + hadolint(recursive) + compose 構文） |

  検査ロジックは `scripts/check-*.sh` に集約し、CI と prek hook が同じ実装を共有する（挙動差や修正漏れの防止）。
- **`aqua install` は CI でも実行する**：手動 `curl` + `sha256sum -c` の置換として `aquaproj/aqua-installer` で aqua 自身を SHA pin した上で `aqua install` → `aqua exec -- <tool>` する。aqua はパッケージ取得とハッシュ検証のみを行い、パッケージ固有の installer スクリプトは実行しない（`require_checksum: true` で fail-closed）。
- **base-branch config overlay（ハードニング）**：`pull_request` イベントの aqua-exec ジョブは PR head ではなく信頼済み base branch の `aqua.yaml` / `aqua-checksums.json` を使う。これにより PR が自分の CI でツールを攻撃者バイナリに差し替える経路を断つ。`push: main` では base==実行 ref なので overlay は no-op になり、ツール bump の post-merge 実機検証として機能する。
- **trust model（正直版・必ず読む）**：`pull_request` の CI は **PR head の workflow / local action 定義で走る**。overlay/guard step を含む `security-audit.yml` 自体も PR が改変できるため、**PR run は advisory** と位置付ける。advisory でも価値は残る—secret 不付与・`GITHUB_TOKEN` は read-only・public source のみで blast radius を限定する。merge は **CODEOWNERS（`aqua.yaml` / `aqua-checksums.json` / `.github/workflows/` / `.github/actions/`） + branch protection の "Require review from Code Owners"** が authoritative なゲート。`push: main` の run は base==実行 ref（信頼済み main）で走り overlay も no-op になるため、ツール bump の **authoritative な post-merge 検証**を担う。
- **overlay/installer を local composite action に括り出さない理由**：overlay は『PR head の aqua 設定を信用しない』ためのもの。そのロジックを PR head から `uses:` で読まれる local action に置くと、PR がその action ファイルを書換えるだけで overlay を no-op 化できる（trust boundary が壊れる）。よって `security-audit.yml` の 5 ジョブに inline で重複させ、同期コメントで保守する。
- **`CODEOWNERS` で aqua 設定 / CI workflow / local action 変更を maintainer レビュー必須に**：`aqua.yaml` / `aqua-checksums.json` / `.github/workflows/` / `.github/actions/` を `.github/CODEOWNERS` 対象にする。default branch の branch protection で "Require review from Code Owners" を ON にしないと無効になる点に注意（hard 条件）。
- **mise の lockfile（bootstrap 専用）**：`mise.toml` は aqua バイナリ 1 本のみを宣言し、`lockfile=true` / `locked=true` で `mise.lock` の checksum 検証を維持する。CLI ツールの実体は `aqua.yaml` + `aqua-checksums.json` に集約済み。
- **aqua 自身のバージョン更新は手動同期**：aqua のバージョン番号は `mise.toml` (`aqua = "x.y.z"`) と各 workflow の `aqua-installer` step (`aqua_version: vx.y.z`) の 2 箇所に存在する。aqua-renovate-config は `aqua.yaml` の packages を追従する preset で、aqua バイナリ自身の版には触らない。よって aqua のメジャー/マイナー bump は両所を手動で揃える運用（`mise install` でローカル整合 → CI でも同じ版が使えるよう workflow を一括置換）。

### 手動での補強（推奨）

- **（推奨・補強・要手動）GitHub 純正 [Enforce SHA pinning](https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/)**：org/repo の allowed actions ポリシーで有効化すると、未 pin の action を含む workflow を **実行時にブロック**（迂回不可）。リポ外設定なので**手動で有効化する**:
  - Repo: Settings → Actions → General → Allowed actions の下の「Require actions to be pinned to a full-length commit SHA」を ON
  - Org: Organization Settings → Actions → Policies で同様に ON（配下リポへ一括適用）
  - 「弾く」だけで pin はしない（tag→SHA 変換は pinact/Renovate）。reusable workflow は tag 参照のまま許容される点に注意。
- **（推奨・要手動・ワンショット）[StepSecurity secure-repo](https://app.stepsecurity.io/securerepo) で一度監査**：push 後に対象リポを通すと、未ハードニング箇所（未 pin action や過剰権限など）を検出し修正 PR を提案。本テンプレは既に大半を満たすため、主に取りこぼし確認用。

## 運用上の注意

`autolabeler` は **ラベルを加算するだけで、外さない**（title 編集に再反応はするが加算のまま）。

> PR title の type を後から書き換えたら（例 `feat:`→`fix:`）、**古いラベルを手動で外す**。

pin している release-drafter v6 は `categories[].exclusive` 非対応のため、二重分類は **autolabeler の type 正規表現を排他化**して防いでいる（type 規則は `!` を含めず、`feat!:`/`fix!:` は breaking のみに一致）。例外として `feat:` + 本文 `BREAKING CHANGE` フッター併用時は feature+breaking の二重ラベルになり得る（semver は major で正しく、表示のみ重複）。なお stale ラベルを放置すると version-resolver が最大を採って semver がズレる点は同様に手動対応。

## ファイル一覧

| ファイル | 役割 |
|---|---|
| `.github/release-drafter.yml` | categories / autolabeler / version-resolver |
| `.github/workflows/release-drafter.yml` | push:main でドラフト更新、PR で autolabel |
| `.github/workflows/pr-validation.yml` | PR の必須チェック（PR title / Actions・hook の pin 検証 / aqua-checksums 整合 / pnpm-aqua-sync / Docker 検証）。aqua-exec を伴う 5 ジョブは `security-audit.yml` に分離。branch 名チェックは廃止済み |
| `.github/workflows/security-audit.yml` | aqua-exec 5 ジョブ（gha-lint / gitleaks / cargo-deny / trivy / pnpm-audit）。`pull_request` では base-branch overlay でツール差し替えを防ぎ、`push: main` でも実行して bump の post-merge 検証を行う |
| `.github/workflows/aqua-update-checksum.yml` | Renovate の aqua.yaml 更新 PR で `aqua-checksums.json` を自動再生成（actor=renovate[bot] + paths ガード） |
| `renovate.json5` | 依存更新（cooldown + digest 固定） |
| `commit-check.toml` | commit / branch の規則 |
| `.pre-commit-config.yaml` | prek フック（commit-check + pinact、`rev` も SHA 固定） |
| `mise.toml` / `mise.lock` | 開発者の手元で aqua バイナリを bootstrap する用途のみ（CLI ツール本体は `aqua.yaml` で管理） |
| `aqua.yaml` / `aqua-checksums.json` | CI/ローカル共通の CLI ツール（prek / pinact / ghalint / gitleaks / cargo-deny / trivy / pnpm）の version・checksum 固定の唯一の SoT。hadolint は `.pre-commit-config.yaml` の remote hook (SHA-pinned rev) で取得し aqua には載せない |
| `.github/CODEOWNERS` | `aqua.yaml` / `aqua-checksums.json` / `.github/workflows/` / `.github/actions/` を maintainer レビュー対象に（branch protection の "Require review from Code Owners" と併用。CI/provisioning と guard を変える PR を maintainer ゲートに通す） |
| `create-labels.sh` | autolabeler 用ラベルの作成/更新 |
| `scripts/check-*.sh` | CI と prek が共有する検査（hook rev / Docker digest / pnpm-aqua sync の静的検証） |
| `examples/docker-node/` | サンプル（Node + pnpm + TypeScript。`pnpm-lock.yaml`・corepack `packageManager` 固定、`pnpm-workspace.yaml` で supply-chain 設定、multi-stage(tsc build) + digest 固定 Dockerfile + compose）。`docker` / `pnpm audit` ジョブの検証対象。README あり |
| `examples/docker-rust/` | サンプル（Docker + Rust。`Cargo.lock` 固定、`cargo build --locked --frozen`、`deny.toml`(cargo-deny)、multi-stage(cargo fetch→offline build→distroless) + digest 固定 Dockerfile + compose）。`docker` / `cargo-deny` / `trivy` ジョブの検証対象。README あり |

## ラベル作成

`autolabeler` 用ラベルを [`create-labels.sh`](../create-labels.sh)（要 `gh`）で作る。`--force` で冪等。

```bash
bash create-labels.sh                 # カレントリポジトリ
REPO=owner/name bash create-labels.sh # 指定
```

> ラベル名は `release-drafter.yml` と一致させること。特に `feat:` → ラベルは **`feature`**。

## 参考

[release-drafter](https://github.com/release-drafter/release-drafter) ／ [commit-check](https://github.com/commit-check/commit-check) ／ [action-semantic-pull-request](https://github.com/amannn/action-semantic-pull-request) ／ [pinact](https://github.com/suzuki-shunsuke/pinact) ／ [Renovate](https://docs.renovatebot.com/)（[cooldown](https://docs.renovatebot.com/key-concepts/minimum-release-age/)）／ [mise](https://mise.jdx.dev/) ／ [prek](https://github.com/j178/prek) ／ [Conventional Commits](https://www.conventionalcommits.org/) ／ [Conventional Branch](https://conventional-branch.github.io/)
