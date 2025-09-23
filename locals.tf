# Subnet helper locals
locals {
  public_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 4, 0),
    cidrsubnet(var.vpc_cidr, 4, 1),
  ]
  app_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 4, 2),
    cidrsubnet(var.vpc_cidr, 4, 3),
  ]
  db_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 4, 4),
    cidrsubnet(var.vpc_cidr, 4, 5),
  ]
}
