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
  image_id = "ami-08a52ddb321b32a8c"

  # Instance type for the EC2 instance
  instance_type = "t2.micro"

  # SSH key pair name for connecting to the instance
  key_name = var.key_pair_name

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