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

  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.backend_ephem.arn_suffix
    LoadBalancer = data.aws_lb.api.arn_suffix
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

  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer = data.aws_lb.api.arn_suffix
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

  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.backend_ephem.arn_suffix
    LoadBalancer = data.aws_lb.api.arn_suffix
  }

  alarm_actions = [data.aws_sns_topic.stg_alerts.arn]
  ok_actions    = [data.aws_sns_topic.stg_alerts.arn]

  tags = {
    Environment = "stg"
    ManagedBy   = "terraform"
  }
}