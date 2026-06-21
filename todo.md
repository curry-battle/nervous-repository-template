# 残作業 TODO

リポジトリ: https://github.com/curry-battle/nervous-repository-template

スキャフォールド・push・CI 実機検証（pr-validation 7チェック + release-drafter + autolabeler）は完了済み。
残りは主に GitHub 側の手動設定。

## 要対応（ブロック中 / 手動）

- [ ] **Branch protection（main）** — 現在 Private × 無料プランのため API 403。
      **Public 化** または **GitHub Pro** にすれば設定可能。有効化したら以下 **11 個** を required status checks にする:
  - `Validate PR title`
  - `Verify actions are SHA-pinned`
  - `Verify hooks are SHA-pinned`
  - `Verify aqua checksums are current`
  - `Verify pnpm packageManager == aqua.yaml`
  - `Verify Docker (lint / digest-pinned / compose)`
  - `Lint workflows (ghalint)`
  - `Scan for secrets (gitleaks)`
  - `Audit Rust deps (cargo-deny)`
  - `Scan filesystem (trivy)`
  - `Audit npm deps (pnpm audit)`
  - あわせて **"Require review from Code Owners"** も ON にする（`.github/CODEOWNERS` を有効化するため。aqua 設定改変の maintainer ゲートが機能する hard 条件）。
  - 「PR 必須（直 push 禁止）」も推奨（required_pull_request_reviews: 0 approvals）。
- [ ] **旧 `Verify mise tools are locked` を required check から外す** — aqua 移行で削除済み job。
      branch protection に残っているとこの check が永遠に来ず PR が merge 不能になるので、
      aqua 化と同 PR で required check リストから必ず外すこと。
- [ ] **Renovate の実 actor 名を実機確認** — `aqua-update-checksum.yml` は `actor == 'renovate[bot]'` で
      ガードしているが、Mend ホスト型 App では `mend-bot` 等の別 actor になりうる。
      最初の Renovate PR で `github.actor` を実機確認し、必要なら if 条件を実 actor 名に直す。
- [ ] **`aqua-renovate-config` preset のカバレッジ確認** — `aqua.yaml` の `packages[*].version` 追従に加えて
      `registries[].ref` まで preset が更新してくれるか確認。preset が覆うなら `renovate.json5` の
      `customManagers`（aqua.yaml の registries 用 regex）を削除して二重定義を解消する。
- [ ] **Renovate App を有効化** — https://github.com/apps/renovate を当該リポにインストール。
      onboarding PR をマージすると `renovate.json5` で稼働開始。
- [ ] **draft `v0.1.0` を publish**（任意）— publish した瞬間に `v0.1.0` tag が作成される。
      しない場合は draft のまま（release-drafter の semver 基準は draft でも機能）。

## push 後に確認したいこと

- [ ] **Renovate × pin-hooks の相性** — Renovate の pre-commit manager が `.pre-commit-config.yaml` の `rev` を
      tag に戻すと `pin-hooks`（prek）が落ちる懸念。最初の pre-commit 更新 PR で確認し、
      落ちるなら pre-commit manager を無効化 or 別運用にする。

## 任意（強化）

- [ ] **native Enforce SHA pinning** — Public/Pro なら Settings → Actions → "Require actions to be
      pinned to a full-length commit SHA" を ON（org 一括も可）。
- [ ] **secure-repo で一度監査** — https://app.stepsecurity.io/securerepo に通して取りこぼし確認。
- [ ] **`disable-releaser`** — `release-drafter.yml` のステップに
      `disable-releaser: ${{ github.event_name == 'pull_request' }}` を足すと
      「PR は autolabel のみ / draft 更新は push:main のみ」と役割分離できる。
- [x] **trivy**（fs スキャン）— `Scan filesystem (trivy)` ジョブで lockfile / 設定の脆弱性・誤設定を静的スキャン済み。
      ~~checkov / `trivy image`~~（IaC・イメージ脆弱性のさらなる層）は任意で追加可。

## メモ

- ローカル開発を始める人向け: `mise install && aqua install` → `prek install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push`
- 詳細設計は docs/design.md、他リポへの移植は docs/adoption-guide.md。

### 保守: 監査ツール版の更新（aqua 移行で自動化済み）

ghalint / gitleaks / cargo-deny / trivy / pnpm の version と checksum は `aqua.yaml` + `aqua-checksums.json` に集約済み。Renovate の `aqua-renovate-config` preset が version 追従、`aqua-update-checksum.yml`（`aquaproj/update-checksum-action`）が checksum 再生成を担うため、**手動 sha256 更新は不要**。

pnpm の二重化（`aqua.yaml` ↔ `examples/docker-node/package.json` の `packageManager`）は `scripts/check-pnpm-aqua-sync.sh`（CI ジョブ `pnpm-aqua-sync` + pre-commit hook）でドリフト検出する。

詳細は docs/design.md「外部依存の SHA と checksum 固定」節。
