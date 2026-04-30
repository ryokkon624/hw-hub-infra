output "lambda_function_name" {
  value = aws_lambda_function.rds_auto_stop.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.rds_auto_stop.arn
}

output "eventbridge_rule_name" {
  value = aws_cloudwatch_event_rule.rds_started.name
}

output "daily_scheduler_name" {
  value = aws_scheduler_schedule.rds_force_stop_daily.name
}
