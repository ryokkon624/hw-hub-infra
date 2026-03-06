resource "aws_cloudwatch_log_group" "batch" {
  name              = "/ecs/hwhub-batch-stg-ephem"
  retention_in_days = 7
}