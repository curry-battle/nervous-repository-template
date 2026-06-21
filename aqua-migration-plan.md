# aqua 移行計画（CLI ツールの provisioning を mise → mise+aqua へ）

> **SUPERSEDED**: この計画メモは `.plans/aqua-migration.md`（Approved の design-doc）に置き換わった。
> 実装は同 design-doc を SoT とすること。本ファイルは経緯確認のための historical memo として残す。
>
> ステータス: ドラフト（未着手 / commit していない作業メモ）
> 関連: PR #6（examples 分割＋依存監査）の議論から派生。二重管理・手動 sha256・trivy 特例を根絶するための後続リファクタ。

## 1. 背景 / 解決したい問題

現状、CLI ツールの版は **2 か所**に書かれて drift しうる（＝二重管理）:

- **cargo-deny**: `mise.toml`（Renovate が更新）↔ `pr-validation.yml` の `CARGO_DENY_VERSION`/`SHA256`（手動）
- **pnpm**: `examples/docker-node/package.json` の `packageManager`（Renovate）↔ workflow `PNPM_VERSION`/`SHA256`（手動）

根本原因は「**CI で `mise install` を走らせない**」方針（PR 由来の任意コード実行を断つため）→ workflow で手動 DL し直す → 二重化。
加えて **trivy は mise が checksum を lock できない**（`asset_pattern` が単一プラットフォーム固定）ため workflow 手動 pin の特例になっている。

これらは「CLI ツールを version＋checksum で固定しつつ自動更新する」という普遍的課題で、定番解が **aqua（aquaproj）**。aqua の install は **検証済みバイナリ取得＋checksum 検証のみ・コード実行なし**なので、信頼できない CI 設定でも安全に install でき、二重管理の発生源を断てる。

## 2. ゴール / 方針

- **mise = 言語ランタイム（node / rust 等）＋ aqua のブートストラップ**
- **aqua = CLI ツール（prek / pinact / ghalint / gitleaks / cargo-deny / trivy / pnpm の 7 ツール）の version＋checksum 固定**
- **hadolint は aqua の対象外**（CI=hadolint-action / ローカル=remote pre-commit hook の従来経路を維持。2 経路で管理が分裂するのを避ける）
- **二重管理・手動 sha256・trivy 特例を解消**。Renovate（`aqua-renovate-config`）＋ `update-checksum-action` で **version も checksum も自動追従**。
>
> 注: 上記の方針記述は最終 design-doc (`.plans/aqua-migration.md`) で更新済み。本メモは historical なので残置。

## 3. アーキテクチャ（after）

```
mise.toml / mise.lock
  ├─ node / rust ...（言語ランタイム。新規に mise 管理へ）
  └─ aqua（バイナリ1本。ローカルのブートストラップ）

aqua.yaml / aqua-checksums.json   ← Renovate + update-checksum-action が自動追従
  └─ prek / pinact / ghalint / gitleaks / cargo-deny / trivy / pnpm (7 ツール)
（hadolint は aqua 対象外＝CI hadolint-action / ローカル remote pre-commit hook）

CI:
  aqua-installer（版＋checksum pin）で aqua を入れ → `aqua install` で各ツールを checksum 検証取得 → 実行
```

ポイント: **ツールの二重管理を消す主役は aqua 本体**。mise は「ランタイム」と「aqua のローカル入口」に役割を縮小する。

## 4. 何が replace / 残る / 新規

### replace される
| 現状 | → after |
|---|---|
| `mise.toml` `[tools]` の CLI ツール群 ＋ `mise.lock` の該当 checksum | **`aqua.yaml` ＋ `aqua-checksums.json`** |
| `pr-validation.yml` の手動 DL ブロック ×4（ghalint / gitleaks / cargo-deny / trivy の `*_VERSION`+`*_SHA256`+curl+`sha256sum -c`） | **`aqua install` ＋ ツール実行** |
| `scripts/check-mise-locked.sh` ＋ `mise-locked` CI ジョブ（CLI ツール分） | **aqua の checksum 検証**（＋任意で `aqua update-checksum --check` を CI に） |
| 二重管理 / 手動 sha256 / **trivy 特例** | **消滅** |

### 残る（aqua の領分外）
- **mise 本体**（役割変更: 言語ランタイム ＋ aqua bootstrap）
- **pinact / prek の役割**（aqua は install するだけ。SHA 固定・hook 実行は不変）
- **`.pre-commit-config.yaml`**（hook 定義は残る。ツール入手元を mise→aqua に向け直す＝`aqua exec -- <tool>` 等／aqua の PATH に乗せる）
- **Renovate**（mise manager は runtimes+aqua 用に残し、**aqua manager を追加**。Actions/Docker/npm/cargo manager はそのまま）
- **ツール本体の設定**: `deny.toml` / `.gitleaks.toml` / hadolint 設定 等
- **`scripts/check-docker-digests.sh` / `check-vocab-sync.sh` / `check-hook-rev-sha.sh`**（provisioning と無関係）
- **Docker base digest 固定・`Cargo.lock`・`pnpm-lock.yaml`・`package.json`**（アプリ依存/イメージ）

