resource "aws_network_acl" "custom_private_nacl" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "custom_private_nacl"
  }
}

# ==================== INBOUND RULES ====================

# Allow the ALB and Bastion to hit the App Port (8080)
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

# Allow the Bastion to SSH (Port 22) into the Private Subnet
resource "aws_network_acl_rule" "private_nacl_ingress_ssh" {
  network_acl_id = aws_network_acl.custom_private_nacl.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 22
  to_port        = 22
}

# CRITICAL FIX: Allow returning internet traffic (from SSM/HTTP/HTTPS) back to your EC2 instance 
resource "aws_network_acl_rule" "private_nacl_ingress_ephemeral" {
  network_acl_id = aws_network_acl.custom_private_nacl.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0" # Must be 0.0.0.0/0 to accept responses from public AWS endpoints
  from_port      = 1024
  to_port        = 65535
}


# ==================== OUTBOUND RULES ====================

# Allow outbound response traffic back to clients using ephemeral ports
resource "aws_network_acl_rule" "private_nacl_egress_rule" {
  network_acl_id = aws_network_acl.custom_private_nacl.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0" # Changed to 0.0.0.0/0 so responses can exit back to the load balancer/external resources securely
  from_port      = 1024
  to_port        = 65535
}

# Allow EC2 instances to communicate outbound to web ports (Necessary if downloading dependencies/updates)
resource "aws_network_acl_rule" "private_nacl_egress_http" {
  network_acl_id = aws_network_acl.custom_private_nacl.id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# Allow SSM Agent traffic outbound to AWS endpoints over secure web lines
resource "aws_network_acl_rule" "private_nacl_egress_https" {
  network_acl_id = aws_network_acl.custom_private_nacl.id
  rule_number    = 130
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_association" "private_nacl_association" {
  network_acl_id = aws_network_acl.custom_private_nacl.id
  subnet_id      = aws_subnet.app_private_subnet_1.id
}
