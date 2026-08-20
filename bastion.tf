resource "aws_instance" "bastion" {
  ami           = "ami-0332d564d76dbd8d6"
  instance_type = "t3.micro"

}

resource "aws_security_group" "bastion_sg" {
  name        = "launch-wizard-10"
  description = "launch-wizard-10 created 2026-08-20T01:12:55.001Z" # MUST match exactly to stop replacement
  vpc_id      = aws_vpc.main.id

  # Maintain the existing rules so Terraform doesn't strip them
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
