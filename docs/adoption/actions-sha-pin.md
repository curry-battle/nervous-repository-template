# actions-sha-pin（GitHub Actions の SHA 固定: pinact）

- 参照: 各 workflow の `uses:`、`pin-actions`ジョブ、`.pre-commit-config.yaml`(pinact)、`aqua.yaml`(`suzuki-shunsuke/pinact`)
- 抜き出すもの: `pr-validation.yml` の `pin-actions` ジョブ + `.pre-commit-config.yaml` の pinact ローカル hook + `aqua.yaml` の `suzuki-shunsuke/pinact` 行。
- AskUser:
  - CI の `pin-actions` 検証ジョブを置く / GitHub 純正 **Enforce SHA pinning** に任せる / 両方
- 生成: 対象リポで `aqua exec -- pinact run` を実行すると、全 workflow の `uses:` をタグから full SHA に書き換える（コピーした SHA はそのまま使わない）。
- 注意: SHA は**対象リポで解決し直す**（コピー禁止）。pinact は Docker 非対応（ベースイメージは `docker-hardening` の digest 固定で守る）。
- 検証: `aqua exec -- pinact run --check`（未 pin が無いこと）
- GitHub 手動設定: GitHub 純正 **Enforce SHA pinning** ポリシーを ON（任意）/ `pin-actions` ジョブを `main` の Branch protection で required check 化（任意・運用次第）
- 依存: `foundation`（ローカル hook 利用時）
