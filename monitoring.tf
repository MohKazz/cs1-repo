############################
# Variables (feel free to move to variables.tf later)
############################
variable "monitor_subnet_id" {
  type        = string
  description = "Private subnet ID to place the monitoring instance in"
  default     = "subnet-0c1bf12397e75f0c5" # your unused private subnet (AZ1)
}

############################
# Security group for monitoring host (egress only)
############################
resource "aws_security_group" "monitoring" {
  name        = "${var.name}-monitor-sg"
  description = "Monitoring host (Prom + Grafana) - private only"
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.name}-monitor-sg" })
}

# Egress all (needed for SSM + pulling images + EC2 API)
resource "aws_security_group_rule" "monitor_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.monitoring.id
}

############################
# Allow Prometheus to scrape node_exporter on web instances (9100)
############################
resource "aws_security_group_rule" "web_in_nodeexporter_from_monitor" {
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.monitoring.id
  security_group_id        = aws_security_group.web.id   # your existing web SG
}

############################
# IAM role/profile for monitoring instance
############################
resource "aws_iam_role" "monitor" {
  name = "${var.name}-monitor-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "monitor_ssm" {
  role       = aws_iam_role.monitor.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "monitor_ec2_read" {
  role       = aws_iam_role.monitor.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "monitor" {
  name = "${var.name}-monitor-profile"
  role = aws_iam_role.monitor.name
}

############################
# Monitoring instance (private)
############################
# Reuse your existing AL2 AMI data source
# data "aws_ami" "amazon_linux2" { ... }  <-- already in your repo

resource "aws_instance" "monitor" {
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = "t3.micro"
  subnet_id              = var.monitor_subnet_id
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  iam_instance_profile   = aws_iam_instance_profile.monitor.name
  associate_public_ip_address = false

  user_data = <<EOF
#!/bin/bash
set -euo pipefail

# 1) Docker
amazon-linux-extras enable docker || true
yum install -y docker
systemctl enable --now docker

# 2) Prometheus config (EC2 service discovery for Name=cs1nca-dev-web on 9100)
mkdir -p /opt/monitoring
cat >/opt/monitoring/prometheus.yml <<'PYAML'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    ec2_sd_configs:
      - region: eu-central-1
        port: 9100
        filters:
          - name: tag:Name
            values: ["cs1nca-dev-web"]
    relabel_configs:
      - source_labels: [__meta_ec2_private_ip]
        target_label: instance
PYAML

# 3) Run Prometheus (9090) + Grafana (3000)
# Prometheus
docker run -d --name prom --restart unless-stopped \
  -p 9090:9090 \
  -v /opt/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
  prom/prometheus:latest

# Grafana (admin / ChangeMe123!)
mkdir -p /opt/monitoring/grafana
docker run -d --name grafana --restart unless-stopped \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=ChangeMe123! \
  -v /opt/monitoring/grafana:/var/lib/grafana \
  grafana/grafana:latest

EOF

  tags = merge(var.tags, { Name = "${var.name}-monitor" })
}

############################
# Outputs
############################
output "monitor_instance_id" { value = aws_instance.monitor.id }
output "monitor_private_ip"  { value = aws_instance.monitor.private_ip }
output "monitor_sg_id"       { value = aws_security_group.monitoring.id }
