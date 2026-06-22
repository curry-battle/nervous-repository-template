# Tooling: aqua / prek / lockfile

## CLI ツールは aqua 経由で実行

直接 `pinact` / `ghalint` / `gitleaks` / `cargo-deny` / `trivy` / `pnpm` を呼ばない。**`aqua exec -- <tool>` を経由**する。

理由: aqua が `aqua-checksums.json` で固定した version とバイナリ checksum を強制するため。直接呼ぶと PATH 上の別 version を踏みうる。

| 用途 | コマンド |
|---|---|
| Actions の SHA pin | `aqua exec -- pinact run` (`--check` で検証) |
| Workflow lint | `aqua exec -- ghalint run` |
| Secret スキャン | `aqua exec -- gitleaks dir .` |
| Rust 依存監査 | `aqua exec -- cargo-deny check` |
| FS 監査 | `aqua exec -- trivy fs --scanners vuln,misconfig` |
| npm 依存監査 | `aqua exec -- pnpm audit --audit-level high` |

### 例外: hadolint

hadolint は aqua に載せていない（aqua registry に release-asset package が無い）。
- CI: `hadolint/hadolint-action`（SHA pin 済み）
- ローカル: `.pre-commit-config.yaml` の remote hook（rev を SHA pin）


## lockfile / checksum は生成コマンドで（手書き禁止）

別環境からのコピーも禁止。**対象環境で生成**する。

| ファイル | 生成コマンド |
|---|---|
| `mise.lock` | `mise lock --platform linux-x64,macos-arm64` |
| `aqua-checksums.json` | `aqua update-checksum`（`-prune` で未使用 entry も削除） |
| `pnpm-lock.yaml` | `corepack enable && pnpm install --lockfile-only` |
| `Cargo.lock` | `cargo generate-lockfile` |
| workflow の SHA | `aqua exec -- pinact run`（全 `uses:` を full SHA に書き換え） |
| Docker base image digest | `docker buildx imagetools inspect <image:tag>` で `@sha256:...` を取得して `FROM` に書く |

`aqua-checksums.json` は id がパッケージ・version・asset・platform を符号化しているため、別環境からコピーすると壊れる（id が一致しない）。

