resource "aws_autoscaling_group" "web" {
  name                      = "${var.name}-asg"
  desired_capacity          = 0
  min_size                  = 0
  max_size                  = 4
  vpc_zone_identifier       = [for s in aws_subnet.public : s.id]
  health_check_type         = "EC2"
  health_check_grace_period = 60
  force_delete              = true

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-web"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "web_cpu_target" {
  name                      = "${var.name}-web-cpu-tt"
  autoscaling_group_name    = aws_autoscaling_group.web.name
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = 60

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}
