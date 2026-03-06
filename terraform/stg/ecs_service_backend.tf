resource "aws_ecs_service" "backend" {
  name            = "hwhub-backend-stg-ephem"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_desired_count
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 120

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.backend.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_ephem.arn
    container_name   = local.backend_container_name
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }

  depends_on = [
    aws_lb_target_group.backend_ephem,
    aws_lb_listener.https
  ]
}