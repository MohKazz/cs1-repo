# ALB SG (HTTP from internet)
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB ingress 80 from internet"
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.name}-alb-sg" })
}

resource "aws_security_group_rule" "alb_in_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# Web SG
resource "aws_security_group" "web" {
  name        = "${var.name}-web-sg"
  description = "Web instances allow HTTP from ALB"
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.name}-web-sg" })
}

resource "aws_security_group_rule" "web_in_http_world" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
}

resource "aws_security_group_rule" "web_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
}

# RDS SG: allow from web SG
resource "aws_security_group" "rds" {
  name   = "${var.name}-rds-sg"
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-rds-sg" })
}

resource "aws_security_group_rule" "rds_in_from_web" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id
  security_group_id        = aws_security_group.rds.id
}

resource "aws_security_group_rule" "rds_out_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
}

# Grafana (3000) open (or scope to your IP)
resource "aws_security_group_rule" "web_in_grafana" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # tighten to your IP if needed
  security_group_id = aws_security_group.web.id
}
