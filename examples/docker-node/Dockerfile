# サンプル Dockerfile（pnpm + TypeScript / multi-stage / 実アプリに差し替える前提）。
# ベースイメージは tag + full digest で固定（CI の pin-docker が強制 / Renovate が digest を更新）。
FROM node:22-alpine@sha256:9385cd9f3001dfc3431e8ead12c43e9e1f87cc1b9b5c6cfd0f73865d405b27c4 AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
# package.json の packageManager に従い pnpm を有効化
RUN corepack enable
WORKDIR /app

# 本番依存だけを解決（runtime 用の node_modules）。store は BuildKit cache mount で共有。
FROM base AS prod-deps
# .npmrc も先に COPY する（pnpm fetch がレジストリ設定を読むため。registry を Takumi Guard に向ける）
COPY pnpm-lock.yaml .npmrc ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm fetch --prod
COPY package.json pnpm-workspace.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --prod --offline --frozen-lockfile

# dev 依存込みで TypeScript をコンパイル
FROM base AS build
COPY pnpm-lock.yaml .npmrc ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm fetch
COPY package.json pnpm-workspace.yaml tsconfig.json server.ts ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --offline --frozen-lockfile
RUN pnpm run build

FROM base AS runtime
ENV NODE_ENV=production
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./
# 非 root で実行（node イメージ同梱の node ユーザ）
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/healthz').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"
CMD ["node", "dist/server.js"]
