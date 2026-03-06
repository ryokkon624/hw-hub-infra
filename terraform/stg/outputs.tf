output "nat_gateway_id" {
  value = aws_nat_gateway.this.id
}

output "nat_eip_public_ip" {
  value = aws_eip.nat.public_ip
}

output "alb_dns_name" {
  value = data.aws_lb.api.dns_name
}

output "alb_arn" {
  value = data.aws_lb.api.arn
}

output "backend_service_name" {
  value = aws_ecs_service.backend.name
}