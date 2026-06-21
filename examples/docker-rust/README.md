# sample-rust-app

テンプレートに含まれる **サンプル**。Docker / Rust まわりのベストプラクティスとチェック対象の見本です。
実プロジェクトでは中身を差し替えてください（不要なら丸ごと削除可）。

## 構成

| ファイル | 役割 |
|---|---|
| `src/main.rs` | 非同期ランタイム無しの最小 HTTP サーバ（`/healthz` を返す。std `TcpListener` + serde/serde_json） |
| `Cargo.toml` | パッケージ定義（`rust-version` で MSRV 固定 / serde・serde_json をキャレットで指定 / `publish = false`） |
| `Cargo.lock` | 依存の固定（厳密バージョン）。`cargo build --locked --frozen` で lockfile を厳守 |
| `deny.toml` | cargo-deny 設定（advisories / licenses / bans / sources） |
| `Dockerfile` | multi-stage（cargo fetch + offline build + distroless runtime）/ digest 固定 / 非 root / healthcheck |
| `docker-compose.yml` | 上記をビルドして起動する最小構成 |

## 使い方

```bash
cargo build              # ビルド（Cargo.lock に従う）
cargo test               # ユニットテスト（health_body のシリアライズ）
cargo run                # http://localhost:3000、/healthz が {"status":"ok"}
cargo deny check         # 依存の監査（このディレクトリ内なら deny.toml を自動検出）

# Docker（multi-stage で build まで実行）
docker compose up --build
```

## サプライチェーン対策（Rust）

依存の固定と監査を「ビルド/実行せずに」効かせるのが方針です。

- **`Cargo.lock` で pin**：全依存を厳密バージョン + ハッシュで固定。Renovate も `rangeStrategy: "pin"` で更新し続ける。
- **`cargo build --locked --frozen`**：`--locked` は Cargo.lock とのズレを失敗扱いにし、`--frozen` は offline（ネットワーク参照を禁止）でビルドする。Dockerfile では先に `cargo fetch --locked` で依存を取得してから `--frozen` ビルドする。
- **`deny.toml`（cargo-deny）**：
  - `advisories`：RUSTSEC DB を参照し、脆弱性 / メンテ放棄（cargo-deny 0.16 以降ではいずれも既定でエラー）/ 取り下げ（`yanked = "deny"`）を弾く。
  - `licenses`：permissive ライセンスのみ allowlist（copyleft は明示許可しない）+ `confidence-threshold`。
  - `bans`：同一クレートの複数バージョンを警告、ワイルドカード要求を禁止。
  - `sources`：未知レジストリ / git ソースを禁止し、crates.io のみ許可。

## このサンプルに効くチェック

リポジトリ共通の CI と、ローカル prek hook で検証されます。

- `hadolint`：Dockerfile lint（`docker` ジョブ）
- `pin-docker`：全 `FROM` が `@sha256:` で digest 固定か（`docker` ジョブ / prek）
- `docker compose config`：compose 構文（`docker` ジョブ）
- **`Audit Rust deps (cargo-deny)`**：`cargo deny check` を固定版で実行。`cargo metadata` のみを使い、**依存のビルド/実行はしない**（任意コード実行を避ける）。
- **`Scan filesystem (trivy)`**：`trivy fs` で lockfile / 設定の脆弱性・誤設定を静的スキャン。
- Renovate（`docker:pinDigests` / cargo manager）：base image digest と `Cargo.lock` を更新。

詳細は [../../docs/design.md](../../docs/design.md) を参照。
