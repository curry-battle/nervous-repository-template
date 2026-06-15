# 導入ガイド（LLM 向けプレイブック）

このドキュメントは **AI エージェント（Claude / Codex 等）向け**の指示書です。
ユーザが「このリポジトリを真似したい」「このリポジトリの XXX を取り入れたい」と言ったとき、
**勝手にコピーせず、この手順で AskUser しながら**対象リポジトリへ移植してください。

- 参照は **ファイル単位**で示す（行番号は時間で陳腐化するので書かない）。実体は各ファイルを読むこと。
- 設定の中身（type 語彙・cooldown 日数など）は**必ず AskUser で決めてから**書く。デフォルトを黙って流用しない。
- lockfile（`mise.lock` / `pnpm-lock.yaml`）や `mise.lock` の checksum、action の SHA は**コピーせず対象環境で生成/解決し直す**。
- 設計の背景は [design.md](./design.md) を参照。

---

## 進め方（4 ステップ）

### Step 1. 何を取り込むか AskUser（モジュール選択・multiSelect）

下の「モジュール一覧」を選択肢にして AskUser する。`header` 例: `導入モジュール`。
推奨プリセットを先頭に置く:

- **コア（推奨）**: A 規約強制 + B PR title + C リリース自動化 + L 語彙自己テスト
- **セキュリティ一式**: D / E / F / G / I / J（pinact / hook-rev / mise-lock / Renovate / ghalint / gitleaks）
- **Docker**: K
- **リポ整備**: M

### Step 2. 依存解決とコンフリクト確認

選択結果から**依存モジュール**を補い、対象リポジトリの既存設定との衝突を洗い出してユーザに伝える
（例: 既に Dependabot がある→G と二重になる、既に release 方式がある 等）。

### Step 3. モジュール別に「設定の中身」を AskUser

各モジュールの「決める項目」を AskUser する（下記の各節に質問形と選択肢を用意）。
**横断的な決定**（複数モジュールに効く）は最初にまとめて聞く:

- **type 語彙**（A/B/C/L で共有する唯一の正）
- **マージ戦略**（squash 前提か。B/C の設計が変わる）
- **branch 語彙**（Conventional Commits 系 `feat/` か Conventional Branch / Git-Flow `feature/` か）

### Step 4. 適用 → 検証

