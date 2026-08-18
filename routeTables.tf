resource "aws_route_table" "public_subnet_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public_subnet_rt"
  }
}

resource "aws_route_table" "private_subnet_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private_subnet_rt"
  }
}

resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.app_public_subnet.id
  route_table_id = aws_route_table.public_subnet_rt.id
}

resource "aws_route_table_association" "private_rt_association" {
  subnet_id      = aws_subnet.app_private_subnet.id
  route_table_id = aws_route_table.private_subnet_rt.id
}

