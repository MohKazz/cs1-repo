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

  user_data = base64encode(<<EOF
#!/bin/bash
yum install -y nginx
systemctl enable nginx
systemctl start nginx
echo "<h1>Hello from \$(hostname)</h1>" > /usr/share/nginx/html/index.html
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-web" })
  }
}
