variable "vpc_id" { type = string }

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "private_route_table_ids" {
  type = list(string)
}

variable "rds_security_group_id" { type = string }

variable "alb_arn" { type = string }

variable "backend_target_group_arn" { type = string }

variable "certificate_arn" { type = string }

variable "backend_image" { type = string }

variable "backend_desired_count" {
  type    = number
  default = 1
}

variable "backend_cpu" {
  type    = number
  default = 512
}

variable "backend_memory" {
  type    = number
  default = 1024
}

variable "ecs_execution_role_arn" { type = string }
variable "ecs_task_role_arn" { type = string }

variable "batch_container_name" {
  type    = string
  default = "hwhub-batch"
}

variable "batch_scheduler_role_arn" {
  type        = string
  description = "Existing IAM role ARN used by EventBridge Scheduler (do not replace yet)"
}

variable "batch_image" { type = string }

variable "batch_task_role_arn" { type = string }
variable "batch_execution_role_arn" { type = string }

variable "batch_datasource_password_secret_arn" { type = string }