### 新規追加
- `aqua.yaml`（ツール宣言）
- `aqua-checksums.json`（全プラットフォーム checksum）
- `update-checksum-action` を使う workflow（Renovate PR 上で `aqua-checksums.json` を自動再生成・commit）
- CI の aqua ブートストラップ（`aqua-installer`）
- `renovate.json5` に `aqua-renovate-config` preset

## 5. ツール別マッピング

| ツール | 現状 | after |
|---|---|---|
| prek | mise（aqua backend） | aqua |
| pinact | mise | aqua |
| hadolint | mise | **aqua 対象外**（CI hadolint-action / ローカル remote pre-commit hook） |
| ghalint | mise ＋ workflow 手動 DL | aqua |
| gitleaks | mise ＋ workflow 手動 DL | aqua |
| cargo-deny | mise（aqua backend）＋ workflow 手動 DL | aqua（aqua-checksums.json で全プラットフォーム固定） |
| trivy | workflow 手動 DL のみ（mise 外） | aqua（**asset/checksum を正しく解決＝特例解消**） |
| pnpm | workflow 手動 DL（version は packageManager 連動） | **要判断**（§7。packageManager との二重化を避けるなら aqua に入れない案も） |
| node / rust（ランタイム） | system 依存（mise 管理外） | **mise 管理へ（新規）** |

## 6. 段階的移行（フェーズ）

- **Phase 0: 並走導入**
  - `aqua.yaml` ＋ `aqua-checksums.json` を作り、ローカルで `aqua install` が動くこと・各ツールが既存版どおり入ることを確認（mise と二重に持って差分検証）。
- **Phase 1: CLI ツールを aqua へ**
  - workflow の手動 DL ジョブ（ghalint/gitleaks/cargo-deny/trivy）を `aqua install` ＋ 実行に置換。
  - `.pre-commit-config.yaml` の各 hook の entry を aqua 経由に向け直す。
  - `mise.toml` から CLI ツールを除去。
- **Phase 2: mise をランタイム＋aqua bootstrap に再定義**
  - `mise.toml` に node / rust 等のランタイムを追加（必要な版を AskUser）。`aqua` も mise に追加（ローカル bootstrap）。
  - `mise lock` で `mise.lock` を再生成。
- **Phase 3: 検証ジョブ・自動化の差し替え**
  - `mise-locked` ジョブ / `check-mise-locked.sh` は **ランタイム＋aqua のみ**を対象に縮小（または aqua の checksum 検証に一本化）。
  - `update-checksum-action` を CI に追加（Renovate PR で `aqua-checksums.json` 自動更新）。
  - `renovate.json5` に `aqua-renovate-config` を追加。mise manager は runtimes 用に維持。
- **Phase 4: ドキュメント更新**
  - `docs/design.md`（依存の監査 / 外部依存の固定 / ファイル一覧）、`docs/adoption-guide.md`（モジュール F・H・I・M 等の参照、新規「aqua」基盤）、`README.md`、`todo.md` を更新。
  - 「二重管理・手動 sha256・trivy 特例」の旧記述を削除/置換。

## 7. 未解決の決定事項（着手前に AskUser）

1. **言語ランタイムの版**: node（example は 22 系）、rust（MSRV 1.80 / 安定版どちら）を mise でどの版に固定するか。CI でランタイムを mise から入れるか、runner 既設を使うか（例: cargo-deny は `cargo metadata` に cargo が要る → runner 既設 cargo を使うか mise 管理 rust にするか）。
2. **pnpm の扱い**: aqua に入れる（CI provisioning を統一）か、`packageManager` 連動のまま据え置く（二重化回避）か。CI の `pnpm-audit` をどちらの pnpm で回すか。
3. **aqua ブートストラップの単一化**: aqua の版が「mise.toml（ローカル）」と「CI の aqua-installer」の2か所に出る → aqua 版の mini 二重管理を防ぐため、両方 Renovate 管理にして許容するか、片方をソースにするか。
4. **prek / pinact を aqua に寄せるか**: prek は hook runner、pinact は SHA 固定。aqua 管理に統一するか、prek だけ別経路にするか（bootstrap 順序: aqua → prek → hooks）。
5. **CI で `aqua install` を許容するか**: aqua の install はコード実行なし＝従来 paranoia と両立する想定だが、「CI で provisioning を一切走らせない」現行思想をどこまで緩めるか明文化する。

## 8. 検証（移行後）

- `aqua install` が checksum 検証し、trivy が正しい per-platform asset を取得、cargo-deny 0.19 系、各ツールが従来どおり動く。
- Renovate dry-run で `aqua-renovate-config`（版）＋ `update-checksum-action`（checksum）が回る。
- `pr-validation.yml` 全ジョブ緑（負例でも各監査が fail することを確認）。
- ローカル `prek` の各 hook が aqua 経由ツールで動く（未インストール時 skip の挙動も確認）。

## 9. 参考

- aqua — Update packages by Renovate: https://aquaproj.github.io/docs/guides/renovate/
- aqua — Enable Checksum Verification: https://aquaproj.github.io/docs/guides/checksum/
- update-checksum-action: https://aquaproj.github.io/docs/products/update-checksum-action/
- 例（CI で aqua-checksums.json を自動更新）: https://github.com/aquaproj/example-update-checksum
- Checksum Verification by aqua（suzuki-shunsuke ＝ ghalint/pinact 作者）: https://dev.to/suzukishunsuke/checksum-verification-by-aqua-5038
