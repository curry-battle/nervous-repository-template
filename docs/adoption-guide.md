# 導入ガイド（LLM 向けプレイブック）

このドキュメントは **AI エージェント（Claude / Codex 等）向け**の指示書です。
ユーザが「このリポジトリを真似したい」「このリポジトリの XXX を取り入れたい」と言ったとき、
**勝手にコピーせず、この手順で AskUser しながら**対象リポジトリへ移植してください。

- 参照は **ファイル単位**で示す（行番号は時間で陳腐化するので書かない）。実体は各ファイルを読むこと。
- 設定の中身（type 語彙や cooldown 日数など）は**必ず AskUser で決めてから**書く。デフォルトを黙って流用しない。
- lockfile（`mise.lock` / `pnpm-lock.yaml` / `aqua-checksums.json`）や action の SHA は**コピーせず対象環境で生成/解決し直す**（生成コマンドは各モジュール節に記載）。
- **共有ファイルは丸ごとコピーしない**。`pr-validation.yml` / `aqua-validate.yml` / `.pre-commit-config.yaml` / `mise.toml` / `aqua.yaml` / `renovate.json5` は複数モジュールが同居する。選んだモジュールに対応する **job / hook / tool / 設定ブロックだけを抜き出して**マージする（各節の「抜き出すもの」を見る）。無関係な job を持ち込むと、未導入のスクリプトやツールを参照して壊れる。
- **共通基盤（下表の `0`）を最初に置く**。ローカルフック系（A/D/E/H/I/J/K/M）は prek に、ツール固定系（D/F/H/I/J/M）は aqua（CI/ローカル共通）に乗る（mise は aqua バイナリの bootstrap のみ）。基盤を用意してから各モジュールの hook / tool を足す。
- 設計の背景は [design.md](./design.md) を参照。

---

## 進め方（4 ステップ）

### Step 1. 何を取り込むか AskUser（モジュール選択・multiSelect）

下の「モジュール一覧」を選択肢にして AskUser する。`header` 例: `導入モジュール`。
推奨プリセットを先頭に置く:

- **開発フロー（コア・推奨）**: A 規約強制 + B PR title + C リリース自動化 + K 語彙自己テスト
- **セキュリティ・環境**: D / E / F / G / H / I（pinact / hook-rev / mise-lock / Renovate / ghalint / gitleaks）
- **セキュリティ・環境（Docker・任意）**: J
- **セキュリティ・環境（依存監査・任意）**: M（cargo-deny / trivy / pnpm audit。example を使うなら J と併用）
- **リポ整備**: L

### Step 2. 依存解決とコンフリクト確認

選択結果から**依存モジュール**を補い（多くは基盤 `0` が要る）、対象リポジトリの既存設定との衝突を洗い出してユーザに伝える。例:

- 既に Dependabot がある → G と二重になる
- 既に release 方式がある → C と衝突
- 既存 workflow が未 pin / 過剰権限 → H（ghalint）が落ちるので D 相当の pin と権限最小化が先に要る
- prek / mise を未導入 → 基盤 `0` を先に立てる

### Step 3. モジュール別に「設定の中身」を AskUser

各モジュールの「決める項目」を AskUser する（下記の各節に質問形と選択肢を用意）。
**横断的な決定**（複数モジュールに効く）は最初にまとめて聞く:

- **type 語彙**（A/B/C/K で共有する唯一の正）
- **マージ戦略**: このテンプレは **Squash 専用**設計（PR title = `main` コミット = リリースノート 1 行）。非 Squash を選ぶ場合、B/C はそのままでは意図通り機能せず別実装が要る（このテンプレには含まれない）。非 Squash を本当に使うなら、その実装まで設計する覚悟があるか確認する。
- **branch 語彙**（Conventional Commits 系 `feat/` か Conventional Branch / Git-Flow `feature/` か）

### Step 4. 適用 → 検証

