# サンプル Dockerfile（Rust / multi-stage / 実アプリに差し替える前提）。
# ベースイメージは tag + full digest で固定（CI の pin-docker が強制 / Renovate が digest を更新）。
FROM rust:1.83-slim-bookworm@sha256:540c902e99c384163b688bbd8b5b8520e94e7731b27f7bd0eaa56ae1960627ab AS build
WORKDIR /app

# 先に manifest だけ COPY して依存を取得（registry cache mount で共有）。
# その後 --frozen（=offline + locked）でビルドするため、依存はこの fetch で揃える。
COPY Cargo.toml Cargo.lock ./
RUN --mount=type=cache,id=cargo,target=/usr/local/cargo/registry \
    cargo fetch --locked

# ソースを入れて offline かつ lockfile 厳守でリリースビルド。
COPY src ./src
RUN --mount=type=cache,id=cargo,target=/usr/local/cargo/registry \
    cargo build --locked --frozen --release

# runtime は distroless（シェル無し・非 root）。glibc + libgcc を含む cc バリアントを使う。
FROM gcr.io/distroless/cc-debian12:nonroot@sha256:b0ae8e989418b458e0f25489bc3be523718938a2b70864cc0f6a00af1ddbd985 AS runtime
WORKDIR /app
COPY --from=build /app/target/release/sample-rust-app /usr/local/bin/sample-rust-app
# 非 root（distroless の nonroot ユーザ）で実行
USER nonroot
EXPOSE 3000
# シェルが無いのでバイナリ自身の healthcheck サブコマンドで /healthz を叩く
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD ["/usr/local/bin/sample-rust-app", "healthcheck"]
CMD ["/usr/local/bin/sample-rust-app"]
