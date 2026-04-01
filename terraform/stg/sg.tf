#############################
# Security Groups (ephemeral)
#############################

resource "aws_security_group" "alb" {
  name        = "hwhub-alb-sg"
  description = "ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "hwhub-stg" }
}

resource "aws_security_group" "backend" {
  name        = "hwhub-stg-ephem-backend-sg"
  description = "Backend ECS SG for ephemeral stg"
  vpc_id      = var.vpc_id

  egress {
    description = "all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "hwhub-stg-ephem-backend-sg" }
}

#########################################
# SG Rule: existing ALB SG -> backend 8080
#########################################
resource "aws_security_group_rule" "backend_ingress_8080_from_existing_alb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.backend.id
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = local.existing_alb_sg_id
  description              = "From existing ALB SG to ephem backend 8080"
}

resource "aws_security_group" "batch" {
  name        = "hwhub-batch-sg-stg-ephem"
  description = "Batch ECS SG for ephemeral stg"
  vpc_id      = var.vpc_id

  tags = { Name = "hwhub-batch-sg-stg-ephem" }
}

resource "aws_security_group_rule" "batch_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.batch.id
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}
