resource "aws_instance" "app_server" {
  ami                    = "ami-0332d564d76dbd8d6"
  instance_type          = "t2.micro"
  user_data              = file("userdata.sh")
  subnet_id              = aws_subnet.app_private_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "aws-app-sec-ec2"
  }
}
