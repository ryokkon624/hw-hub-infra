resource "aws_ecs_task_definition" "batch" {
  family                   = "hwhub-batch-stg-ephem"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  # keep existing roles (same as your JSON)
  task_role_arn      = var.batch_task_role_arn
  execution_role_arn = var.batch_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "hwhub-batch"
      image     = var.batch_image
      essential = true

      environment = [
        { name = "SPRING_DATASOURCE_USERNAME", value = "hwhub_app" },
        { name = "SPRING_DATASOURCE_URL", value = "jdbc:mysql://hwhub-mysql-stg.c1o42eyisztt.ap-northeast-1.rds.amazonaws.com:3306/hwhub_db?useSSL=false&characterEncoding=utf8&serverTimezone=Asia/Tokyo&sessionVariables=time_zone='%2B09:00'" },
        { name = "SPRING_PROFILES_ACTIVE", value = "stg" },
        { name = "KNOWLEDGE_S3_BUCKET", value = "hwhub-stg-knowledge" },
      ]

      secrets = [
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = var.batch_datasource_password_secret_arn
        },
        {
          name      = "CLAUDE_API_KEY"
          valueFrom = var.claude_api_key_secret_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.batch.name
          awslogs-region        = "ap-northeast-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}