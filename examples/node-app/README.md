# sample-node-app

テンプレートに含まれる **サンプル**。Docker / pnpm まわりのベストプラクティスとチェック対象の見本です。
実プロジェクトでは中身を差し替えてください（不要なら丸ごと削除可）。

## 構成

| ファイル | 役割 |
|---|---|
| `server.ts` | 依存ゼロの最小 HTTP サーバ（`/healthz` を返す。TypeScript） |
| `tsconfig.json` | TypeScript 設定（`strict`、`tsc` で `dist/` に出力） |
| `package.json` | `packageManager` で pnpm を固定 / devDeps に typescript・@types/node |
| `pnpm-lock.yaml` | 依存の固定（integrity）。`--frozen-lockfile` で厳格インストール |
| `pnpm-workspace.yaml` | pnpm のサプライチェーン設定（下記） |
| `Dockerfile` | multi-stage（prod-deps + tsc build + runtime）/ digest 固定 / 非 root / healthcheck |
| `docker-compose.yml` | 上記をビルドして起動する最小構成 |

## 使い方

```bash
corepack enable          # package.json の packageManager に従い pnpm を有効化
pnpm install             # pnpm-lock.yaml に従って導入
pnpm run typecheck       # 型チェック（tsc --noEmit）
pnpm run build           # tsc で dist/ に出力
pnpm start               # node dist/server.js（http://localhost:3000、/healthz）

# Docker（multi-stage で build まで実行）
docker compose up --build
```

## サプライチェーン対策（`pnpm-workspace.yaml`）

pnpm 11 の既定を踏まえつつ、意図を明示しています。

- **`minimumReleaseAge: 1440`** — 公開から 1 日経たない新規バージョンは解決しない（cooldown）。Renovate 側の cooldown と同じ思想をインストール時にも効かせる。緊急時は `minimumReleaseAgeExclude` で個別除外。
- **`blockExoticSubdeps: true`** — 非標準なサブ依存をブロック。
- **`allowBuilds: {}`** — 依存のライフサイクルスクリプト（postinstall 等）は既定でブロック。実行を許可するパッケージのみ allowlist に明示する。
- **`verifyDepsBeforeRun: error`** — スクリプト実行前に `node_modules` と lockfile の整合を検証し、ズレていれば**失敗させる**（fail-closed。`install` だと自動で入れ直してしまう）。

## このサンプルに効くチェック

リポジトリ共通の CI（`docker` ジョブ）とローカル prek hook で検証されます。

- `hadolint` — Dockerfile lint
- `pin-docker` — 全 `FROM` が `@sha256:` で digest 固定か
- `docker compose config` — compose 構文
- Renovate（`docker:pinDigests` / npm manager）— base image digest と `pnpm-lock.yaml` / `packageManager` を更新

詳細は [../../docs/design.md](../../docs/design.md) を参照。
