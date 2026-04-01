# Terraform Structure Policy (HwHub)

This document describes the Terraform structure and management policy
used in the HwHub project.

------------------------------------------------------------------------

# Goals

The Terraform configuration is designed with the following goals:

-   clear separation of infrastructure responsibilities
-   maintainable long‑term structure
-   safe ephemeral environments
-   easy understanding for future maintainers (including future you)

------------------------------------------------------------------------

# Environment Strategy

The staging environment uses a **single Terraform directory** that
manages both persistent and ephemeral resources together.

The original `stg-core / stg-ephemeral` split was considered but not
adopted. Instead, the entire environment is managed as one unit with
`terraform apply` / `terraform destroy`.

## What gets created on `terraform apply`

-   ALB (Application Load Balancer)
-   ALB Security Group
-   ALB Listeners (HTTP:80 redirect / HTTPS:443 forward)
-   Target Group
-   ECS Cluster
-   ECS Backend Service + Task Definition
-   ECS Batch Task Definition
-   EventBridge Scheduler
-   CloudWatch Log Groups
-   CloudWatch Alarms
-   Route 53 A Record (api.familyapp-hwhub.com)

## What persists after `terraform destroy`

-   RDS MySQL (existing, referenced via data source)
-   ACM Certificate (existing, referenced via variable)
-   ECR Repositories (existing)
-   S3 Buckets (existing)
-   Secrets Manager (existing)
-   SNS Topic (existing, referenced via data source)
-   CloudFront (existing)
-   Route 53 Hosted Zone (existing, referenced via data source)
-   VPC / Subnets / Route Tables (existing)
-   S3 Gateway VPC Endpoint (free, persistent)

------------------------------------------------------------------------

# Ephemeral Operations

## Cost profile

| State | Daily cost (approx) |
|-------|-------------------|
| apply (running) | ~$5.71/day |
| destroy (stopped) | ~$0.09/day (RDS storage only) |

## Typical workflow

```bash
# Start environment for development / testing
terraform apply

# Stop environment when not in use
terraform destroy

# RDS can be manually stopped from AWS Console for further savings
# Note: RDS auto-restarts after 7 days
```

------------------------------------------------------------------------

# Terraform Directory Structure

```text
terraform/stg/

main.tf
providers.tf
variables.tf
terraform.tfvars
outputs.tf

nat.tf                      # NAT Gateway + EIP
routes.tf                   # Route table associations
sg.tf                       # ALB Security Group
sg_rules.tf                 # ECS / RDS SG rules
rds_sg_rules.tf             # RDS inbound rules

alb.tf                      # ALB + Target Group + Listeners + Route53 record
listeners_rule_ephem_assoc.tf  # Listener rule for ephem TG

ecs_cluster.tf              # ECS Cluster
ecs_task_backend.tf         # Backend Task Definition
ecs_service_backend.tf      # Backend ECS Service
logs.tf                     # Backend CloudWatch Log Group

ecs_task_batch.tf           # Batch Task Definition
log_group_batch.tf          # Batch CloudWatch Log Group

scheduler.tf                # EventBridge Scheduler

alarm.tf                    # CloudWatch Alarms
sns.tf                      # SNS Topic reference
```

------------------------------------------------------------------------

# Resource Ownership Rules

## Managed by Terraform

| Resource | File |
|----------|------|
| ALB | alb.tf |
| ALB Security Group | sg.tf |
| ALB Listeners | alb.tf |
| Target Group | alb.tf |
| Route 53 A Record | alb.tf |
| ECS Cluster | ecs_cluster.tf |
| ECS Backend Service | ecs_service_backend.tf |
| ECS Backend Task Definition | ecs_task_backend.tf |
| ECS Batch Task Definition | ecs_task_batch.tf |
| EventBridge Scheduler | scheduler.tf |
| CloudWatch Log Groups | logs.tf / log_group_batch.tf |
| CloudWatch Alarms | alarm.tf |
| Security Group rules | sg_rules.tf / rds_sg_rules.tf |

## Referenced but not managed (data sources / variables)

| Resource | How referenced |
|----------|---------------|
| RDS MySQL | data source |
| ACM Certificate | var.certificate_arn |
| ECR Repositories | var.ecr_repository_url |
| Secrets Manager | ECS task definition env |
| SNS Topic | data source |
| S3 Buckets | existing |
| CloudFront | existing |
| VPC / Subnets | var.vpc_id / var.public_subnet_ids |
| Route 53 Hosted Zone | data source |

------------------------------------------------------------------------

# Import History

Resources that were migrated from manual creation to Terraform management:

| Resource | Import date | Note |
|----------|-------------|------|
| aws_lb.api | 2026-03 | Migrated from data source to resource |
| aws_security_group.alb | 2026-03 | Migrated from data source to resource |
| aws_route53_record.api | 2026-03 | Migrated from manual to Terraform |

------------------------------------------------------------------------

# Design Principles

-   infrastructure as code
-   clear logical grouping of resources
-   environment isolation
-   minimal manual configuration in AWS Console
-   ephemeral-first: destroy when not in use to minimize cost

------------------------------------------------------------------------

# Known Residual Resources (not Terraform managed)

The following resources exist in AWS but are not managed by Terraform.
They are safe to leave or clean up manually.

| Resource | Name | Action |
|----------|------|--------|
| Security Group | hwhub-ses-smtp-endpoint-stg | Can delete if SES VPC endpoint removed |
| Security Group | hwhub-vpce-sg-stg | Can delete if VPC endpoints removed |
| Security Group | launch-wizard-1 | Can delete (auto-created, unused) |
| VPC Endpoint | hwhub-vpce-s3-stg | Keep (Gateway type = free) |

------------------------------------------------------------------------

# Future Improvements

-   module化
-   PRD 用ディレクトリ分離
-   監視項目追加（CPU / Memory / RDS / Scheduler failure）
-   README / Runbook 充実
