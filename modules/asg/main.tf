resource "aws_iam_role" "instance_role" {
  
  assume_role_policy    = jsonencode(
        {
            Statement = [
                {
                    Action    = "sts:AssumeRole"
                    Effect    = "Allow"
                    Principal = {
                        Service = "ec2.amazonaws.com"
                    }
                },
            ]
            Version   = "2012-10-17"
        }
    )

  description           = "Allows EC2 instances to call AWS services on our behalf."
  force_detach_policies = false
  managed_policy_arns   = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentAdminPolicy",
  ]
  max_session_duration  = 3600
  name                  = "${var.project}-instance-role"
  path                  = "/"
  tags                  = {
    "Name" = "${var.project}-instance-role"
  }

}

resource "aws_iam_instance_profile" "instance_role_profile" {

    name        = "${var.project}-instance-role"
    path        = "/"
    role        = aws_iam_role.instance_role.name
    depends_on = [
      aws_iam_role.instance_role
    ]
    tags        = {
    
      Name = "${var.project}-instance-profile"
    }
}


resource "aws_security_group"  "template_sg" {
    
  name_prefix = "${var.project}-"
  description = "Allow http,https,ssh inbound traffic"
    
  ingress {

    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }
    
    
  ingress {

    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups  = [ var.alb_sg ]
  }

    
  ingress {
      
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    security_groups  = [ var.alb_sg ]
  }
    
    
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "template-instance-${var.project}-${var.env}",
    project = var.project,
    env = var.project
  }
}


resource "aws_key_pair" "key" {
  
  key_name = "${var.project}"
          public_key = file("${var.key}.pub") 
  tags = {
    Name = "${var.project}"
  }
}

resource "aws_launch_template" "tmplt" {

  name_prefix   = "${var.env}-"
  image_id      = data.aws_ami.ami.id
  instance_type = var.instance_type
  key_name = aws_key_pair.key.key_name
  
  network_interfaces {
    
    security_groups = [aws_security_group.template_sg.id]
    associate_public_ip_address = true
    delete_on_termination = true
  }

  iam_instance_profile {

    arn = aws_iam_instance_profile.instance_role_profile.arn
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
  depends_on = [
    aws_key_pair.key,
    aws_iam_instance_profile.instance_role_profile
  ]

}

resource "aws_autoscaling_group" "asg" {

  name = "${var.project}-ASG"
  availability_zones = var.az
  desired_capacity   = 2
  max_size           = 4
  min_size           = 2
  default_cooldown = 300
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
#  cooldown               = 300
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
#  cooldown               = 120
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
#  cooldown               = 120
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
 # cooldown               = 120
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

