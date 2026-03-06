resource "aws_route" "private_to_nat" {
  for_each               = toset(var.private_route_table_ids)
  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}