# Public subnets
resource "aws_subnet" "public" {
  for_each = {
    a = { az = var.azs[0], cidr = local.public_subnet_cidrs[0] }
    b = { az = var.azs[1], cidr = local.public_subnet_cidrs[1] }
  }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.name}-public-${each.key}", Tier = "public" })
}

# Private APP subnets
resource "aws_subnet" "app" {
  for_each = {
    a = { az = var.azs[0], cidr = local.app_subnet_cidrs[0] }
    b = { az = var.azs[1], cidr = local.app_subnet_cidrs[1] }
  }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = merge(var.tags, { Name = "${var.name}-app-${each.key}", Tier = "app" })
}

# Private DB subnets
resource "aws_subnet" "db" {
  for_each = {
    a = { az = var.azs[0], cidr = local.db_subnet_cidrs[0] }
    b = { az = var.azs[1], cidr = local.db_subnet_cidrs[1] }
  }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = merge(var.tags, { Name = "${var.name}-db-${each.key}", Tier = "db" })
}
