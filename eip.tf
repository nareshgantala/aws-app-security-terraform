resource "aws_eip" "eip" {
  domain = "vpc"
  tags = {
    "Name" = "aws-app-security-terraform-eip"
  }
  depends_on = [aws_internet_gateway.gw]
}
