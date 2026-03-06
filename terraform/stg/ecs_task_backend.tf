locals {
  backend_container_name = "hwhub-backend"
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "hwhub-backend-ephem"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.backend_cpu)
  memory                   = tostring(var.backend_memory)

  execution_role_arn = var.ecs_execution_role_arn
  task_role_arn      = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = local.backend_container_name
      image     = var.backend_image
      essential = true

      portMappings = [
        {
          name          = "http"
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      environment = [
        { name = "SPRING_DATASOURCE_USERNAME", value = "hwhub_app" },
        { name = "SES_SMTP_HOST", value = "email-smtp.ap-northeast-1.amazonaws.com" },
        { name = "HWHUB_OAUTH_STATE_SECRET", value = "some-long-random-string" },
        { name = "SPRING_DATASOURCE_URL", value = "jdbc:mysql://hwhub-mysql-stg.c1o42eyisztt.ap-northeast-1.rds.amazonaws.com:3306/hwhub_db?useSSL=false&characterEncoding=utf8&serverTimezone=Asia/Tokyo&sessionVariables=time_zone='%2B09:00'" },
        { name = "HWHUB_OBJECT_STORAGE_BUCKET", value = "hwhub-stg-file" },
        { name = "SPRING_PROFILES_ACTIVE", value = "stg" }
      ]

      secrets = [
        { name = "HWHUB_JWT_SECRET", valueFrom = "arn:aws:secretsmanager:ap-northeast-1:564323392873:secret:hwhub/stg/backend/HWHUB_JWT_SECRET-9GFieS" },
        { name = "SES_SMTP_PASSWORD", valueFrom = "arn:aws:secretsmanager:ap-northeast-1:564323392873:secret:hwhub/stg/ses/smtp-fwXtdM:password::" },
        { name = "SES_SMTP_USER", valueFrom = "arn:aws:secretsmanager:ap-northeast-1:564323392873:secret:hwhub/stg/ses/smtp-fwXtdM:username::" },
        { name = "SPRING_DATASOURCE_PASSWORD", valueFrom = "arn:aws:secretsmanager:ap-northeast-1:564323392873:secret:hwhub/stg/backend/SPRING_DATASOURCE_PASSWORD-KRxqmr" },
        { name = "GOOGLE_OAUTH_CLIENT_ID", valueFrom = "arn:aws:secretsmanager:ap-northeast-1:564323392873:secret:hwhub/stg/oauth/google-A1guPX:clientId::" },
        { name = "GOOGLE_OAUTH_CLIENT_SECRET", valueFrom = "arn:aws:secretsmanager:ap-northeast-1:564323392873:secret:hwhub/stg/oauth/google-A1guPX:clientSecret::" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.backend.name
          awslogs-region        = "ap-northeast-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}