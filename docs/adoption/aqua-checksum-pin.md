# aqua-checksum-pin（aqua ツールの checksum 固定）

- 参照: `aqua.yaml`、`aqua-checksums.json`、`.github/workflows/pr-validation.yml`(aqua-checksums ジョブ)、`.github/workflows/aqua-update-checksum.yml`、`.github/CODEOWNERS`、`mise.toml`(aqua bootstrap)
- 抜き出すもの: `aqua.yaml` の骨組み（`registries` + `checksum.require_checksum: true` + `supported_envs` + 必要な `packages`）、`pr-validation.yml` の `aqua-checksums` ジョブ、`aqua-update-checksum.yml`（Renovate との連携が要るなら）、`.github/CODEOWNERS`（aqua 設定変更の maintainer ゲート）、`mise.toml` の aqua 1 行。
- AskUser:
  - 管理するツール一覧（`aqua g <pkg>` で aqua-registry に release-asset package として存在することを事前確認する）。hadolint は除外する方針（aqua に載せず CI=hadolint-action / ローカル=remote pre-commit hook の従来経路を維持。詳細は [design.md](../design.md) の「依存の監査」節）
  - サポートするプラットフォーム（`supported_envs`、CI=`linux/amd64` + 開発機=`darwin/arm64` 等）
  - CODEOWNERS の owner（maintainer の @user / @org/team）
- 生成: `aqua update-checksum` で `aqua-checksums.json` を生成（**手書き禁止**）。`aqua install` が全 `supported_envs` で通ることを確認。
- 注意:
  - **`require_checksum: true`** を必ず付ける（checksum 不在で install を fail させる fail-closed）。**`aqua-checksums.json` はコピーせず対象環境で生成**（id がパッケージ、version、asset、platform を符号化しているため）。CODEOWNERS は default branch の branch protection で "Require review from Code Owners" を ON にしないと無効。aqua-exec ジョブは `security-audit.yml` 側で base-branch overlay と push:main 検証を組む（`workflow-lint` / `secret-scan` / `dependency-audit` を入れるならセットで）。
  - **mise→aqua 移行時**: 旧 required check `Verify mise tools are locked` が branch protection に残ったまま `aqua-checksum-pin` に切り替えると、存在しない check 待ちで PR が永遠に merge 不能になる。aqua 化と同 PR で required check リストを `Verify aqua checksums are current` に差し替え、旧 mise-locked check を必ず外す。
- 検証: `aqua update-checksum -prune` 後 `git diff --exit-code aqua-checksums.json`（aqua v2 に `--check` は無い。整合と未使用 checksum を diff で検出）／`aqua install` が `supported_envs` 全てで通ること
- GitHub 手動設定:
  - **（hard 条件）**: `.github/CODEOWNERS` を有効化するため、default branch の branch protection で **"Require review from Code Owners"** を ON にする。これが無いと CODEOWNERS は単なる通知になり、aqua 設定改変の maintainer ゲートが機能しない。
  - **（任意・運用次第）**: `aqua-checksums` ジョブを `main` の Branch protection で required check 化
- 依存: `foundation`（aqua）
