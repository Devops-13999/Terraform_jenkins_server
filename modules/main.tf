provider "aws" {
  region = local.region
}

#data source
#it retrives the list of available az's for the mentioned aws region 
data "aws_availability_zones" "available_zones" {
  state = "available"
}
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-*-amd64-server-*"]
  }
}

#local varialbles
#basename will extract name from current working directory
locals {
  name   = "zomato-${basename(path.cwd)}"
  region = "us-east-1"
  azs    = slice(data.aws_availability_zones.available_zones.names, 0, 3)
  type   = "t2.micro"
  os     = data.aws_ami.amazon_linux.id

}

#VPC resource
resource "aws_vpc" "VPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "${local.name}-vpc"
  }
}

#public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.VPC.id
  map_public_ip_on_launch = true
  availability_zone       = element(local.azs, 0)
  cidr_block              = "10.0.1.0/24"
  tags = {
    Name = "${local.name}-public_subnet"

  }

}

#Security Group
resource "aws_security_group" "sg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.VPC.id

  tags = {
    Name = "${local.name}-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4_first" {
  description       = "SSH"
  security_group_id = aws_security_group.sg.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = ["::/0"]
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4_second" {
  description       = "HTTP"
  security_group_id = aws_security_group.sg.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 8080
  ip_protocol = "tcp"
  to_port     = 8080
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4_ipv4" {
  security_group_id = aws_security_group.sg.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = ["::/0"]
  ip_protocol = "-1" # semantically equivalent to all ports
}

#Internet gateway
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.VPC.id
  tags = {
    Name = "${local.name}-ig"
  }
}

#Route Table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.VPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }

}

#Route association
resource "aws_route_table_association" "route_asso" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
}


#EC2 Instance
resource "aws_instance" "jenkins_server" {
  ami                    = local.os
  subnet_id              = aws_subnet.public_subnet.id
  instance_type          = local.type
  availability_zone      = element(local.azs, 0)
  vpc_security_group_ids = [aws_security_group.sg.id]
  user_data              = file("jenkins_setup_script.sh")

  tags = {
    Name = local.name
  }
}