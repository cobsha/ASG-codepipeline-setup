output "traget_group" {
  
  value = aws_lb_target_group.tg
}

output "alb" {
  
  value = aws_lb.lb
}

output "https_listener" {
  
  value = aws_lb_listener.httpslistener
}

output "alb_sg" {
  
  value = aws_security_group.web_traffic
}