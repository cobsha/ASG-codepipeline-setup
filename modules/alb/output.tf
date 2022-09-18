output "traget_group" {
  
  value = aws_lb_target_group.tg
}

output "alb" {
  
  value = aws_lb.lb
}

output "alb_sg" {
  
  value = aws_security_group.web_traffic
}