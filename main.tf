terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-1"
 
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.88.0.0/16"
  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.88.1.0/24"

  tags = {
    Name = "main_vpc_public"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.88.2.0/24"

  tags = {
    Name = "main_vpc_private"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt_main_vpc_public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "rt_main_vpc_public"
  }
}

resource "aws_route_table_association" "a" {
 subnet_id = aws_subnet.public.id
 route_table_id = aws_route_table.rt_main_vpc_public.id
}

resource "aws_eip" "lb" {
  vpc      = true
}

resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.lb.id
  subnet_id     = aws_subnet.public.id

  tags = {
    "name" = "gw_NAT"
  }
}

resource "aws_route_table" "rt_main_vpc_private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.gw.id
  }

  tags = {
    Name = "rt_main_vpc_private"
  }
}

resource "aws_route_table_association" "b" {
 subnet_id = aws_subnet.private.id
 route_table_id = aws_route_table.rt_main_vpc_private.id
}



data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "allow_web" {
  name = "allow_web_traffic"
  description = "Allow inbound web traffic"
  vpc_id = aws_vpc.main.id

  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }

  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }

  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "HTTP"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
  }

  egress  {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "All networks allowed"
    from_port = 0
    to_port = 0
    protocol = "-1"
  }

  tags = {
    "Name" = "main-sg"
  }

}


resource "aws_network_interface" "web" {
  subnet_id       = aws_subnet.private.id
  private_ips     = ["10.88.2.63"]
  security_groups = [aws_security_group.allow_web.id]
}

variable "key_name" {}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.example.public_key_openssh
}


resource "aws_instance" "SQL" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.generated_key.key_name
  user_data = <<-EOF
    #! /bin/bash
    sudo apt update -y 
    sudo apt install -y docker.io
    docker pull mysql
    docker run -itd -e MYSQL_ROOT_PASSWORD=wordpress -e MYSQL_DATABASE=wordpress -e MYSQL_USER=wordpress -e MYSQL_PASSWORD=wordpress -p 3306:3306 mysql
  EOF

  network_interface {
    network_interface_id = aws_network_interface.web.id
    device_index         = 0
  }

  tags = {
    Name = "firas-SQL"
  }
}


resource "aws_network_interface" "web1" {
  subnet_id       = aws_subnet.public.id
  private_ips     = ["10.88.1.202"]
  security_groups = [aws_security_group.allow_web.id]

}

resource "aws_eip" "two" {
  vpc                       = true
  network_interface         = aws_network_interface.web1.id
  associate_with_private_ip = "10.88.1.202"
}

resource "aws_instance" "WordPress" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.generated_key.key_name
  user_data = <<-EOF
    #! /bin/bash
    sleep 60
    sudo apt update -y
    sudo apt install -y docker.io
    docker pull wordpress
    docker run -itd -e WORDPRESS_DB_HOST=10.88.2.63  -e WORDPRESS_DB_USER=wordpress -e WORDPRESS_DB_PASSWORD=wordpress -e WORDPRESS_DB_NAME=wordpress -p 80:80 wordpress
  EOF

  network_interface {
    network_interface_id = aws_network_interface.web1.id
    device_index         = 0
  }

  tags = {
    Name = "firas-WordPress"
  }
}
