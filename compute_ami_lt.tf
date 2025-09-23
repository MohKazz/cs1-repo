# AMI lookup
data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Launch Template
resource "aws_launch_template" "web" {
  name_prefix   = "${var.name}-lt-"
  image_id      = data.aws_ami.amazon_linux2.id
  instance_type = "t3.micro"

  iam_instance_profile { name = aws_iam_instance_profile.ec2.name }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web.id]
  }

user_data = base64encode(<<-EOF
#!/bin/bash
set -euxo pipefail

# Detect OS family (AL2 vs AL2023) and install nginx properly
if grep -qi "Amazon Linux 2" /etc/system-release 2>/dev/null; then
  # Amazon Linux 2
  yum clean all -y
  amazon-linux-extras enable nginx1
  yum install -y nginx
elif grep -qi "Amazon Linux" /etc/os-release 2>/dev/null && command -v dnf >/dev/null 2>&1; then
  # Amazon Linux 2023
  dnf clean all -y || true
  dnf install -y nginx
else
  # Fallback for other RPM-based images
  yum install -y nginx || dnf install -y nginx || true
fi

# Minimal index page
mkdir -p /usr/share/nginx/html
echo "<h1>Hello from $(hostname -f)</h1>" > /usr/share/nginx/html/index.html

# Start & enable
systemctl enable nginx
systemctl restart nginx

# If firewalld is running, allow HTTP (rare on AL2/AL2023)
if systemctl is-active --quiet firewalld; then
  firewall-cmd --add-service=http --permanent || true
  firewall-cmd --reload || true
fi
EOF
)


  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-web" })
  }
}


#testing ci 