ファイルをコピー/マージし、決めた値を埋め、**[導入後の検証](#導入後の検証)**を必ず実行する。

---

## モジュール一覧

区分は README「包含されるもの」の 2 グループ（開発フロー / セキュリティ・環境）に対応する。

| 区分 | ID | モジュール | 主な参照ファイル | 依存 |
|---|---|---|---|---|
| 基盤 | 0 | 共通基盤（prek + aqua、mise は aqua bootstrap 用） | `.pre-commit-config.yaml`、`aqua.yaml`、`aqua-checksums.json`、`mise.toml` | — |
| 開発フロー | A | commit / branch の Conventional 強制 | `commit-check.toml`、`.pre-commit-config.yaml`（prek の commit-msg / pre-push hook のみ。CI では検証しない） | 0 |
| 開発フロー | B | PR title の Conventional 強制 | `.github/workflows/pr-validation.yml`(pr-title) | type語彙 |
| 開発フロー | C | リリース自動化 | `.github/release-drafter.yml`、`.github/workflows/release-drafter.yml`、`create-labels.sh` | A/B(語彙) |
| セキュリティ・環境 | D | GitHub Actions の SHA 固定 | 各 workflow の `uses:`、`pin-actions`ジョブ、`.pre-commit-config.yaml`(pinact)、`aqua.yaml`(pinact) | 0（ローカル hook 利用時） |
| セキュリティ・環境 | E | pre-commit hook rev の SHA 固定 | `scripts/check-hook-rev-sha.sh`、`pin-hooks`ジョブ、`.pre-commit-config.yaml` | 0（`.pre-commit-config.yaml` が前提） |
| セキュリティ・環境 | F | aqua ツールの checksum 固定 | `aqua.yaml`、`aqua-checksums.json`、`aqua-checksums`ジョブ、`.github/workflows/aqua-update-checksum.yml`、`.github/CODEOWNERS` | 0（aqua） |
| セキュリティ・環境 | G | 依存更新（Renovate） | `renovate.json5` | 更新対象が存在すること |
| セキュリティ・環境 | H | workflow セキュリティ lint（ghalint） | `aqua-validate.yml`(gha-lint)、`.pre-commit-config.yaml`、`aqua.yaml` | 0、D 推奨（未 pin と衝突） |
| セキュリティ・環境 | I | secret スキャン（gitleaks） | `aqua-validate.yml`(gitleaks)、`.pre-commit-config.yaml`、`aqua.yaml` | 0 |
| セキュリティ・環境 | J | Docker ベストプラクティス + digest 固定 | `examples/docker-node/*`・`examples/docker-rust/*`、`docker`ジョブ、`scripts/check-docker-digests.sh`、`.pre-commit-config.yaml`(pin-docker)、`renovate.json5`(`docker:pinDigests`) | 0（prek hook 利用時） |
| セキュリティ・環境 | M | 依存監査（cargo-deny / trivy / pnpm audit） | `aqua-validate.yml`(cargo-deny / trivy / pnpm-audit)、`pnpm-aqua-sync`ジョブ、`.pre-commit-config.yaml`(cargo-deny / trivy / check-pnpm-aqua-sync hook)、`aqua.yaml`(cargo-deny / trivy / pnpm)、`examples/docker-rust/deny.toml`、`examples/docker-node/pnpm-workspace.yaml`、`scripts/check-pnpm-aqua-sync.sh` | 0（prek hook 利用時）、J（example を使うなら） |
| 開発フロー | K | type 語彙の自己テスト | `scripts/check-vocab-sync.sh`、`.pre-commit-config.yaml`（pre-commit hook のみ。当該ファイル変更時に発火） | 0 + A/B/C |
| リポ整備 | L | リポ整備 | `.github/ISSUE_TEMPLATE/*`、`.github/pull_request_template.md`、`LICENSE`、`.gitignore` | — |

> 基盤（`0`）：prek が A/D/E/H/I/J/K/M のローカルフックを動かし、aqua が D/F/H/I/J/M の CLI を固定・checksum 検証する（CI もローカルも同じ `aqua.yaml`/`aqua-checksums.json` を参照）。mise は aqua バイナリ自身を bootstrap する用途のみ。最初に `.pre-commit-config.yaml` / `aqua.yaml` / `aqua-checksums.json` / `mise.toml` の土台を置き、各モジュールの hook / tool をそこへ足していく。CI だけで完結するモジュール（B/C/G、および D/H/I/J を「CI ジョブのみ」で使う場合）は基盤なしでも動くが、ローカルフックを使うなら基盤が要る。

> **抜き出し方の原則**：`pr-validation.yml` は job 単位（`pr-title` / `pin-actions` / `pin-hooks` / `aqua-checksums` / `pnpm-aqua-sync` / `docker`）、`aqua-validate.yml` は aqua-exec ジョブ単位（`gha-lint` / `gitleaks` / `cargo-deny` / `trivy` / `pnpm-audit`）で分離できる。選んだモジュールの job だけを対象リポの workflow にコピーする。`.pre-commit-config.yaml` は hook の `id` 単位、`aqua.yaml` は `packages[]` の行単位、`mise.toml` は `[tools]` の行単位、`renovate.json5` は manager / 設定ブロック単位で抜く。各 job / hook が参照する `scripts/check-*.sh` も同時に持ち込む。

---

## モジュール別：AskUser する決定と注意

### 0. 共通基盤（prek + aqua、mise は aqua bootstrap 用）
- 参照: `.pre-commit-config.yaml`、`aqua.yaml`、`aqua-checksums.json`、`mise.toml`、`mise.lock`
- 抜き出すもの: `.pre-commit-config.yaml` の骨組み（`repos:` と各モジュールの hook を足す器）、`aqua.yaml` の `packages[]`（各モジュールが使う CLI）と `registries` / `checksum` ブロック、`mise.toml`（aqua バイナリの 1 エントリのみ）と `[settings]`。
- 手順（bootstrap 順序に注意）:
  - `mise.toml` に aqua 1 行を宣言する（CLI ツールは `aqua.yaml` 側に列挙する）。このとき `[settings] locked` は**省略 or `false`** にしておく（`mise.lock` が無い状態で `locked=true` だと `mise install` が失敗する）。
  - `mise install` → `mise lock --platform linux-x64,macos-arm64` で `mise.lock` を生成してコミット → そのうえで `[settings]` に `lockfile=true` / `locked=true` を有効化する。
  - `aqua.yaml` を作り、`aqua update-checksum` で `aqua-checksums.json` を生成・コミット（**手書き禁止**）。`aqua install` が `linux/amd64` と `darwin/arm64` の両方で通ることを確認（= F）。
  - `mise exec -- prek install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push` で hook を有効化。**pre-commit を必ず含める**（pinact / ghalint / gitleaks / hadolint / vocab / check-pnpm-aqua-sync は pre-commit ステージ。これを外すと D/H/I/J/K/M のローカルフックが発火しない）。
- 注意: 基盤なしで「CI ジョブのみ」運用も可能だが、その場合ローカルフックは付かない（commit 前の早期検知が無くなる）。aqua 未 bootstrap な開発機では各ローカル CLI hook は `command -v aqua` で skip メッセージを出して commit はブロックしない（CI が強制する）。

### A. commit / branch の Conventional 強制
- 参照: `commit-check.toml`、`.pre-commit-config.yaml`(commit-check リポフック + `check-hook-rev-sha`)、`mise.toml`(prek)
- 抜き出すもの: `commit-check.toml` 全体 + `.pre-commit-config.yaml` の `commit-check` リポブロック（`check-message`=commit-msg / `check-branch`=pre-push）。
- AskUser:
  - **type 語彙**（横断・最初に確定）: 標準セット(feat/fix/docs/refactor/perf/test/build/ci/chore/revert) / 最小 / その他
  - **branch 語彙**: Conventional Commits 系(`feat/...`、type 語彙をそのまま branch prefix に流用) / Conventional Branch・Git-Flow(`feature/...`、type とは別語彙)。後者を選ぶ場合は `commit-check.toml` の `[branch] allow_branch_types`（または `conventional_branch`）を `feature`/`hotfix` 等に置き換える。type 語彙（feat/fix…）の単一の正とは**別系統の語彙になる**点を明示する（K の語彙自己テストは commit/PR/リリースの type を対象にし、branch 語彙は別管理）。
- 注意: commit / branch とも **commit-msg / pre-push hook（prek、ローカル）でのみ検証**。このテンプレに CI 検証ジョブは無い（branch 名は squash で main に残らないため）。CI でも強制したい場合は commit-check-action 等を別途追加する必要があり、このテンプレには**含まれない**。既定ブランチ(`main`)は `allow_branch_names` で除外。bot は `ignore_authors`。

### B. PR title の Conventional 強制
- 参照: `.github/workflows/pr-validation.yml`(pr-title ジョブ)
- 抜き出すもの: `pr-validation.yml` の `pr-title` ジョブのみ（`permissions: pull-requests: read` も一緒に）。対象リポに workflow が無ければ pr-title ジョブだけの新規 workflow を作る。
- AskUser:
  - **scope**: 任意・自由記述 / 必須・allowlist / 禁止
  - **subject 厳格度**: 最小(type形式のみ) / 整形ルール追加
  - **required check 化**するか（横断の Branch protection チェックリストへ）
- 注意: types は **A の type 語彙と一致**させる。マージ戦略は横断決定（Squash 専用）に従う。

### C. リリース自動化（release-drafter）
- 参照: `.github/release-drafter.yml`、`.github/workflows/release-drafter.yml`、`create-labels.sh`
- 抜き出すもの: `release-drafter.yml`(設定) + `workflows/release-drafter.yml`(push:main でドラフト更新、PR で autolabel) + `create-labels.sh`。3 点セットで持ち込む。
- AskUser:
  - **章構成**: 集約型 / 主要のみ表示
  - **version-resolver**: default patch / default no-bump
  - **破壊的変更検出**: title `!` + body footer / `!` のみ
  - **fork PR ラベリング**: `pull_request` のみ（fork からの PR は `GITHUB_TOKEN` が read-only になりラベル付与が失敗しうる。fork 非対応で割り切る） / `pull_request_target` または GitHub App。autolabel は PR title しか見ないので **PR のコードは checkout しない**（ラベル操作のみ）。`pull_request_target` で untrusted な PR head を checkout してビルド/スクリプトを走らせるのが最も危険なパターンなので避ける。やむを得ず checkout する場合もビルド・任意コード実行をジョブに入れず、付与権限は `pull-requests: write` 最小、`persist-credentials: false`
- 注意（落とし穴）:
  - **`categories[].exclusive` は v6 系では非対応**。二重分類防止は **autolabeler 側で type 正規表現を排他化**（type 規則は `!` を含めず `:` で終端、`feat!:` は breaking のみ）で行う。
  - autolabeler は**加算のみ**（stale ラベルを外さない）。
  - ラベルは `create-labels.sh` で作る（`feat:`→ラベルは **`feature`**）。
  - 初回は基準 tag が無いと semver 算出不可。手動で `v0.1.0` を作る。

### D. GitHub Actions の SHA 固定（pinact）
- 参照: 各 workflow の `uses:`、`pin-actions`ジョブ、`.pre-commit-config.yaml`(pinact)、`mise.toml`(pinact)
- 抜き出すもの: `pr-validation.yml` の `pin-actions` ジョブ + `.pre-commit-config.yaml` の pinact ローカル hook + `mise.toml` の `pinact` 行。
- 生成: 対象リポで `mise exec -- pinact run` を実行すると、全 workflow の `uses:` をタグから full SHA に書き換える（コピーした SHA はそのまま使わない）。
- AskUser:
  - CI の `pin-actions` 検証ジョブを置く / GitHub 純正 **Enforce SHA pinning** に任せる / 両方
- 注意: SHA は**対象リポで解決し直す**（コピー禁止）。pinact は Docker 非対応（ベースイメージは J の digest 固定で守る）。

### E. pre-commit hook rev の SHA 固定
- 参照: `scripts/check-hook-rev-sha.sh`、`pin-hooks`ジョブ、`.pre-commit-config.yaml`
- 抜き出すもの: `pr-validation.yml` の `pin-hooks` ジョブ + `scripts/check-hook-rev-sha.sh`。
- 生成: `.pre-commit-config.yaml` の各 `rev:` を full SHA に固定する。`mise exec -- prek auto-update --freeze` でタグ→SHA に凍結できる（pre-commit を使う場合は `pre-commit autoupdate --freeze`。サブコマンド名が prek=`auto-update` / pre-commit=`autoupdate` で異なる点に注意）。
- AskUser: 特になし（採用 or 不採用）。Renovate(G) があれば更新は自動。

### F. aqua ツールの checksum 固定
- 参照: `aqua.yaml`、`aqua-checksums.json`、`.github/workflows/pr-validation.yml`(aqua-checksums ジョブ)、`.github/workflows/aqua-update-checksum.yml`、`.github/CODEOWNERS`、`mise.toml`(aqua bootstrap)
- 抜き出すもの: `aqua.yaml` の骨組み（`registries` + `checksum.require_checksum: true` + `supported_envs` + 必要な `packages`）、`pr-validation.yml` の `aqua-checksums` ジョブ、`aqua-update-checksum.yml`（Renovate との連携が要るなら）、`.github/CODEOWNERS`（aqua 設定変更の maintainer ゲート）、`mise.toml` の aqua 1 行。
- AskUser:
  - 管理するツール一覧（`aqua g <pkg>` で aqua-registry に release-asset package として存在することを事前確認する）。hadolint は除外する方針（aqua に載せず CI=hadolint-action / ローカル=remote pre-commit hook の従来経路を維持。詳細は design.md「依存の監査」節）
  - サポートするプラットフォーム（`supported_envs`、CI=`linux/amd64` + 開発機=`darwin/arm64` 等）
  - CODEOWNERS の owner（maintainer の @user / @org/team）
- 生成: `aqua update-checksum` で `aqua-checksums.json` を生成（**手書き禁止**）。`aqua install` が全 `supported_envs` で通ることを確認。
- 注意: **`require_checksum: true`** を必ず付ける（checksum 不在で install を fail させる fail-closed）。**`aqua-checksums.json` はコピーせず対象環境で生成**（id がパッケージ・version・asset・platform を符号化しているため）。CODEOWNERS は default branch の branch protection で "Require review from Code Owners" を ON にしないと無効。aqua-exec ジョブは `aqua-validate.yml` 側で base-branch overlay と push:main 検証を組む（H/I/M を入れるならセットで）。
- 注意（mise→aqua 移行時）: 旧 required check `Verify mise tools are locked` が branch protection に残ったまま F に切り替えると、存在しない check 待ちで PR が永遠に merge 不能になる。aqua 化と同 PR で required check リストを `Verify aqua checksums are current` に差し替え、旧 mise-locked check を必ず外す。

### G. 依存更新（Renovate）
- 参照: `renovate.json5`
- 抜き出すもの: `renovate.json5` から、有効化する manager（github-actions / pre-commit / mise / docker / npm / cargo 等）と該当する設定ブロック（`minimumReleaseAge` / `packageRules` / `pinDigests` 等）だけを対象リポの Renovate 設定にマージ。使わない manager のルールは持ち込まない。
- AskUser:
  - **実行方式**: Mend ホスト型 App / self-hosted(GHA)。self-hosted は `GITHUB_TOKEN` だと PR が CI を発火しないため**別アイデンティティのトークン必須**
  - **cooldown 日数**: `minimumReleaseAge`（既定 7d、major 14d 等）
  - **automerge**: しない / digest・patch のみ限定解禁
- 注意: Dependabot と同 ecosystem で併走させない。pre-commit / mise / docker manager を有効化。`@types/node` 等は runtime メジャーに合わせる `allowedVersions` を検討。

### H. workflow セキュリティ lint（ghalint）
- 参照: `aqua-validate.yml`(gha-lint ジョブ)、`.pre-commit-config.yaml`、`aqua.yaml`
- 抜き出すもの: `aqua-validate.yml` の `gha-lint` ジョブ（base-branch overlay step 込み）+ `.pre-commit-config.yaml` の ghalint ローカル hook + `aqua.yaml` の `suzuki-shunsuke/ghalint` 行。
- AskUser: 特になし。ghalint のポリシー（`permissions` 最小化、`timeout-minutes` 必須、SHA 固定）に合わせて**既存 workflow の修正が必要**になる点を伝える。
- 注意: SHA 固定を要求するため、**未 pin の action が残っていると落ちる**（D を先に適用するか、対象 workflow を pin する）。CI は **aqua-installer で aqua 自身を SHA pin し、`aqua exec -- ghalint run` を実行**（PR の aqua 設定差し替えは base-branch overlay でブロック）。

### I. secret スキャン（gitleaks）
- 参照: `aqua-validate.yml`(gitleaks ジョブ)、`.pre-commit-config.yaml`、`aqua.yaml`
- 抜き出すもの: `aqua-validate.yml` の `gitleaks` ジョブ（base-branch overlay step 込み）+ `.pre-commit-config.yaml` の gitleaks ローカル hook + `aqua.yaml` の `gitleaks/gitleaks` 行。
- AskUser: `.gitleaks.toml`(allowlist) を使うか。
- 注意: 導入時に **一度 `aqua exec -- gitleaks dir .` を実行して誤検知を確認**（lockfile のハッシュ等）。誤検知が出たら allowlist を作る。

### J. Docker ベストプラクティス + digest 固定
- 参照: `examples/docker-node/*`・`examples/docker-rust/*`(サンプル)、`docker`ジョブ、`scripts/check-docker-digests.sh`、`.pre-commit-config.yaml`(pin-docker)、`renovate.json5`(`docker:pinDigests`)
- 抜き出すもの: `pr-validation.yml` の `docker` ジョブ + `scripts/check-docker-digests.sh` + `.pre-commit-config.yaml` の pin-docker hook + `renovate.json5` の `docker:pinDigests`。サンプルが要るなら言語に応じて `examples/docker-node/`（Node + pnpm）か `examples/docker-rust/`（Rust + cargo）を。
- 生成:
  - base image の digest を対象環境で解決し、`docker buildx imagetools inspect <image:tag>` で得た `@sha256:...` を `FROM` に書く（コピー禁止）。
  - Node サンプルを使うなら `pnpm-lock.yaml` を再生成: `corepack enable && pnpm install --lockfile-only`。Rust サンプルなら `cargo generate-lockfile` で `Cargo.lock` を生成。
- AskUser:
  - **サンプルごと入れる / チェックだけ入れる**
  - パッケージマネージャ・言語（pnpm/TS / cargo/Rust 等）
- 注意: hadolint の lint と digest 検証は対象リポの Dockerfile 構成に合わせてパスを調整する。監査ジョブ（M）との対応は言語別: `docker-node` は pnpm audit、`docker-rust` は cargo-deny（`deny.toml`）。trivy（fs スキャン）は言語非依存で両方に効く。いずれも依存をビルド/実行しない静的監査。

### M. 依存監査（cargo-deny / trivy / pnpm audit）
- 参照: `aqua-validate.yml`(cargo-deny / trivy / pnpm-audit ジョブ)、`pr-validation.yml`(pnpm-aqua-sync ジョブ)、`.pre-commit-config.yaml`(cargo-deny / trivy / check-pnpm-aqua-sync hook)、`aqua.yaml`(cargo-deny / trivy / pnpm)、`scripts/check-pnpm-aqua-sync.sh`、`examples/docker-rust/deny.toml`、`examples/docker-node/pnpm-workspace.yaml`
- 抜き出すもの: **監査したい言語のぶんだけ**（独立に選べる）:
  - **Rust（cargo-deny）**: `aqua-validate.yml` の `cargo-deny` ジョブ + `.pre-commit-config.yaml` の cargo-deny hook + `aqua.yaml` の `EmbarkStudios/cargo-deny` 行 + `deny.toml`。
  - **FS / コンテナ（trivy）**: `aqua-validate.yml` の `trivy` ジョブ + `.pre-commit-config.yaml` の trivy hook + `aqua.yaml` の `aquasecurity/trivy` 行。
  - **npm（pnpm audit）**: `aqua-validate.yml` の `pnpm-audit` ジョブ + `aqua.yaml` の `pnpm/pnpm` 行 + `pr-validation.yml` の `pnpm-aqua-sync` ジョブ + `scripts/check-pnpm-aqua-sync.sh` + `.pre-commit-config.yaml` の check-pnpm-aqua-sync hook + `examples/docker-node/pnpm-workspace.yaml`。
- 生成（コピー禁止・対象環境で解決）:
  - `aqua.yaml` に対象ツールを追加して `aqua update-checksum` で `aqua-checksums.json` を再生成する（version と checksum はここに集約）。
  - `deny.toml` は `cargo deny init` をベースに、対象リポの実依存に合わせて `licenses` allowlist を調整。publish=false の自前 crate は `[licenses] private = { ignore = true }`。
- AskUser:
  - **監査する言語**（multiSelect）: Rust(cargo-deny) / npm(pnpm audit) / FS(trivy)
  - **cargo-deny の licenses allowlist**（permissive のみ等）
  - **trivy の severity 閾値**（`HIGH,CRITICAL` 等。緩いと低重大度で CI が flaky になる）
  - **required check 化**するか
- 注意:
  - **3 つとも「依存コードをビルド/実行しない」静的監査**（cargo-deny=cargo metadata / trivy=`fs`（`image` ではない）/ pnpm audit=install せず lockfile + advisory API）。CI で PR の依存を走らせない原則を保つ。
  - **cargo-deny は 0.16 系不可**（現行 RUSTSEC の CVSS 4.0 を parse できず落ちる）→ **0.19 系以降**。
  - **pnpm audit は脆弱性監査のみ**で cargo-deny の licenses / bans 相当は無い（非対称）。npm 側の広い守りは `pnpm-workspace.yaml`（cooldown / postinstall ブロック=`allowBuilds:{}` / `verifyDepsBeforeRun`）側に置く。
  - **pnpm は aqua 管理の release tarball を使う**（corepack 不使用＝PR の `packageManager` に CI 実行の pnpm を差し替えさせない）。`aqua.yaml` の `pnpm/pnpm` と `examples/docker-node/package.json` の `packageManager` は別 consumer なので両方残るが、ドリフトは `check-pnpm-aqua-sync.sh` で検出する。

### K. type 語彙の自己テスト
- 参照: `scripts/check-vocab-sync.sh`、`.pre-commit-config.yaml`（**pre-commit hook のみ。CI には載せない**＝毎 PR 実行は過剰。当該ファイル変更時のみ発火）
- 注意: A/B/C を入れた場合のみ意味を持つ。スクリプトは語彙の抽出元（4 箇所）が対象リポの構成と一致しているか調整する。

### L. リポ整備
- 参照: `.github/ISSUE_TEMPLATE/*`、`.github/pull_request_template.md`、`LICENSE`、`.gitignore`
- AskUser: **ライセンス種別**、PR/issue テンプレの要否。
- 注意（落とし穴）: PR テンプレ本文に **`BREAKING CHANGE:` という文字列を書かない**（C の body autolabeler に一致して全 PR が breaking 扱いになる）。"!" を使う旨の表現にする。

---

## 導入後の検証

取り込んだモジュールに応じて回す。**入手元に注意**：`actionlint` / `renovate-config-validator` はこのテンプレの `mise.toml` には含まれないので、検証時だけ別途入れる（`mise.toml` に足す、または単発インストール）。`scripts/check-*.sh` は repo-root のファイル一式を前提に書かれているので、部分採用ではパスや対象一覧を対象リポに合わせて調整してから回す。

| モジュール | 検証 | 前提 |
|---|---|---|
| 0 | `mise install && aqua install` が通る / `prek install` 後に hook が登録される | mise + aqua + prek |
| A | 規約違反の commit message・branch 名がローカルで弾かれる（負例で確認） | 0 + A |
| B | 不正な PR title で `pr-title` ジョブが fail する | B |
| C | `create-labels.sh` 後にラベルが揃う / テスト PR で autolabel が付く | C + ラベル作成 |
| 全 workflow | `actionlint .github/workflows/*.yml` | actionlint を入手 |
| D | `aqua exec -- pinact run --check`（未 pin が無いこと） | 0（aqua）+ pinact |
| E | `bash scripts/check-hook-rev-sha.sh` | スクリプトを移植済み |
| F | `aqua update-checksum --check`（aqua.yaml と aqua-checksums.json の整合）／`aqua install` が `supported_envs` 全てで通ること | 0（aqua）+ `aqua-checksums.json` コミット済み |
| H | `aqua exec -- ghalint run`（違反なら既存 workflow を修正） | 0 + D 済み（未 pin で落ちる） |
| I | `aqua exec -- gitleaks dir .`（誤検知確認） | 0 + gitleaks |
| J | `bash scripts/check-docker-digests.sh` / `docker build` + 起動 + healthcheck / `docker compose config -q` | Dockerfile・compose を移植済み |
| M | `aqua exec -- cargo-deny check` / `aqua exec -- trivy fs --scanners vuln,misconfig` / `aqua exec -- pnpm audit --audit-level high` が通る（**負例**＝既知脆弱性・禁止ライセンス・禁止版で fail することも確認）／`bash scripts/check-pnpm-aqua-sync.sh` で版同期 | deny.toml・aqua bootstrap 済み |
| K | `bash scripts/check-vocab-sync.sh`（語彙の抽出元 4 箇所が一致） | A/B/C 済み |
| G | `renovate-config-validator`（`renovate.json5` 構文） | validator を入手 |

各 `scripts/check-*.sh` は**正常系と、わざと違反させた負例**の両方で確認する（チェックが本当に効くことの担保）。

---

## GitHub 側の手動設定（モジュール別）

ファイルだけでは完結しない。選んだモジュールに応じてリポジトリ設定を手で入れる:

- **C**: Squash merge のみ有効化 + "Default to PR title for squash commits" / `bash create-labels.sh` でラベル作成 / 初回の基準 tag `v0.1.0` を手動作成
- **B / D / E / F / H / I / J / M**: 各 CI チェックを `main` の Branch protection で **required** にするか決める（required 化は任意・運用次第。M は `Audit Rust deps (cargo-deny)` / `Scan filesystem (trivy)` / `Audit npm deps (pnpm audit)` / `Verify pnpm packageManager == aqua.yaml`）
- **F**（hard 条件）: `.github/CODEOWNERS` を有効化するため、default branch の branch protection で **"Require review from Code Owners"** を ON にする。これが無いと CODEOWNERS は単なる通知になり、aqua 設定改変の maintainer ゲートが機能しない。
- **D**（任意）: GitHub 純正 **Enforce SHA pinning** ポリシーを ON
- **G**: [Renovate App](https://github.com/apps/renovate) を有効化（self-hosted なら別アイデンティティのトークンを用意）

---

## 既知の落とし穴チェックリスト（コピー時に必ず確認）

- [ ] 共有ファイル（`pr-validation.yml` / `aqua-validate.yml` / `.pre-commit-config.yaml` / `aqua.yaml` / `mise.toml` / `renovate.json5`）から**選んだモジュールの job / hook / tool だけ**を抜いた（無関係な job を持ち込んでいない）
- [ ] 各 job / hook が参照する `scripts/check-*.sh` を一緒に移植した
- [ ] ローカルフック系を入れたなら基盤（prek + aqua、モジュール `0`）を先に立てた
- [ ] H（ghalint）を入れたなら未 pin の action が残っていない（D 済み）
- [ ] PR テンプレに `BREAKING CHANGE:` の文字列を残していない（L×C）
- [ ] release-drafter のバージョンに `categories[].exclusive` が**対応しているか**。v6 系なら autolabeler 排他化で代替
- [ ] `mise.lock` / `pnpm-lock.yaml` / `aqua-checksums.json` を**コピーせず生成**した
- [ ] action の SHA と base image digest を**対象環境で解決**した
- [ ] F（aqua）の `aqua.yaml` に `require_checksum: true` を付けた／`.github/CODEOWNERS` を追加し default branch の "Require review from Code Owners" を ON にした／`aqua-validate.yml` のジョブに base-branch overlay step を入れ `push: main` でも実行した
- [ ] `prek install` に **`--hook-type pre-commit --hook-type commit-msg --hook-type pre-push`** を含めた（commit-check は commit-msg / pre-push、その他のローカルフックは pre-commit 既定）
- [ ] type 語彙が A/B/C/K の参照箇所で一致（K の自己テストで担保）
