resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow TLS inbound traffic and all outbound traffic for EC2"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "ec2_sg"
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Allow TLS inbound traffic and all outbound traffic for ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "alb_sg"
  }
}


resource "aws_vpc_security_group_ingress_rule" "alb-ec2-ingress" {
  security_group_id = aws_security_group.ec2_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv6" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv6         = aws_vpc.main.ipv6_cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
