resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/hwhub-backend-stg-ephem"
  retention_in_days = 14
}