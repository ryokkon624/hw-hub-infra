# ephem TG を ALB に「関連付け」するだけのルール（通常アクセスでは踏まれないパス）
resource "aws_lb_listener_rule" "ephem_assoc" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 9999

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_ephem.arn
  }

  condition {
    path_pattern {
      values = ["/__ephem__/*"]
    }
  }
}