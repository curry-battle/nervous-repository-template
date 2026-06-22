# 導入ガイド（LLM 向けプレイブック）

このドキュメントは **AI エージェント（Claude / Codex 等）向け**の指示書です。
ユーザが「このリポジトリを真似したい」「このリポジトリの XXX を取り入れたい」と言ったとき、
**勝手にコピーせず、この手順で AskUser しながら**対象リポジトリへ移植してください。

- 参照は **ファイル単位**で示す（行番号は時間で陳腐化するので書かない）。実体は各ファイルを読むこと。
- 設定の中身（type 語彙や cooldown 日数など）は**必ず AskUser で決めてから**書く。デフォルトを黙って流用しない。
- lockfile（`mise.lock` / `pnpm-lock.yaml` / `aqua-checksums.json`）や action の SHA は**コピーせず対象環境で生成/解決し直す**（生成コマンドは各モジュール詳細に記載）。
- **共有ファイルは丸ごとコピーしない**。`pr-validation.yml` / `security-audit.yml` / `.pre-commit-config.yaml` / `mise.toml` / `aqua.yaml` / `renovate.json5` は複数モジュールが同居する。選んだモジュールに対応する **job / hook / tool / 設定ブロックだけを抜き出して**マージする（各モジュール詳細の「抜き出すもの」を見る）。無関係な job を持ち込むと、未導入のスクリプトやツールを参照して壊れる。
- **共通基盤（`foundation`）を最初に置く**。ローカルフック系は prek に、ツール固定系は aqua（CI/ローカル共通）に乗る（mise は aqua バイナリの bootstrap のみ）。基盤を用意してから各モジュールの hook / tool を足す。
- 設計の背景は [design.md](./design.md) を参照。

---

## 進め方（4 ステップ）

### Step 1. 何を取り込むか AskUser（モジュール選択・multiSelect）

下の「モジュール一覧」を選択肢にして AskUser する。`header` 例: `導入モジュール`。
推奨プリセットを先頭に置く:

- **開発フロー（コア・推奨）**: `conventional-commits` + `pr-title` + `release-drafter` + `vocab-self-test`
- **セキュリティ・環境**: `actions-sha-pin` / `hook-rev-pin` / `aqua-checksum-pin` / `renovate` / `workflow-lint` / `secret-scan`
- **セキュリティ・環境（Docker・任意）**: `docker-hardening`
- **セキュリティ・環境（依存監査・任意）**: `dependency-audit`（example を使うなら `docker-hardening` と併用）
- **リポ整備**: `repo-scaffolding`

### Step 2. 依存解決とコンフリクト確認

選択結果から**依存モジュール**を補い（多くは `foundation` が要る）、対象リポジトリの既存設定との衝突を洗い出してユーザに伝える。例:

- 既に Dependabot がある → `renovate` と二重になる
- 既に release 方式がある → `release-drafter` と衝突
- 既存 workflow が未 pin / 過剰権限 → `workflow-lint` が落ちるので `actions-sha-pin` 相当の pin と権限最小化が先に要る
- prek / mise を未導入 → `foundation` を先に立てる

### Step 3. モジュール別に「設定の中身」を AskUser

各モジュール詳細の「AskUser」を順に確認する。
**横断的な決定**（複数モジュールに効く）は最初にまとめて聞く:

- **type 語彙**（`conventional-commits` / `pr-title` / `release-drafter` / `vocab-self-test` で共有する唯一の正）
- **マージ戦略**: このテンプレは **Squash 専用**設計（PR title = `main` コミット = リリースノート 1 行）。非 Squash を選ぶ場合、`pr-title` / `release-drafter` はそのままでは意図通り機能せず別実装が要る（このテンプレには含まれない）。非 Squash を本当に使うなら、その実装まで設計する覚悟があるか確認する。
- **branch 語彙**（Conventional Commits 系 `feat/` か Conventional Branch / Git-Flow `feature/` か）

### Step 4. 適用 → 検証

ファイルをコピー/マージし、決めた値を埋め、各モジュール詳細の「検証」と「GitHub 手動設定」を必ず実行する。`actionlint` / `renovate-config-validator` はこのテンプレの `mise.toml` には含まれないので、検証時だけ別途入れる（`mise.toml` に足す、または単発インストール）。`scripts/check-*.sh` は repo-root のファイル一式を前提に書かれているので、部分採用ではパスや対象一覧を対象リポに合わせて調整してから回す。各 `scripts/check-*.sh` は**正常系と、わざと違反させた負例**の両方で確認する（チェックが本当に効くことの担保）。全 workflow には `actionlint .github/workflows/*.yml` を回す。

---

## モジュール一覧

区分は README「包含されるもの」の 2 グループ（開発フロー / セキュリティ・環境）に対応する。各モジュール詳細はリンク先を参照。

