output "asg_op" {
  
  value = aws_autoscaling_group.asg
}

output "key_pair" {
  
  value = aws_key_pair.key
}

output "launch_template" {
  
  value = aws_launch_template.tmplt
}
