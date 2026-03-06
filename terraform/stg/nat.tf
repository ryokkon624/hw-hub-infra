resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "hwhub-stg-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.public_subnet_ids[0] # TODO: 本当は両方

  tags = {
    Name = "hwhub-stg-nat"
  }
}