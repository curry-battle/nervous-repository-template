# aqua 移行 — ローカル完了 HANDOFF チェックリスト

> このブランチ（`feature/aqua-migration`）は **aqua を導入する足場（scaffolding）** を実装したもの。
> 実装環境に **aqua とネットワークが無かった**ため、checksum 実値・action SHA・version pin・`mise.lock`
> は**意図的にプレースホルダのまま**にしてある（捏造しない方針）。
> **下記をローカル（aqua + network が使える環境）で完了させるまで CI は red のまま**。
> 設計の根拠と全体像は `.plans/aqua-migration.md`（承認済み design-doc）を参照。

## 完了させる手順（順番に）

### 1. aqua のインストールと gating 確認（design-doc Step1）
```bash
# aqua をローカルに入れる（mise 経由 or 公式 installer）
# mise.toml の aqua バージョン確定後:  mise install
aqua g pnpm     # pnpm が aqua-registry に release-asset として在るか確認
aqua g trivy    # trivy も同様
```
- **pnpm が aqua-registry に無い / 非対応の場合**は、自動でスコープ縮小せず**判断を仰ぐ**
  （pnpm を aqua から外す＝Alternatives F に縮退するか、別経路）。design-doc の方針通り。

### 2. version プレースホルダの確定（CI が parse して fail する箇所）
以下のプレースホルダを実バージョンに置換する：

| ファイル | プレースホルダ | 置換内容 |
|---|---|---|
| `aqua.yaml` | `registries[].ref: v4.x.y` | aqua standard registry の最新タグ |
| `aqua.yaml` | `supported_envs` の値表記 | 公式 docs で確定（`linux/amd64` 等の形式） |
| `.github/workflows/aqua-validate.yml` | `aqua_version: v2.x.y`（inline aqua-installer ×5 ジョブ） | aqua 本体の最新互換版 |
| `.github/workflows/pr-validation.yml` / `aqua-update-checksum.yml` | `aqua_version: v2.x.y` | 同上 |
| `mise.toml` | `aqua = "2.x.y"` | aqua 本体の版（CI と揃える） |
| `renovate.json5` | `aqua-renovate-config#2.x.x` | preset の最新版 |

### 3. checksum 実値の生成（design-doc Step1）
```bash
aqua update-checksum   # aqua-checksums.json を実値で生成（現状は空配列）
aqua install           # linux/amd64 と darwin/arm64 で成功すること
aqua update-checksum --check   # diff 0
```
- 生成された `aqua-checksums.json` をそのままコミット（手書き禁止）。
- 既存 `mise.lock` の sha256 と 6 ツール（cargo-deny/ghalint/gitleaks/hadolint は対象外/pinact/prek）を交差検証。

### 4. action の SHA pin（pin-actions ジョブが tag-only を fail させる）
`<full-sha>` プレースホルダを pinact で解決：
```bash
pinact run   # aqua-installer / update-checksum-action / その他 uses を full SHA に
```
- 対象: `.github/workflows/aqua-validate.yml`（5 ジョブに inline の aqua-installer ×5）、
  `.github/workflows/aqua-update-checksum.yml`（aqua-installer + update-checksum-action）、
  `.github/workflows/pr-validation.yml` の aqua 系 uses。
  ※ overlay は security 上 composite local action 化せず各ジョブ inline。SHA は 5 箇所すべて置換する。

### 5. `mise.lock` の再生成
```bash
mise lock --platform linux-x64,macos-arm64   # aqua 1 エントリのみに縮約
```
- `mise.toml` の aqua backend 表記（`aqua = "x"` か `aqua:aquaproj/aqua`）を確定してから。

### 6. リポ設定（コード差分ではない・handoff 漏れ注意）
- `.github/CODEOWNERS` の owner は暫定で `@curry-battle`。実体に合わせて調整。
  CODEOWNERS は `aqua.yaml` / `aqua-checksums.json` に加えて **`.github/workflows/` と
  `.github/actions/`** も対象（CI/guard を変える PR も maintainer レビュー必須にするため）。
  ※ `.github/actions/` は現状ファイル無し（overlay は inline 化したため）。将来 composite を
  非 security-critical 用途で導入した場合に備えた **pre-emptive 保護**として残してある。
- **trust model（重要・正直な前提）**: `pull_request` の CI は PR head の workflow/action で走るため、
  overlay や guard も PR 側で改変可能。よって `pull_request` の required check は **advisory**
  （secret なし・read-only token・public source で blast radius は bounded）。**信頼できる検証は
  push:main の run**（merge 後・信頼済みコード）。merge 自体を CODEOWNERS + branch protection で
  gate することが本質的防御。
- **branch protection**（default branch）:
  - 「Require review from Code Owners」を **ON**（CODEOWNERS はこれが無いと無効）。
  - required status checks を新ジョブ構成に更新し、**旧 `Verify mise tools are locked` を required から外す**
    （残すと存在しない check 待ちで merge 不能）。
- **Renovate の実 actor 名**を確認（`renovate[bot]` か Mend App の `mend-bot` 等）。
  `aqua-update-checksum.yml` の `if: github.actor == ...` を実体に合わせる。

### 7. 受け入れ検証（design-doc Testing）
- `aqua exec -- <tool>` 各ツールが従来通り動く。
- `pr-validation` / `aqua-validate` 全ジョブ緑。
- 負例: aqua.yaml 版不一致 / checksum 削除 / pnpm 版ズレ で対応ジョブが fail。
- base-branch overlay: テスト PR で aqua.yaml のツール版を変え、`aqua exec -- trivy version` が
  **base 側の版**を出すこと（overlay が効いている）を確認。
- 移行後、aqua-exec ジョブが push:main でも走り新 config が main で実機検証されること。

## この環境で完了済み（参考）
- 全ファイルの実装（aqua.yaml/checksums雛形/workflow群[overlay は各ジョブ inline]/mise.toml/renovate/pre-commit/scripts+test/CODEOWNERS/docs）
- Director 実行ゲート: **actionlint exit0 / 全 YAML・JSON 妥当 / shellcheck OK / pnpm-aqua-sync テスト 5/5 pass**
- クロスモデル・ダブルレビュー（claude / codex）で修正可能な指摘は解消済み
