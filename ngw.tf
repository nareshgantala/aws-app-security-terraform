resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "aws-app-security-terraform-nat"
  }
  depends_on = [aws_internet_gateway.gw]
}
