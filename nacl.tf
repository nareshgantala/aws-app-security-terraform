resource "aws_network_acl" "custom_private_nacl" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "custom_private_nacl"
  }
}

resource "aws_network_acl_rule" "private_nacl_ingress_rule" {
  network_acl_id = aws_network_acl.custom_private_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 8080
  to_port        = 8080
}

resource "aws_network_acl_rule" "private_nacl_egress_rule" {
  network_acl_id = aws_network_acl.custom_private_nacl.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_association" "private_nacl_association" {
  network_acl_id = aws_network_acl.custom_private_nacl.id
  subnet_id      = aws_subnet.app_private_subnet_1.id
}
