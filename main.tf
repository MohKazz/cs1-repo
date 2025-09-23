# provider "aws" { region = var.region }

# # --- VPC + IGW ---------------------------------------------------------------
# resource "aws_vpc" "this" {
#   cidr_block           = var.vpc_cidr
#   enable_dns_support   = true
#   enable_dns_hostnames = true
#   tags = merge(var.tags, { Name = "${var.name}-vpc" })
# }

# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.this.id
#   tags   = merge(var.tags, { Name = "${var.name}-igw" })
# }

# # --- Subnet helper locals ----------------------------------------------------
# # We carve the /16 into /20s -> plenty for dev and simple to read.
# locals {
#   public_subnet_cidrs = [
#     cidrsubnet(var.vpc_cidr, 4, 0), # 10.20.0.0/20
#     cidrsubnet(var.vpc_cidr, 4, 1), # 10.20.16.0/20
#   ]
#   app_subnet_cidrs = [
#     cidrsubnet(var.vpc_cidr, 4, 2), # 10.20.32.0/20
#     cidrsubnet(var.vpc_cidr, 4, 3), # 10.20.48.0/20
#   ]
#   db_subnet_cidrs = [
#     cidrsubnet(var.vpc_cidr, 4, 4), # 10.20.64.0/20
#     cidrsubnet(var.vpc_cidr, 4, 5), # 10.20.80.0/20
#   ]
# }

# # --- Public subnets (ALB) ----------------------------------------------------
# resource "aws_subnet" "public" {
#   for_each = {
#     a = { az = var.azs[0], cidr = local.public_subnet_cidrs[0] }
#     b = { az = var.azs[1], cidr = local.public_subnet_cidrs[1] }
#   }
#   vpc_id                  = aws_vpc.this.id
#   cidr_block              = each.value.cidr
#   availability_zone       = each.value.az
#   map_public_ip_on_launch = true
#   tags = merge(var.tags, { Name = "${var.name}-public-${each.key}", Tier = "public" })
# }

# # --- Private APP subnets (web/ECS) ------------------------------------------
# resource "aws_subnet" "app" {
#   for_each = {
#     a = { az = var.azs[0], cidr = local.app_subnet_cidrs[0] }
#     b = { az = var.azs[1], cidr = local.app_subnet_cidrs[1] }
#   }
#   vpc_id            = aws_vpc.this.id
#   cidr_block        = each.value.cidr
#   availability_zone = each.value.az
#   tags = merge(var.tags, { Name = "${var.name}-app-${each.key}", Tier = "app" })
# }

# # --- Private DB subnets (RDS) ------------------------------------------------
# resource "aws_subnet" "db" {
#   for_each = {
#     a = { az = var.azs[0], cidr = local.db_subnet_cidrs[0] }
#     b = { az = var.azs[1], cidr = local.db_subnet_cidrs[1] }
#   }
#   vpc_id            = aws_vpc.this.id
#   cidr_block        = each.value.cidr
#   availability_zone = each.value.az
#   tags = merge(var.tags, { Name = "${var.name}-db-${each.key}", Tier = "db" })
# }

# # --- One NAT for all private subnets (cheap dev) -----------------------------
# resource "aws_eip" "nat" {
#   domain = "vpc"
#   tags   = merge(var.tags, { Name = "${var.name}-nat-eip" })
# }

# resource "aws_nat_gateway" "nat" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = aws_subnet.public["a"].id
#   tags          = merge(var.tags, { Name = "${var.name}-nat" })
#   depends_on    = [aws_internet_gateway.igw]
# }

# # --- Route tables ------------------------------------------------------------
# # Public → IGW
# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.this.id
#   tags   = merge(var.tags, { Name = "${var.name}-rt-public" })
# }
# resource "aws_route" "public_inet" {
#   route_table_id         = aws_route_table.public.id
#   destination_cidr_block = "0.0.0.0/0"
#   gateway_id             = aws_internet_gateway.igw.id
# }
# resource "aws_route_table_association" "public_assoc" {
#   for_each       = aws_subnet.public
#   subnet_id      = each.value.id
#   route_table_id = aws_route_table.public.id
# }

