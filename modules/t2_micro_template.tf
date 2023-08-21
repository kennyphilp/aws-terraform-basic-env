variable "environment" {
  type = string
  validation {
    condition     = var.environment == "dev" || var.environment == "uat" || var.environment == "prod"
    error_message = "Must specify a valid environment from (dev/uat/prod)"
  }
}

variable "key_pair_name" {
  type = string
}



resource "aws_launch_template" "first-template" {
  # Name of the launch template
  name = "t2_micro_template"

  # ID of the Amazon Machine Image (AMI) to use for the instance
  ami = "ami-08a52ddb321b32a8c"

  # Instance type for the EC2 instance
  instance_type = "t2.micro"

  # SSH key pair name for connecting to the instance
  key_name = var.key_pair_name

  # Block device mappings for the instance
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      # Size of the EBS volume in GB
      volume_size = 20

      # Type of EBS volume (General Purpose SSD in this case)
      volume_type = "gp2"
    }
  }

  connection {
      user = "${var.EC2_USER}"
      private_key = "${file("${var.PRIVATE_KEY_PATH}")}"
  }

  # Tag specifications for the instance
  tag_specifications {
    # Specifies the resource type as "instance"
    resource_type = "instance"

    # Tags to apply to the instance
    tags = {
      Name = "Createdfirst template"
    }
  }
}