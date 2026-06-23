# THREAT_MODEL — hw-hub-infra

Housework Hub のインフラ（Terraform / AWS）の脅威モデル。
IaC スキャン（tfsec/Trivy・Checkov）・シークレットスキャン（gitleaks）および LLM ベースの
レビューが、**何を守り・何を信頼し・何を対象外とするか**を共有するための土台ドキュメント。

> 本書は Anthropic「Using LLMs to secure source code」の Find-and-Fix ループ Step 1（Threat Modeling）に対応する。
> 2a の `security-scheduled-infra.yml`（Trivy config / gitleaks）が、下記 T1〜T4 の一部を機械的に検知する。

- 対象リポジトリ: `hw-hub-infra`
- 種別: AWS インフラを定義する Terraform（**設定ミスが信頼境界の穴になる**）
- 最終更新: 2026-06-23
- ステータス: ドラフト（Phase 0）

---

## 1. システムコンテキスト

| 項目         | 内容                                                                        |
| ------------ | --------------------------------------------------------------------------- |
| 構成         | `terraform/stg/`（STG・Ephemeral: 使用時 apply / 不使用時 destroy）＋ `terraform/stg-persistent/monitoring/`（RDS 自動停止）。PRD は一部 TODO |
| state        | S3 backend（`encrypt = true`）＋ DynamoDB lock                              |
| CI/CD        | GitHub Actions ＋ **OIDC**（static key ではなく一時 STS）                   |
| 主要リソース | ALB / ECS Fargate（backend・batch）/ RDS MySQL / S3 / CloudFront / VPC / Secrets Manager / IAM |
| ネットワーク | public(ALB/CloudFront) ─ private(ECS/RDS, `assign_public_ip=false`) ─ NAT  |

---

## 2. 守るべき資産（Assets）

| 資産                            | 説明                                                       | 影響度 |
| ------------------------------- | ---------------------------------------------------------- | ------ |
| Terraform state（S3）           | ARN・account id・Secrets Manager 参照を含む。暗号化＋lock済 | 高     |
| Secrets Manager の秘密          | JWT・DB パスワード・OAuth・Claude API キー・SES（ARN 参照）| 高     |
| IAM ロール / 信頼ポリシー        | ECS task role・実行ロール・OIDC ロール                     | 高     |
| RDS / S3 バケット               | file / knowledge / state バケット、DB                      | 高     |
| OIDC 信頼境界                   | GitHub Actions → AWS の認可                                 | 高     |

---

## 3. エントリポイント / 攻撃面（Entry points）

| #   | エントリポイント                          | 信頼できない入力 / リスク         |
| --- | ----------------------------------------- | --------------------------------- |
| E1  | ALB（public 80→443 redirect / 443）       | インターネットからの全リクエスト  |
| E2  | CloudFront（フロント配信）                | 同上                              |
| E3  | GitHub Actions OIDC ロール                | CI から AWS への権限（ECR/ECS）   |
| E4  | Terraform state（S3）                     | 窃取で構成・ARN・参照が露出        |
| E5  | `.tfvars` / ECS task の environment       | 機微値の置き場所                  |

---

## 4. 信頼境界（Trust boundaries）

```
[インターネット:信頼できない] ──> [ALB/CloudFront:public] ──SG──> [ECS:private] ──SG──> [RDS:private]
                                                                      │
                              [GitHub Actions] ──OIDC──> [AWS STS/IAM ロール（一時）]
                                                                      │
                                                  [Secrets Manager]（ECS が ARN 参照で取得）
```

**最重要原則: 信頼境界は IaC（Terraform）が定義する。設定ミス（IAM 過剰権限・公開設定・暗号化漏れ・ログ欠落）が境界の穴になる。**

---

## 5. 想定する脅威（What can go wrong?）

