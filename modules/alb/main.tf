resource "aws_lb_target_group" "tg" {
  
  name_prefix = "${var.env}-"
  target_type = "instance"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  deregistration_delay = 120
  health_check {
    
    protocol = "HTTP"
    path = "/"
    matcher = 200
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
  tags = {

    project = var.project
    env = "${var.env}"
  }
  lifecycle {

    create_before_destroy = true
  }
}

resource "aws_lb" "lb" {

  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.sg]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "${var.project}-alb"
  }
}

resource "aws_lb_listener" "httpslistener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.tls.arn

  default_action {

    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = "<h1>Website not found!</h1>"
      status_code  = "503"
    }
  }
  tags = {

    project = var.project
  }
}

resource "aws_lb_listener" "httplistener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener_rule" "rule" {
  
  listener_arn = aws_lb_listener.httpslistener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }

  condition {
    host_header {
      values = ["${var.env}.${var.domain}"]
    }
  }
}
