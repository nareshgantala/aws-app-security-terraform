resource "aws_instance" "example" {
  ami           = "ami-0332d564d76dbd8d6"
  instance_type = "t2.micro"
  user_data     = file("userdata.sh")
  subnet_id     = aws_subnet.app_private_subnet.id

  tags = {
    Name = "aws-app-sec-ec2"
  }
}