ファイルをコピー/マージし、決めた値を埋め、**[導入後の検証](#導入後の検証)**を必ず実行する。

---

## モジュール一覧

| ID | モジュール | 主な参照ファイル | 依存 |
|---|---|---|---|
| A | commit / branch の Conventional 強制 | `commit-check.toml`、`.pre-commit-config.yaml`、`mise.toml`、`.github/workflows/pr-validation.yml`(branch-name) | — |
| B | PR title の Conventional 強制 | `.github/workflows/pr-validation.yml`(pr-title) | type語彙 |
| C | リリース自動化 | `.github/release-drafter.yml`、`.github/workflows/release-drafter.yml`、`create-labels.sh` | A/B(語彙) |
| D | GitHub Actions の SHA 固定 | 各 workflow の `uses:`、`pin-actions`ジョブ、`.pre-commit-config.yaml`(pinact)、`mise.toml`(pinact) | — |
| E | pre-commit hook rev の SHA 固定 | `scripts/check-hook-rev-sha.sh`、`pin-hooks`ジョブ、`.pre-commit-config.yaml` | — |
| F | mise ツールの checksum 固定 | `mise.toml`(`[settings]`)、`mise.lock`、`scripts/check-mise-locked.sh`、`mise-locked`ジョブ | — |
| G | 依存更新（Renovate） | `renovate.json5` | 更新対象が存在すること |
| I | workflow セキュリティ lint（ghalint） | `gha-lint`ジョブ、`.pre-commit-config.yaml`、`mise.toml` | — |
| J | secret スキャン（gitleaks） | `gitleaks`ジョブ、`.pre-commit-config.yaml`、`mise.toml` | — |
| K | Docker ベストプラクティス + digest 固定 | `examples/node-app/*`、`docker`ジョブ、`scripts/check-docker-digests.sh`、`.pre-commit-config.yaml`(pin-docker)、`renovate.json5`(`docker:pinDigests`) | — |
| L | type 語彙の自己テスト | `scripts/check-vocab-sync.sh`、`.pre-commit-config.yaml`（prek hook のみ。当該ファイル変更時に発火） | A/B/C |
| M | リポ整備 | `.github/ISSUE_TEMPLATE/*`、`.github/pull_request_template.md`、`LICENSE`、`.gitignore` | — |

> 共通基盤：A〜L の多くは **prek（ローカルフック）+ mise（ツール固定）** に乗る。最初に `mise.toml` と `.pre-commit-config.yaml` の土台を用意し、各モジュールの hook を足していく構成が楽。

---

## モジュール別：AskUser する決定と注意

### A. commit / branch の Conventional 強制
- 参照: `commit-check.toml`、`.pre-commit-config.yaml`(commit-check リポフック + `check-hook-rev-sha`)、`mise.toml`(prek)
- AskUser:
  - **type 語彙**（横断・最初に確定）: 標準セット(feat/fix/docs/refactor/perf/test/build/ci/chore/revert) / 最小 / その他
  - **branch 語彙**: Conventional Commits 系(`feat/...`) / Conventional Branch・Git-Flow(`feature/...`)
  - **commit message の強制場所**: ローカル(prek)のみ / CI でも
- 注意: 既定ブランチ(`main`)は `allow_branch_names` で除外。bot は `ignore_authors`。

### B. PR title の Conventional 強制
- 参照: `.github/workflows/pr-validation.yml`(pr-title ジョブ)
- AskUser:
  - **マージ戦略**（横断）: Squash（PR title=main commit）か否か
  - **scope**: 任意・自由記述 / 必須・allowlist / 禁止
  - **subject 厳格度**: 最小(type形式のみ) / 整形ルール追加
  - **required check 化**するか
- 注意: types は **A の type 語彙と一致**させる。

### C. リリース自動化（release-drafter）
- 参照: `.github/release-drafter.yml`、`.github/workflows/release-drafter.yml`、`create-labels.sh`
- AskUser:
  - **章構成**: 集約型 / 主要のみ表示
  - **version-resolver**: default patch / default no-bump
  - **破壊的変更検出**: title `!` + body footer / `!` のみ
  - **fork PR**: `pull_request` のみ(fork 非対応) / `pull_request_target`・App
- 注意（落とし穴）:
  - **`categories[].exclusive` は v6 系では非対応**。二重分類防止は **autolabeler 側で type 正規表現を排他化**（type 規則は `!` を含めず `:` で終端、`feat!:` は breaking のみ）で行う。
  - autolabeler は**加算のみ**（stale ラベルを外さない）。
  - ラベルは `create-labels.sh` で作る（`feat:`→ラベルは **`feature`**）。
  - 初回は基準 tag が無いと semver 算出不可。手動で `v0.1.0` を作る。

### D. GitHub Actions の SHA 固定（pinact）
- 参照: 各 workflow の `uses:`、`pin-actions`ジョブ、`.pre-commit-config.yaml`(pinact)、`mise.toml`(pinact)
- AskUser:
  - CI の `pin-actions` 検証ジョブを置く / GitHub 純正 **Enforce SHA pinning** に任せる / 両方
- 注意: SHA は**対象リポで解決し直す**（コピー禁止）。pinact は Docker 非対応。

### E. pre-commit hook rev の SHA 固定
- 参照: `scripts/check-hook-rev-sha.sh`、`pin-hooks`ジョブ、`.pre-commit-config.yaml`
- AskUser: 特になし（採用 or 不採用）。Renovate(G) があれば更新は自動。

### F. mise ツールの checksum 固定
- 参照: `mise.toml`(`[settings] lockfile/locked`)、`mise.lock`、`scripts/check-mise-locked.sh`、`mise-locked`ジョブ
- AskUser:
  - 管理するツール一覧
  - lock するプラットフォーム（CI=linux-x64、開発機=macos-arm64 等）
- 注意: **`mise.lock` はコピーせず `mise lock --platform ...` で生成**してコミット。`locked=true` は lockfile コミット後に有効。CI 検証は `mise install` ではなく**静的検証**にする（PR の任意コード実行を避ける）。

### G. 依存更新（Renovate）
- 参照: `renovate.json5`
- AskUser:
  - **実行方式**: Mend ホスト型 App / self-hosted(GHA)。self-hosted は `GITHUB_TOKEN` だと PR が CI を発火しないため**別アイデンティティのトークン必須**
  - **cooldown 日数**: `minimumReleaseAge`（既定 7d、major 14d 等）
  - **automerge**: しない / digest・patch のみ限定解禁
- 注意: Dependabot と同 ecosystem で併走させない。pre-commit / mise / docker manager を有効化。`@types/node` 等は runtime メジャーに合わせる `allowedVersions` を検討。

### I. workflow セキュリティ lint（ghalint）
- 参照: `gha-lint`ジョブ、`.pre-commit-config.yaml`、`mise.toml`
- AskUser: 特になし。ghalint のポリシー（`permissions` 最小化・`timeout-minutes` 必須・SHA 固定）に合わせて**既存 workflow の修正が必要**になる点を伝える。
- 注意: CI は **固定版を checksum 検証して実行**（mise-action 等で PR 設定を信頼しない）。

### J. secret スキャン（gitleaks）
- 参照: `gitleaks`ジョブ、`.pre-commit-config.yaml`、`mise.toml`
- AskUser: `.gitleaks.toml`(allowlist) を使うか。
- 注意: 導入時に **一度 `gitleaks dir .` を実行して誤検知を確認**（lockfile のハッシュ等）。誤検知が出たら allowlist を作る。

### K. Docker ベストプラクティス + digest 固定
- 参照: `examples/node-app/*`(サンプル)、`docker`ジョブ、`scripts/check-docker-digests.sh`、`.pre-commit-config.yaml`(pin-docker)、`renovate.json5`(`docker:pinDigests`)
- AskUser:
  - **サンプルごと入れる / チェックだけ入れる**
  - パッケージマネージャ・言語（pnpm/TS 等）
- 注意: base image の digest は**対象環境で解決**（`docker buildx imagetools inspect <image:tag>`）。`pnpm-lock.yaml` はコピーせず再生成。

### L. type 語彙の自己テスト
- 参照: `scripts/check-vocab-sync.sh`、`.pre-commit-config.yaml`（**prek hook のみ。CI には載せない**＝毎 PR 実行は過剰。当該ファイル変更時のみ発火）
- 注意: A/B/C を入れた場合のみ意味を持つ。スクリプトは語彙の抽出元（4 箇所）が対象リポの構成と一致しているか調整する。

### M. リポ整備
- 参照: `.github/ISSUE_TEMPLATE/*`、`.github/pull_request_template.md`、`LICENSE`、`.gitignore`
- AskUser: **ライセンス種別**、PR/issue テンプレの要否。
- 注意（落とし穴）: PR テンプレ本文に **`BREAKING CHANGE:` という文字列を書かない**（C の body autolabeler に一致して全 PR が breaking 扱いになる）。"!" を使う旨の表現にする。

---

## 導入後の検証

取り込んだモジュールに応じて、このリポと同じ検証を回す:

- `actionlint .github/workflows/*.yml`（ワークフロー構文）
- `ghalint run`（I を入れた場合。既存 workflow がポリシー違反なら修正）
- `gitleaks dir .`（J を入れた場合。誤検知確認）
- `bash scripts/check-*.sh`（導入した自己チェックの正常系・負例）
- `mise install`（F。`locked=true` 下で通ること）
- Docker を入れたら `docker build` + 起動 + healthcheck、`docker compose config -q`
- Renovate を入れたら `renovate-config-validator`

---

## 既知の落とし穴チェックリスト（コピー時に必ず確認）

- [ ] PR テンプレに `BREAKING CHANGE:` の文字列を残していない（M×C）
- [ ] release-drafter のバージョンに `categories[].exclusive` が**対応しているか**。v6 系なら autolabeler 排他化で代替
- [ ] `mise.lock` / `pnpm-lock.yaml` を**コピーせず生成**した
- [ ] action の SHA・base image digest を**対象環境で解決**した
- [ ] `prek install` に **`--hook-type pre-commit`** を含めた（ローカルフックは pre-commit 既定）
- [ ] mise-locked / pin 系の CI 検証は **静的**（PR で `mise install` 等の実行をしない）
- [ ] type 語彙が A/B/C/L の参照箇所で一致（L の自己テストで担保）
