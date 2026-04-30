terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = "hwhub-terraform-state-apne1"
    key            = "stg/persistent/monitoring/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "hwhub-terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "archive_file" "rds_auto_stop" {
  type        = "zip"
  source_file = "${path.module}/lambda/rds_auto_stop.py"
  output_path = "${path.module}/lambda/rds_auto_stop.zip"
}

# ─────────────────────────────────────────────
# IAM — Lambda execution role
# ─────────────────────────────────────────────

resource "aws_iam_role" "rds_auto_stop_lambda" {
  name = "stg-persistent-rds-auto-stop-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "rds_auto_stop_lambda" {
  name = "stg-persistent-rds-auto-stop-lambda"
  role = aws_iam_role.rds_auto_stop_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/stg-persistent-rds-auto-stop:*"
      },
      {
        Effect   = "Allow"
        Action   = ["rds:StopDBInstance", "rds:DescribeDBInstances"]
        Resource = "*"
      },
      {
        # Create one-time delayed-stop schedules; DELETE is handled by the scheduler role
        Effect = "Allow"
        Action = "scheduler:CreateSchedule"
        Resource = "arn:aws:scheduler:${var.aws_region}:${data.aws_caller_identity.current.account_id}:schedule/default/stg-persistent-rds-*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.rds_auto_stop_scheduler.arn
      },
    ]
  })
}

# ─────────────────────────────────────────────
# IAM — EventBridge Scheduler execution role
# ─────────────────────────────────────────────

resource "aws_iam_role" "rds_auto_stop_scheduler" {
  name = "stg-persistent-rds-auto-stop-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "rds_auto_stop_scheduler" {
  name = "stg-persistent-rds-auto-stop-scheduler"
  role = aws_iam_role.rds_auto_stop_scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.rds_auto_stop.arn
      },
      {
        # Required for ActionAfterCompletion=DELETE on one-time schedules
        Effect = "Allow"
        Action = "scheduler:DeleteSchedule"
        Resource = "arn:aws:scheduler:${var.aws_region}:${data.aws_caller_identity.current.account_id}:schedule/default/stg-persistent-rds-*"
      },
    ]
  })
}

# ─────────────────────────────────────────────
# Lambda
# ─────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "rds_auto_stop" {
  name              = "/aws/lambda/stg-persistent-rds-auto-stop"
  retention_in_days = 14
}

resource "aws_lambda_function" "rds_auto_stop" {
  filename         = data.archive_file.rds_auto_stop.output_path
  source_code_hash = data.archive_file.rds_auto_stop.output_base64sha256
  function_name    = "stg-persistent-rds-auto-stop"
  role             = aws_iam_role.rds_auto_stop_lambda.arn
  handler          = "rds_auto_stop.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      RDS_INSTANCE_IDENTIFIER = var.rds_instance_identifier
      AUTO_STOP_DELAY_MINUTES = tostring(var.auto_stop_delay_minutes)
      SCHEDULER_ROLE_ARN      = aws_iam_role.rds_auto_stop_scheduler.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.rds_auto_stop]
}

# ─────────────────────────────────────────────
# EventBridge Rule — RDS-EVENT-0088 (instance started)
# ─────────────────────────────────────────────

resource "aws_cloudwatch_event_rule" "rds_started" {
  name        = "stg-persistent-rds-started"
  description = "Detects RDS-EVENT-0088 (DB instance started) for ${var.rds_instance_identifier}"

  event_pattern = jsonencode({
    source      = ["aws.rds"]
    detail-type = ["RDS DB Instance Event"]
    detail = {
      EventID          = ["RDS-EVENT-0088"]
      SourceIdentifier = [var.rds_instance_identifier]
    }
  })
}

resource "aws_cloudwatch_event_target" "rds_started_lambda" {
  rule = aws_cloudwatch_event_rule.rds_started.name
  arn  = aws_lambda_function.rds_auto_stop.arn
}

resource "aws_lambda_permission" "allow_eventbridge_rule" {
  statement_id  = "AllowEventBridgeRule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_auto_stop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rds_started.arn
}

# ─────────────────────────────────────────────
# EventBridge Scheduler — daily forced stop 02:00 JST (UTC 17:00)
# ─────────────────────────────────────────────

resource "aws_scheduler_schedule" "rds_force_stop_daily" {
  name                         = "stg-persistent-rds-force-stop-daily"
  group_name                   = "default"
  schedule_expression          = "cron(0 17 * * ? *)"
  schedule_expression_timezone = "UTC"
  state                        = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.rds_auto_stop.arn
    role_arn = aws_iam_role.rds_auto_stop_scheduler.arn

    input = jsonencode({ action = "stop" })

    retry_policy {
      maximum_event_age_in_seconds = 3600
      maximum_retry_attempts       = 0
    }
  }
}

# Covers both the static daily schedule and dynamic one-time schedules created at runtime.
# source_account restricts to this account to prevent confused deputy attacks.
resource "aws_lambda_permission" "allow_scheduler" {
  statement_id   = "AllowEventBridgeScheduler"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.rds_auto_stop.function_name
  principal      = "scheduler.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}