| ID  | 脅威                                                                                                   | 関連                                       | 重大度 |
| --- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------ | ------ |
| T1  | **IAM 過剰権限**: Lambda の RDS アクションが `Resource: "*"`／backend・batch が**同一 task role を共有** | `stg-persistent/monitoring/main.tf` / `terraform.tfvars` | 中     |
| T2  | **機微値の plaintext 構成**: `HWHUB_OAUTH_STATE_SECRET` が ECS task の **environment（非シークレット）** に平文 | `ecs_task_backend.tf`                       | 中     |
| T3  | **Terraform state の露出**: ARN・account id・Secrets 参照を含む（暗号化＋lock＋gitignore で緩和）       | `providers.tf` / state バケット            | 低〜中 |
| T4  | **監視盲点**: ALB アクセスログ・VPC Flow Logs 未設定                                                    | `alb.tf` 他                                | 低     |
| T5  | **OIDC ロールのスコープ**: PRD が STG ロールを流用（TODO）／信頼ポリシー（repo/branch）・権限範囲       | deploy ワークフロー / OIDC ロール          | 低〜中 |
| T6  | **SG / ネットワーク**: ingress `0.0.0.0/0`（80/443 は必要）／egress 全開放                              | `sg.tf`                                    | 低     |

### 補足（過大評価しないための整理）

- **T2 の現値は `"some-long-random-string"` のプレースホルダ**で、実秘密の漏洩ではない。問題は「機微値を Secrets Manager でなく plaintext environment に置く**構成パターン**」。本番投入前に Secrets Manager 化すべき。
- **コミット済みの実秘密・tfstate は無い**（`.gitignore` で `*.tfvars`（example を除く）・`*.tfstate`・`.terraform/` を除外。実秘密は Secrets Manager に ARN 参照のみ）。account id は deploy ワークフロー等で既出。

---

## 6. 現状の対策（既存コントロール）

- **認証**: GitHub Actions は **OIDC**（static key 不使用・一時 STS）。
- **シークレット**: Secrets Manager 経由（JWT・DB・OAuth・Claude・SES を ARN 参照で ECS に注入）。
- **state**: S3 backend 暗号化（`encrypt = true`）＋ DynamoDB lock。
- **ネットワーク**: ECS/RDS は private subnet（`assign_public_ip=false`）、SG 単位のホワイトリスト（ALB→ECS、ECS→RDS）。
- **TLS**: HTTP→HTTPS 強制リダイレクト、`ELBSecurityPolicy-TLS13-*`（TLS 1.3/1.2）、ACM 証明書。
- **監視**: CloudWatch Alarms（UnHealthyHost / 5xx）→ SNS 通知、ログ保持期間設定。
- **最小権限の例**: EventBridge Scheduler ロールはリソース ARN を限定、Lambda は source_account 制限。

---

## 7. 信頼する入力（Trusted inputs）

- **GitHub OIDC token**（AWS STS に対してのみ有効・一時）。
- **Terraform が管理する定義**（apply はレビュー済みの IaC を前提）。
- **Secrets Manager の値**（IaC のコードに実値は無く、ARN 参照のみ）。
- **EventBridge Scheduler のトリガー**。

---

## 8. スコープ外（Out of scope）

- 既存リソースの設定（RDS 暗号化/削除保護/バックアップ、CloudFront/S3 フロントの WAF、ACM、ECR、VPC/Subnet は「参照のみ・管理外」が多い）
- Secrets Manager の値そのもの・ローテーション運用
- アプリケーションロジック（認証・認可・SQLi 等）→ `hw-hub-backend` / `hw-hub-batch`
- AWS コンソールの直接操作・認証情報の物理的盗難

> 既存リソースの未管理項目（RDS 暗号化等）は IaC に現れないため、ここを根拠に「未対策」と断ずる指摘は、管理外であることを確認してからトリアージする。

---

## 9. レビュー観点チェック（Did we do a good job?）

1. IAM が最小権限か（`Resource: "*"`・ワイルドカードアクション・ロール共有が無いか）
2. 機微値が environment 平文でなく Secrets Manager に置かれているか（T2）
3. Terraform state バケットの公開ブロック・暗号化・バージョニングが有効か
4. ALB アクセスログ・VPC Flow Logs 等の監査ログが有効か
5. SG の ingress/egress が必要最小か（不要な全開放が無いか）
6. OIDC ロールの信頼ポリシー（repo/branch 限定）と権限範囲が適切か（PRD 分離）
7. tfsec/Trivy・gitleaks の検知（2a の定期スキャン）の棚卸し

---

## 10. 更新運用

- リソース追加・IAM/SG/公開設定・シークレット供給・OIDC ロールの変更時に本書を更新する。
- 2a の `security-scheduled-infra.yml` の検知はトリアージ後 `hw-hub-manage` に Issue 化し、Sprint backlog に合流させる。
- Retro でセキュリティ指摘を棚卸しする際、本書の見直し要否を確認する。
