# secret-scan（secret スキャン: gitleaks）

- 参照: `security-audit.yml`(gitleaks ジョブ)、`.pre-commit-config.yaml`、`aqua.yaml`
- 抜き出すもの: `security-audit.yml` の `gitleaks` ジョブ（base-branch overlay step 込み）+ `.pre-commit-config.yaml` の gitleaks ローカル hook + `aqua.yaml` の `gitleaks/gitleaks` 行。
- AskUser:
  - **`.gitleaks.toml`(allowlist) の扱い**: 使う / 使わない / 初回スキャンで誤検知が出たら作る
- 生成: なし
- 注意: 導入時に **一度 `aqua exec -- gitleaks dir .` を実行して誤検知を確認**（lockfile のハッシュ等）。誤検知が出たら allowlist を作る。
- 検証: `aqua exec -- gitleaks dir .`（誤検知確認）
- GitHub 手動設定: `gitleaks` ジョブを `main` の Branch protection で required check 化（任意・運用次第）
- 依存: `foundation`
