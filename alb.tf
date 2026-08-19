resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.app_public_subnet_1.id, aws_subnet.app_public_subnet_2.id]

  enable_deletion_protection = false

  tags = {
    Name = "app-alb"
  }
}

resource "aws_lb_target_group" "app_lb_tg" {
  name     = "app-lb-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "app_alb_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_lb_tg.arn
  }
}


resource "aws_lb_target_group_attachment" "app_lb_tg_attachment" {
  target_group_arn = aws_lb_target_group.app_lb_tg.arn
  target_id        = aws_instance.app_server.id
  port             = 8080
}
