resource "aws_key_pair" "key" {
  
  key_name = "${var.project}"
          public_key = file("${var.key}.pub") 
  tags = {
    Name = "${var.project}"
  }
}

resource "aws_launch_template" "tmplt" {

  name_prefix   = "${var.env}-"
  #block_device_mappings {
  #device_name = "/dev/sda1"

  #ebs {
  #  volume_size = 1
  #
#delete_on_termination = true
  #}
  #}
  image_id      = data.aws_ami.ami.image_id
  instance_type = var.instance_type
  key_name = aws_key_pair.key.key_name
  
  #vpc_security_group_ids = [var.sg]
  network_interfaces {
    
    security_groups = [var.sg]
    associate_public_ip_address = true
    delete_on_termination = true
  }

  iam_instance_profile {
    arn = var.instance_role
  }

  monitoring {
    enabled = true
  }


  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project}-${var.env}"
    }
  }
  user_data = filebase64("user_data.sh")
  lifecycle {

    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "asg" {

  name = "${var.project}-ASG"
  availability_zones = var.az
  desired_capacity   = 2
  max_size           = 3
  min_size           = 1
  default_cooldown = 180
  health_check_grace_period = 120
  default_instance_warmup = 120
  health_check_type = "EC2"
  target_group_arns = [var.tg]
  termination_policies = ["Default"]

  launch_template {

    id      = aws_launch_template.tmplt.id
    version = "$Latest"
  }
depends_on = [
  aws_launch_template.tmplt
]

tag {

    key = "Name"
    value = "${var.project}-${var.env}-ASG"
    propagate_at_launch = true
}
}

resource "aws_autoscaling_notification" "notification" {
  group_names = [ aws_autoscaling_group.asg.name ]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]

  topic_arn = data.aws_sns_topic.sns.arn
}

resource "aws_autoscaling_policy" "scaleout_cpu" {
  name                   = "ScaleOut-CPU"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "CPUHigh-50"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "50"
  datapoints_to_alarm = "2"
  ok_actions = [data.aws_sns_topic.sns.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "CPU Utilization is above 50"
  alarm_actions     = [aws_autoscaling_policy.scaleout_cpu.arn, data.aws_sns_topic.sns.arn]
  tags = {
    "Name" = "CPUHigh-50"
  }
}

resource "aws_autoscaling_policy" "scalein_cpu" {
  name                   = "Scalein-CPU"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "CPULow-30"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  datapoints_to_alarm = "2"
  ok_actions = [data.aws_sns_topic.sns.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "CPU Utilization is lower than 30"
  alarm_actions     = [aws_autoscaling_policy.scalein_cpu.arn, data.aws_sns_topic.sns.arn]
  tags = {
    "Name" = "CPULow-30"
  }
}

resource "aws_autoscaling_policy" "scaleout_memory" {
  name                   = "ScaleOut-memory"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "MemoryHigh-50"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = var.cw_namespace
  period              = "120"
  statistic           = "Average"
  threshold           = "50"
  datapoints_to_alarm = "2"
  ok_actions = [data.aws_sns_topic.sns.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "Memory Utilization is above 50"
  alarm_actions     = [aws_autoscaling_policy.scaleout_memory.arn, data.aws_sns_topic.sns.arn]
  tags = {
    "Name" = "MemoryHigh-50"
  }
}

resource "aws_autoscaling_policy" "scalein_memory" {
  name                   = "ScaleIn-memory"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_cloudwatch_metric_alarm" "memory_low" {
  alarm_name          = "MemoryUtilLow-30"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = var.cw_namespace
  period              = "120"
  statistic           = "Average"
  threshold           = "50"
  datapoints_to_alarm = "2"
  ok_actions = [data.aws_sns_topic.sns.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "Memory Utilization is lower than 30"
  alarm_actions     = [aws_autoscaling_policy.scalein_memory.arn, data.aws_sns_topic.sns.arn]
  tags = {
    "Name" = "MemoryUtilLow-30"
  }
}