locals {
  batch_schedules = {
    notification_aggregate_every_4h_jst = {
      name = "hwhub-batch-stg-notification-aggregate-every-4h-jst"
      cron = "cron(30 0/4 * * ? *)"
      tz   = "Etc/GMT-9"
      cmd  = ["--spring.batch.job.name=notificationAggregationJob"]
    }

    household_cleanup_monthly_15_0000_jst = {
      name = "hwhub-batch-stg-household-cleanup-monthly-15-0000-jst"
      cron = "cron(0 0 15 * ? *)"
      tz   = "Asia/Tokyo"
      cmd  = ["--spring.batch.job.name=householdCleanupJob"]
    }

    housework_recalc_hourly = {
      name = "hwhub-batch-stg-housework-recalc-hourly"
      cron = "cron(0 * * * ? *)"
      tz   = "Etc/GMT-9"
      cmd  = ["--spring.batch.job.name=houseworkTaskRecalcJob"]
    }

    housework_generate_daily_0300_jst = {
      name = "hwhub-batch-stg-housework-generate-daily-0300-jst"
      cron = "cron(0 18 * * ? *)"
      tz   = "UTC"
      cmd  = ["--spring.batch.job.name=houseworkTaskGenerateJob"]
    }

    invitation_expire_daily_0100_jst = {
      name = "hwhub-batch-stg-invitation-expire-daily-0100-jst"
      cron = "cron(0 16 * * ? *)"
      tz   = "UTC"
      cmd  = ["--spring.batch.job.name=invitationExpireJob"]
    }
  }
}

resource "aws_scheduler_schedule" "batch" {
  for_each = local.batch_schedules

  name                         = each.value.name
  group_name                   = "default"
  schedule_expression          = each.value.cron
  schedule_expression_timezone = each.value.tz
  state                        = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_ecs_cluster.this.arn
    role_arn = var.batch_scheduler_role_arn

    input = jsonencode({
      containerOverrides = [
        {
          name    = var.batch_container_name
          command = each.value.cmd
        }
      ]
    })

    ecs_parameters {
      task_definition_arn     = aws_ecs_task_definition.batch.arn
      launch_type             = "FARGATE"
      task_count              = 1
      enable_ecs_managed_tags = true

      network_configuration {
        subnets          = var.private_subnet_ids
        security_groups  = [aws_security_group.batch.id]
        assign_public_ip = false
      }
    }

    retry_policy {
      maximum_event_age_in_seconds = 86400
      maximum_retry_attempts       = 0
    }
  }
}