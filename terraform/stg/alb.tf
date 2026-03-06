# 既存ALB参照（hwhub-alb-stg）
data "aws_lb" "api" {
  arn = var.alb_arn
}

# ephem用TGを新規作成
resource "aws_lb_target_group" "backend_ephem" {
  name        = "hwhub-backend-stg-ephem-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/actuator/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    matcher             = "200-399"
  }

  tags = { Name = "hwhub-backend-stg-ephem-tg" }
}

# HTTP:80 -> HTTPS:443 redirect
resource "aws_lb_listener" "http" {
  load_balancer_arn = data.aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
      host        = "#{host}"
      path        = "/#{path}"
      query       = "#{query}"
    }
  }
}

# HTTPS:443 -> TG forward
resource "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.api.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_ephem.arn
  }
}

locals {
  existing_alb_sg_id = tolist(data.aws_lb.api.security_groups)[0]
}