############################################
# CloudWatch Alarm (STG / ephem backend)
############################################

############################################
# 1. TargetGroup Unhealthy Host
############################################
resource "aws_cloudwatch_metric_alarm" "tg_unhealthy_host" {
  alarm_name        = "hwhub-stg-ephem-tg-unhealthy-host"
  alarm_description = "ephem TargetGroup has unhealthy hosts"

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"
  statistic   = "Maximum"
  period      = 60

  # デプロイ中の一時的なコンテナ入れ替えでは発火しないよう3分連続に変更
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.backend_ephem.arn_suffix
    LoadBalancer = aws_lb.api.arn_suffix
  }

  alarm_actions = [data.aws_sns_topic.stg_alerts.arn]
  ok_actions    = [data.aws_sns_topic.stg_alerts.arn]

  tags = {
    Environment = "stg"
    ManagedBy   = "terraform"
  }
}

############################################
# 2. ALB-generated 5xx
############################################
resource "aws_cloudwatch_metric_alarm" "alb_elb_5xx" {
  alarm_name        = "hwhub-stg-alb-elb-5xx"
  alarm_description = "ALB returned ELB-side 5xx responses"

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_ELB_5XX_Count"
  statistic   = "Sum"
  period      = 60

  # ALB側の5xxは重大なので1分のままにするが3連続に変更
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.api.arn_suffix
  }

  alarm_actions = [data.aws_sns_topic.stg_alerts.arn]
  ok_actions    = [data.aws_sns_topic.stg_alerts.arn]

  tags = {
    Environment = "stg"
    ManagedBy   = "terraform"
  }
}

############################################
# 3. Target-generated 5xx
############################################
resource "aws_cloudwatch_metric_alarm" "alb_target_5xx" {
  alarm_name        = "hwhub-stg-ephem-target-5xx"
  alarm_description = "Backend returned target-side 5xx responses"

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_Target_5XX_Count"
  statistic   = "Sum"
  period      = 60

  # デプロイ中の一時的な5xxでは発火しないよう3分連続に変更
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.backend_ephem.arn_suffix
    LoadBalancer = aws_lb.api.arn_suffix
  }

  alarm_actions = [data.aws_sns_topic.stg_alerts.arn]
  ok_actions    = [data.aws_sns_topic.stg_alerts.arn]

  tags = {
    Environment = "stg"
    ManagedBy   = "terraform"
  }
}