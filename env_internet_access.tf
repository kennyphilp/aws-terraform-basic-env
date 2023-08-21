variable "awsprops" {
  type = map(any)
  default = {
    region       = "us-east-1"
    subnet       = "subnet-02653648ae120f8aa"
    vpc          = "vpc-dev"
    secgroupname = "IAC-Sec-Group"

    env  = "dev"

  }
}

locals {
  env = "dev"
}




provider "aws" {
  profile = "default"
  region  = lookup(var.awsprops, "region")
}


resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    enable_classiclink = false
    instance_tenancy = "default"
    tags = {
      Name     = "VPC - $(local.env}",
      Teardown = "True"
    }
}


resource "aws_subnet" "subnet-public-1" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = true
    availability_zone = "us-east-1a"
    tags = {
      Name     = "VPC Instance 1",
      Teardown = "True"
    }
}




resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.vpc.id}"
  
  tags = {
    Name = "main"
  }
}

resource "aws_security_group" "project-iac-sg" {
  name        = lookup(var.awsprops, "secgroupname")
  description = lookup(var.awsprops, "secgroupname")
  vpc_id = "${aws_vpc.vpc.id}"

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
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_instance" "example" {
  ami           = "ami-2757f631"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  subnet_id     = "${aws_subnet.subnet-public-1.id}"
  user_data     = <<EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd.x86_64
    systemctl start httpd.service
    systemctl enable httpd.service
    echo “Hello World from $(hostname -f)” > /var/www/html/index.html
  EOF

  tags = {
    Name     = "EC2 Instance 1",
    Teardown = "True"
  }

  depends_on = [aws_security_group.project-iac-sg, aws_internet_gateway.gw]

}