# # Private (app + db) → NAT
# resource "aws_route_table" "private" {
#   vpc_id = aws_vpc.this.id
#   tags   = merge(var.tags, { Name = "${var.name}-rt-private" })
# }
# resource "aws_route" "private_nat" {
#   route_table_id         = aws_route_table.private.id
#   destination_cidr_block = "0.0.0.0/0"
#   nat_gateway_id         = aws_nat_gateway.nat.id
# }
# resource "aws_route_table_association" "app_assoc" {
#   for_each       = aws_subnet.app
#   subnet_id      = each.value.id
#   route_table_id = aws_route_table.private.id
# }
# resource "aws_route_table_association" "db_assoc" {
#   for_each       = aws_subnet.db
#   subnet_id      = each.value.id
#   route_table_id = aws_route_table.private.id
# }

# # --- Outputs we’ll use for later steps --------------------------------------
# output "vpc_id"                   { value = aws_vpc.this.id }
# output "public_subnet_ids"        { value = [for s in aws_subnet.public : s.id] }
# output "private_app_subnet_ids"   { value = [for s in aws_subnet.app   : s.id] }
# output "private_db_subnet_ids"    { value = [for s in aws_subnet.db    : s.id] }

# # -------------------- Security Groups --------------------
# # # ALB SG: allow HTTP from internet, egress anywhere
# resource "aws_security_group" "alb" {
#   name        = "${var.name}-alb-sg"
#   description = "ALB ingress 80 from internet"
#   vpc_id      = aws_vpc.this.id
#   tags        = merge(var.tags, { Name = "${var.name}-alb-sg" })
# }

# resource "aws_security_group_rule" "alb_in_http" {
#   type              = "ingress"
#   from_port         = 80
#   to_port           = 80
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.alb.id
# }

# resource "aws_security_group_rule" "alb_egress_all" {
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.alb.id
# }

# # Web SG: only allow HTTP from ALB SG
# resource "aws_security_group" "web" {
#   name        = "${var.name}-web-sg"
#   description = "Web instances allow HTTP from ALB"
#   vpc_id      = aws_vpc.this.id
#   tags        = merge(var.tags, { Name = "${var.name}-web-sg" })
# }

# resource "aws_security_group_rule" "web_in_http_world" {
#   type              = "ingress"
#   from_port         = 8080
#   to_port           = 8080
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.web.id
# }


# resource "aws_security_group_rule" "web_egress_all" {
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.web.id
# }

# # -------------------- Outputs --------------------
# # output "alb_dns_name" { value = aws_lb.web.dns_name }
# output "alb_sg_id"    { value = aws_security_group.alb.id }
# output "web_sg_id"    { value = aws_security_group.web.id }
# # output "web_tg_arn"   { value = aws_lb_target_group.web.arn }


# # -------------------- Launch Template --------------------
# resource "aws_iam_role" "ec2" {
#   name               = "${var.name}-ec2-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow"
#       Principal = { Service = "ec2.amazonaws.com" }
#       Action = "sts:AssumeRole"
#     }]
#   })
# }
# resource "aws_iam_role_policy_attachment" "ec2_ssm" {
#   role       = aws_iam_role.ec2.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# resource "aws_iam_instance_profile" "ec2" {
#   name = "${var.name}-ec2-profile"
#   role = aws_iam_role.ec2.name
# }

# data "aws_ami" "amazon_linux2" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }


# resource "aws_launch_template" "web" {
#   name_prefix   = "${var.name}-lt-"
#   image_id = data.aws_ami.amazon_linux2.id
#   instance_type = "t3.micro"
#   iam_instance_profile { name = aws_iam_instance_profile.ec2.name }
# #   vpc_security_group_ids = [aws_security_group.web.id]
#   network_interfaces {
#   associate_public_ip_address = true
#   security_groups              = [aws_security_group.web.id]
# }

