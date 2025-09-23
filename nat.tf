# One NAT for all private subnets (dev)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-eip" })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["a"].id
  tags          = merge(var.tags, { Name = "${var.name}-nat" })
  depends_on    = [aws_internet_gateway.igw]
}
