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

The staging environment is divided into two logical groups.

## stg-core (persistent infrastructure)

These components exist permanently and should normally not be destroyed.

Examples:

-   VPC
-   Subnets
-   Route Tables
-   Security Groups
-   RDS MySQL
-   ECR repositories
-   S3 buckets
-   Secrets Manager

These components represent the **stable foundation of the system**.

------------------------------------------------------------------------

## stg-ephemeral (temporary infrastructure)

These components may be created and destroyed during testing or
experimentation.

Examples:

-   NAT Gateway
-   ALB (Application Load Balancer)
-   Target Groups
-   ECS Cluster
-   ECS Services
-   ECS Task Definitions
-   EventBridge Scheduler
-   Interface VPC Endpoints
-   CloudWatch Alarms

These are considered **runtime infrastructure**.

------------------------------------------------------------------------

# Terraform Directory Structure

Example structure:

    terraform/
     └ stg/
        ├ networking/
        │   ├ nat.tf
        │   ├ routes.tf
        │   ├ sg.tf
        │   └ sg_rules.tf
        │
        ├ alb/
        │   ├ alb.tf
        │   └ listener_rules.tf
        │
        ├ ecs/
        │   ├ ecs_cluster.tf
        │   ├ ecs_service_backend.tf
        │   ├ ecs_task_backend.tf
        │   └ ecs_task_batch.tf
        │
        ├ scheduler/
        │   └ scheduler.tf
        │
        ├ monitoring/
        │   ├ alarm.tf
        │   └ sns.tf
        │
        └ variables.tf

------------------------------------------------------------------------

# Resource Ownership Rules

Terraform **manages only selected resources**.

Managed by Terraform:

-   ECS services
-   ECS batch tasks
-   networking configuration
-   monitoring and alarms
-   scheduled jobs

Referenced but not managed:

-   CloudFront
-   S3 static hosting
-   existing ALB (if reused)
-   existing RDS (depending on setup)

------------------------------------------------------------------------

# Design Principles

Terraform code follows these principles:

-   infrastructure as code
-   clear logical grouping of resources
-   environment isolation
-   minimal manual configuration in AWS Console

------------------------------------------------------------------------

# Future Improvements

Possible future improvements include:

-   full environment separation (dev / stg / prod)
-   reusable Terraform modules
-   automated Terraform pipelines
