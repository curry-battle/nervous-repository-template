# docker-hardening（Docker ベストプラクティス + digest 固定）

- 参照: `examples/docker-node/*` と `examples/docker-rust/*`(サンプル)、`docker`ジョブ、`scripts/check-docker-digests.sh`、`.pre-commit-config.yaml`(pin-docker)、`renovate.json5`(`docker:pinDigests`)
- 抜き出すもの: `pr-validation.yml` の `docker` ジョブ + `scripts/check-docker-digests.sh` + `.pre-commit-config.yaml` の pin-docker hook + `renovate.json5` の `docker:pinDigests`。サンプルが要るなら言語に応じて `examples/docker-node/`（Node + pnpm）か `examples/docker-rust/`（Rust + cargo）を。
- AskUser:
  - **Dockerfile 状況**: 既存 Dockerfile を硬化対象 / Dockerfile なしのため不採用
  - **サンプルごと入れる / チェックだけ入れる**
  - パッケージマネージャ / 言語（pnpm/TS / cargo/Rust 等）
- 生成:
  - base image の digest を対象環境で解決し、`docker buildx imagetools inspect <image:tag>` で得た `@sha256:...` を `FROM` に書く（コピー禁止）。
  - Node サンプルを使うなら `pnpm-lock.yaml` を再生成: `aqua exec -- pnpm install --lockfile-only`（corepack 不使用＝aqua 管理の pnpm を使う）。Rust サンプルなら `cargo generate-lockfile` で `Cargo.lock` を生成。
- 注意: hadolint の lint と digest 検証は対象リポの Dockerfile 構成に合わせてパスを調整する。監査ジョブ（`dependency-audit`）との対応は言語別: `docker-node` は pnpm audit、`docker-rust` は cargo-deny（`deny.toml`）。trivy（fs スキャン）は言語非依存で両方に効く。いずれも依存をビルド/実行しない静的監査。
- 検証: `bash scripts/check-docker-digests.sh` / `docker build -f examples/docker-node/Dockerfile examples/docker-node`（または `examples/docker-rust`）+ 起動 + healthcheck / 各 example で `docker compose config -q`
- GitHub 手動設定: `docker` ジョブを `main` の Branch protection で required check 化（任意・運用次第）
- 依存: `foundation`（prek hook 利用時）
