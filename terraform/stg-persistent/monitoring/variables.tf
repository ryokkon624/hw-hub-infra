variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "rds_instance_identifier" {
  type        = string
  description = "RDS DB instance identifier to auto-stop"
}

variable "auto_stop_delay_minutes" {
  type        = number
  default     = 30
  description = "Minutes to wait after RDS start before stopping"
}
