
variable "environment" {
  type = string
  validation {
    condition     = var.environment == "dev" || var.environment == "uat" || var.environment == "prod"
    error_message = "Must specify a valid environment from (dev/uat/prod)"
  }
}

provider "aws" {
  profile = "default"
  region  = lookup(var.awsprops, "region")
}


variable "awsprops" {
  type = map(any)
  default = {
    region              = "us-east-1"
    publicsecgroupname  = "IAC-Public-Sec-Group"
    privatesecgroupname = "IAC-Private-Sec-Group"
    key_pair_name       = "KeyPairNorthVirginia"
  }
}

module "assets" {
  source        = "./modules"
  environment   = var.environment
  key_pair_name = var.awsprops.key_pair_name
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = {
    Name     = "vpc_${var.environment}",
    Teardown = "True"
  }
}


resource "aws_subnet" "subnet-public-1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name     = "Public_Subnet_1_${var.environment}",
    Teardown = "True"
  }
}


resource "aws_subnet" "subnet-private-1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name     = "Private_Subnet_1_${var.environment}",
    Teardown = "True"
  }
}

resource "aws_route_table" "public-crt" {
  vpc_id = aws_vpc.vpc.id

  route {
    //associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"

    //CRT uses this IGW to reach internet
    gateway_id = aws_internet_gateway.igw.id
  }

}


resource "aws_route_table_association" "crta-subnet-public-1" {
  subnet_id      = aws_subnet.subnet-public-1.id
  route_table_id = aws_route_table.public-crt.id
}



resource "aws_route_table" "private-crt" {
  vpc_id = aws_vpc.vpc.id

  route {
    //associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"

    //CRT uses this IGW to reach internet
    gateway_id = aws_nat_gateway.natgtw.id
  }

}

resource "aws_route_table_association" "crta-subnet-private-1" {
  subnet_id      = aws_subnet.subnet-private-1.id
  route_table_id = aws_route_table.private-crt.id
}






resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "Internet_Gateway_${var.environment}"
  }
}


resource "aws_eip" "multi-ip" {

}


resource "aws_nat_gateway" "natgtw" {
  allocation_id = aws_eip.multi-ip.id
  subnet_id     = aws_subnet.subnet-public-1.id

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_security_group" "sg-ssh-allowed-public" {
  name        = lookup(var.awsprops, "publicsecgroupname")
  description = lookup(var.awsprops, "publicsecgroupname")
  vpc_id      = aws_vpc.vpc.id

  // To Allow SSH Transport
  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  // To Allow Port 80 Transport
  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "sg-ssh-allowed-private" {
  name        = lookup(var.awsprops, "privatesecgroupname")
  description = lookup(var.awsprops, "privatesecgroupname")
  vpc_id      = aws_vpc.vpc.id

  // To Allow SSH Transport
  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["10.0.0.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["10.0.0.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }


  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "web_server_instance" {

  count = 1

  launch_template {
    name = "t2_micro_template"
  }

  associate_public_ip_address = true
  subnet_id                   = aws_subnet.subnet-public-1.id

  vpc_security_group_ids = ["${aws_security_group.sg-ssh-allowed-public.id}"]

  user_data = filebase64("${path.module}/scripts/user_data_httpd_install.sh")

  tags = {
    Name     = "EC2_Public_Instance_${count.index}_${var.environment}",
    Teardown = "True"
  }

  depends_on = [aws_security_group.sg-ssh-allowed-public, aws_internet_gateway.igw]

}


resource "aws_instance" "private_server_instance" {

  count = 1

  launch_template {
    name = "t2_micro_template"
  }

  associate_public_ip_address = false
  subnet_id                   = aws_subnet.subnet-private-1.id

  vpc_security_group_ids = ["${aws_security_group.sg-ssh-allowed-private.id}"]


  tags = {
    Name     = "EC2_Private_Instance_${count.index}_${var.environment}",
    Teardown = "True"
  }

  depends_on = [aws_security_group.sg-ssh-allowed-private]

}