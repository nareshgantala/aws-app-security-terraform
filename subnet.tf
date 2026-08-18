resource "aws_subnet" "app_public_subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.16.0.0/24"

  tags = {
    Name = "app_public_subnet_1"
  }
}

resource "aws_subnet" "app_public_subnet_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.16.1.0/24"

  tags = {
    Name = "app_public_subnet_2"
  }
}

resource "aws_subnet" "app_private_subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.16.2.0/24"

  tags = {
    Name = "app_private_subnet_1"
  }
}

resource "aws_subnet" "app_private_subnet_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.16.3.0/24"

  tags = {
    Name = "app_private_subnet_2"
  }
}