# user_data = base64encode(<<EOF
# #!/bin/bash
# yum install -y nginx
# systemctl enable nginx
# systemctl start nginx
# echo "<h1>Hello from \$(hostname)</h1>" > /usr/share/nginx/html/index.html
# EOF
# )


#   tag_specifications {
#     resource_type = "instance"
#     tags = merge(var.tags, { Name = "${var.name}-web" })
#   }
# }

# # -------------------- Auto Scaling Group --------------------
# resource "aws_autoscaling_group" "web" {
#   name                      = "${var.name}-asg"
#   desired_capacity           = 2
#   min_size                   = 2
#   max_size                   = 4
#   vpc_zone_identifier = [for s in aws_subnet.public : s.id]
# #   target_group_arns          = [aws_lb_target_group.web.arn]
#   health_check_type           = "EC2"
#   health_check_grace_period   = 60
#   force_delete                = true

#   launch_template {
#     id      = aws_launch_template.web.id
#     version = "$Latest"
#   }

#   tag {
#     key                 = "Name"
#     value               = "${var.name}-web"
#     propagate_at_launch = true
#   }
# }

# # RDS SG: allow PostgreSQL only from web SG
# resource "aws_security_group" "rds" {
#   name   = "${var.name}-rds-sg"
#   vpc_id = aws_vpc.this.id
#   tags   = merge(var.tags, { Name = "${var.name}-rds-sg" })
# }
# resource "aws_security_group_rule" "rds_in_from_web" {
#   type                     = "ingress"
#   from_port                = 5432
#   to_port                  = 5432
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.web.id
#   security_group_id        = aws_security_group.rds.id
# }
# resource "aws_security_group_rule" "rds_out_all" {
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.rds.id
# }

# # DB subnet group (use the two private DB subnets you already have)
# resource "aws_db_subnet_group" "this" {
#   name       = "${var.name}-db-subnets"
#   subnet_ids = [for s in aws_subnet.db : s.id]
#   tags       = merge(var.tags, { Name = "${var.name}-db-subnets" })
# }

# # Smallest simple PostgreSQL
# resource "aws_db_instance" "postgres" {
#   identifier             = "${var.name}-pg"
#   engine                 = "postgres"          # let AWS pick default version
#   instance_class         = "db.t3.micro"
#   allocated_storage      = 20
#   username               = var.db_username
#   password               = var.db_password
#   db_subnet_group_name   = aws_db_subnet_group.this.name
#   vpc_security_group_ids = [aws_security_group.rds.id]
#   publicly_accessible    = false
#   multi_az               = false
#   skip_final_snapshot    = true
#   apply_immediately      = true
#   deletion_protection    = false
#   tags                   = merge(var.tags, { Name = "${var.name}-pg" })
# }

# output "rds_endpoint" { value = aws_db_instance.postgres.address }

# # Allow the EC2 instance to read CloudWatch metrics (for Grafana data source)
# resource "aws_iam_role_policy_attachment" "ec2_cw_read" {
#   role       = aws_iam_role.ec2.name
#   policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
# }

# # Allow access to Grafana UI (port 3000) from your IP or anywhere (simplest)
# resource "aws_security_group_rule" "web_in_grafana" {
#   type              = "ingress"
#   from_port         = 3000
#   to_port           = 3000
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]   # or your IP/CIDR
#   security_group_id = aws_security_group.web.id
# }

# resource "aws_autoscaling_policy" "web_cpu_target" {
#   name                   = "${var.name}-web-cpu-tt"
#   autoscaling_group_name = aws_autoscaling_group.web.name
#   policy_type            = "TargetTrackingScaling"
#   estimated_instance_warmup = 60

#   target_tracking_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ASGAverageCPUUtilization"
#     }
#     target_value = 50  # aim for ~50% avg CPU
#   }
# }

