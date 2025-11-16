packer {
  required_plugins {
    amazon = {
      version = ">= 1.7.1"
      source  = "github.com/hashicorp/amazon"
    }
    azure = {
      version = ">= 2.5.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

variable "image_prefix" {
  type    = string
  default = "packer-ubuntu"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "azure_subscription_id" {
  type = string
}

variable "azure_tenant_id" {
  type = string
}

variable "azure_resource_group" {
  type    = string
  default = "packer-rg"
}

variable "azure_location" {
  type    = string
  default = "centralus"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "ubuntu" {
  ami_name        = "${var.image_prefix}-${local.timestamp}"
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

source "azure-arm" "ubuntu" {
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id

  use_azure_cli_auth = true

  managed_image_resource_group_name = var.azure_resource_group
  managed_image_name                = "${var.image_prefix}-azure-${local.timestamp}"

  os_type  = "Linux"
  location = var.azure_location
  vm_size  = "Standard_B1s"

  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server"
  image_version   = "latest"

  azure_tags = {
    environment = "devops-course"
    role        = "node-nginx"
  }

  ssh_username = "ubuntu"
}

build {
  name = "ubuntu-nginx-nodejs"
  sources = [
    "source.amazon-ebs.ubuntu",
    "source.azure-arm.ubuntu",
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

  post-processor "manifest" {
    output = "packer-manifest.json"
  }
}
