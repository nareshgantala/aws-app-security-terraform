resource "aws_subnet" "app_public_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.16.0.0/24"

  tags = {
    Name = "app_public_subnet"
  }
}

resource "aws_subnet" "app_private_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.16.1.0/24"

  tags = {
    Name = "app_private_subnet"
  }
}
