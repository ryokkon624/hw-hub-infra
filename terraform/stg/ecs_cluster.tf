resource "aws_ecs_cluster" "this" {
  name = "hwhub-stg-ephem"

  tags = { Name = "hwhub-stg-ephem" }
}