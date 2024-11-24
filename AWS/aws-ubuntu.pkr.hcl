packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.3"
      source  = "github.com/hashicorp/amazon"
    }
    vagrant = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

variable "ami_prefix" {
  type    = string
  default = "learn-packer-linux-aws-redis"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "ubuntu" {
  ami_name        = "${var.ami_prefix}-${local.timestamp}"
  ami_description = "Learn Packer Linux AWS with Redis installed"
  instance_type   = "t2.micro"
  region          = "us-east-1"

  profile             = "localstack"
  access_key          = "mmc"
  secret_key          = "mmc"
  custom_endpoint_ec2 = "http://localhost:4566"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }

  ssh_username = "ubuntu"
}

source "amazon-ebs" "ubuntu-focal" {
  ami_name        = "${var.ami_prefix}-focal-${local.timestamp}"
  ami_description = "Learn Packer Linux AWS with Redis installed on Ubuntu Focal"
  instance_type   = "t2.micro"
  region          = "us-east-1"

  profile             = "localstack"
  access_key          = "mmc"
  secret_key          = "mmc"
  custom_endpoint_ec2 = "http://localhost:4566"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }

  ssh_username = "ubuntu"
}

build {
  name = "learn-packer"
  sources = [
    "source.amazon-ebs.ubuntu",
    "source.amazon-ebs.ubuntu-focal"
  ]

  provisioner "shell" {
    environment_vars = [
      "FOO=hello world",
    ]
    inline = [
      "echo Installing Redis",
      "sleep 30",
      "sudo apt update",
      "sudo apt install -y redis-server",
      "echo \"FOO is $FOO\" > example.txt",
    ]
  }

  provisioner "shell" {
    inline = ["echo This provisioner runs last"]
  }

  post-processor "vagrant" {}
}
