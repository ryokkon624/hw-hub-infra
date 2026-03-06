# 既存RDS SGの情報（参照用）
data "aws_security_group" "rds" {
  id = var.rds_security_group_id
}

# ephem backend → RDS(3306) を許可
resource "aws_security_group_rule" "rds_allow_mysql_from_ephem_backend" {
  type              = "ingress"
  security_group_id = data.aws_security_group.rds.id
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"

  source_security_group_id = aws_security_group.backend.id
  description              = "MySQL from ephem backend (ECS)"
}

# RDS SG へ MySQL 許可（RDS 側の SG に inbound 追加）
resource "aws_security_group_rule" "rds_allow_mysql_from_batch" {
  type                     = "ingress"
  security_group_id        = var.rds_security_group_id
  protocol                 = "tcp"
  from_port                = 3306
  to_port                  = 3306
  source_security_group_id = aws_security_group.batch.id
  description              = "MySQL from ephem batch (ECS)"
}