| 区分 | モジュール | 説明 | 依存 |
|---|---|---|---|
| 基盤 | [foundation](./adoption/foundation.md) | 共通基盤（prek + aqua、mise は aqua bootstrap 用） | なし |
| 開発フロー | [conventional-commits](./adoption/conventional-commits.md) | commit / branch の Conventional 強制 | `foundation` |
| 開発フロー | [pr-title](./adoption/pr-title.md) | PR title の Conventional 強制 | type 語彙 |
| 開発フロー | [release-drafter](./adoption/release-drafter.md) | リリース自動化 | `conventional-commits` / `pr-title`（語彙） |
| 開発フロー | [vocab-self-test](./adoption/vocab-self-test.md) | type 語彙の自己テスト | `foundation` + `conventional-commits` / `pr-title` / `release-drafter` |
| セキュリティ・環境 | [actions-sha-pin](./adoption/actions-sha-pin.md) | GitHub Actions の SHA 固定（pinact） | `foundation`（ローカル hook 利用時） |
| セキュリティ・環境 | [hook-rev-pin](./adoption/hook-rev-pin.md) | pre-commit hook rev の SHA 固定 | `foundation`（`.pre-commit-config.yaml` が前提） |
| セキュリティ・環境 | [aqua-checksum-pin](./adoption/aqua-checksum-pin.md) | aqua ツールの checksum 固定 | `foundation`（aqua） |
| セキュリティ・環境 | [renovate](./adoption/renovate.md) | 依存更新（Renovate） | 更新対象が存在すること |
| セキュリティ・環境 | [workflow-lint](./adoption/workflow-lint.md) | workflow セキュリティ lint（ghalint） | `foundation`、`actions-sha-pin` 推奨 |
| セキュリティ・環境 | [secret-scan](./adoption/secret-scan.md) | secret スキャン（gitleaks） | `foundation` |
| セキュリティ・環境 | [docker-hardening](./adoption/docker-hardening.md) | Docker ベストプラクティス + digest 固定 | `foundation`（prek hook 利用時） |
| セキュリティ・環境 | [dependency-audit](./adoption/dependency-audit.md) | 依存監査（cargo-deny / trivy / pnpm audit） | `foundation`（prek hook 利用時）、`docker-hardening`（example を使うなら） |
| リポ整備 | [repo-scaffolding](./adoption/repo-scaffolding.md) | issue/PR テンプレ・LICENSE・.gitignore | なし |

> 基盤（`foundation`）：prek が `conventional-commits` / `actions-sha-pin` / `hook-rev-pin` / `workflow-lint` / `secret-scan` / `docker-hardening` / `vocab-self-test` / `dependency-audit` のローカルフックを動かし、aqua が `actions-sha-pin` / `aqua-checksum-pin` / `workflow-lint` / `secret-scan` / `docker-hardening` / `dependency-audit` の CLI を固定・checksum 検証する（CI もローカルも同じ `aqua.yaml`/`aqua-checksums.json` を参照）。mise は aqua バイナリ自身を bootstrap する用途のみ。最初に `.pre-commit-config.yaml` / `aqua.yaml` / `aqua-checksums.json` / `mise.toml` の土台を置き、各モジュールの hook / tool をそこへ足していく。CI だけで完結するモジュール（`pr-title` / `release-drafter` / `renovate`、および `actions-sha-pin` / `workflow-lint` / `secret-scan` / `docker-hardening` を「CI ジョブのみ」で使う場合）は基盤なしでも動くが、ローカルフックを使うなら基盤が要る。

> **抜き出し方の原則**：`pr-validation.yml` は job 単位（`pr-title` / `pin-actions` / `pin-hooks` / `aqua-checksums` / `pnpm-aqua-sync` / `docker`）、`security-audit.yml` は aqua-exec ジョブ単位（`gha-lint` / `gitleaks` / `cargo-deny` / `trivy` / `pnpm-audit`）で分離できる。選んだモジュールの job だけを対象リポの workflow にコピーする。`.pre-commit-config.yaml` は hook の `id` 単位、`aqua.yaml` は `packages[]` の行単位、`mise.toml` は `[tools]` の行単位、`renovate.json5` は manager / 設定ブロック単位で抜く。各 job / hook が参照する `scripts/check-*.sh` も同時に持ち込む。

---

## 既知の落とし穴チェックリスト（コピー時に必ず確認）

- [ ] 共有ファイル（`pr-validation.yml` / `security-audit.yml` / `.pre-commit-config.yaml` / `aqua.yaml` / `mise.toml` / `renovate.json5`）から**選んだモジュールの job / hook / tool だけ**を抜いた（無関係な job を持ち込んでいない）
- [ ] 各 job / hook が参照する `scripts/check-*.sh` を一緒に移植した
- [ ] ローカルフック系を入れたなら基盤（`foundation`）を先に立てた
- [ ] `workflow-lint` を入れたなら未 pin の action が残っていない（`actions-sha-pin` 済み）
- [ ] PR テンプレに `BREAKING CHANGE:` の文字列を残していない（`repo-scaffolding` × `release-drafter`）
- [ ] release-drafter のバージョンに `categories[].exclusive` が**対応しているか**。v6 系なら autolabeler の type 正規表現を排他化（type 規則は `!` を含めず `:` で終端、`feat!:` は breaking のみ）で代替（詳細は [design.md](./design.md) / [release-drafter.md](./adoption/release-drafter.md)）
- [ ] `mise.lock` / `pnpm-lock.yaml` / `aqua-checksums.json` を**コピーせず生成**した
- [ ] action の SHA と base image digest を**対象環境で解決**した
- [ ] `aqua-checksum-pin` の `aqua.yaml` に `require_checksum: true` を付けた／`.github/CODEOWNERS` を追加し default branch の "Require review from Code Owners" を ON にした／`security-audit.yml` のジョブに base-branch overlay step を入れ `push: main` でも実行した
- [ ] `prek install` に **`--hook-type pre-commit --hook-type commit-msg --hook-type pre-push`** を含めた（commit-check は commit-msg / pre-push、その他のローカルフックは pre-commit 既定）
- [ ] type 語彙が `conventional-commits` / `pr-title` / `release-drafter` / `vocab-self-test` の参照箇所で一致（`vocab-self-test` の自己テストで担保）
