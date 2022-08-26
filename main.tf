resource "aws_vpc" "main" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Dev"
  }
}

resource "aws_subnet" "vpc_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"

  tags = {
    Name = "Dev-public"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Dev-gateway"
  }
}

resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Dev-rt"
  }
}

resource "aws_route" "default-route" {
  route_table_id         = aws_route_table.route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "rt-subnet" {
  subnet_id      = aws_subnet.vpc_subnet.id
  route_table_id = aws_route_table.route-table.id
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all_traffic"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow All Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "allow_all_traffic"
  }
}

resource "aws_key_pair" "devkeypair" {
  key_name   = "devkey"
  public_key = file("~/.ssh/devkey.pub")
}

resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.server.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.devkeypair.id
  vpc_security_group_ids = [aws_security_group.allow_all.id]
  subnet_id              = aws_subnet.vpc_subnet.id
  user_data              = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "Web Server"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname     = self.public_ip,
      user         = "ubuntu",
      identityfile = "~/.ssh/devkey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }


}