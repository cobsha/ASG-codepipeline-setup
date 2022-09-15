output "traget_group" {
  
  value = aws_lb_target_group.tg
}

output "alb" {
  
  value = aws_lb.lb
}

output "https_listener" {
  
  value = aws_lb_listener.httpslistener
}