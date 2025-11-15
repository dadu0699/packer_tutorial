packer {
  required_plugins {
    amazon = {
      version = ">= 1.7.1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ami_prefix" {
  type    = string
  default = "packer-exercise-1-ubuntu"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "ubuntu" {
  ami_name        = "${var.ami_prefix}-${local.timestamp}"
  ami_description = "AMI with Nginx and Node.js installed on Ubuntu"
  instance_type   = "t2.micro"
  region          = var.aws_region

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }

  ssh_username = "ubuntu"
  ssh_timeout  = "5m"
}

build {
  name = "ubuntu-nginx-nodejs"
  sources = [
    "source.amazon-ebs.ubuntu",
  ]

  provisioner "file" {
    source      = "hello.js"
    destination = "/tmp/hello.js"
  }

  provisioner "file" {
    source      = "node_nginx.conf"
    destination = "/tmp/node_nginx.conf"
  }

  provisioner "shell" {
    script = "scripts/provision.sh"
  }
}
