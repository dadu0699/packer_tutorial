packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.3"
      source  = "github.com/hashicorp/amazon"
    }
    azure = {
      source  = "github.com/hashicorp/azure"
      version = ">= 2.2.0"
    }
  }
}

variable "ami_prefix" {
  type    = string
  default = "packer-linux-nginx-nodejs"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "ubuntu" {
  ami_name        = "${var.ami_prefix}-${local.timestamp}"
  ami_description = "AMI with Nginx and Node.js installed on Ubuntu"
  # source_ami      = "ami-0e2c8caa4b6378d8c"
  instance_type = "t2.micro"
  region        = "us-east-1"

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
}

build {
  name = "learn-packer"
  sources = [
    "source.amazon-ebs.ubuntu",
  ]

  provisioner "shell" {
    inline = [
      "echo updating and upgrading the system",
      "sleep 30",
      "sudo apt update",
      "sudo apt upgrade -y",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo Installing Nginx",
      "sleep 30",
      "sudo apt install nginx -y",
      "sudo nginx -version",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
      "sudo systemctl status nginx",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo Installing Node.js",
      "cd ~",
      "sudo apt update",
      "curl -fsSL https://fnm.vercel.app/install | bash",
      "source ~/.bashrc",
      "fnm use --install-if-missing 22",
      "node -v",
      "npm -v",
    ]
  }

  provisioner "file" {
    source      = "./hello.js"
    destination = "/home/ubuntu/hello.js"
  }

  provisioner "shell" {
    inline = [
      "echo Creating a simple Node.js app",
      "cd ~",
      "mkdir -p app",
      "mv /home/ubuntu/hello.js app/hello.js",
      "cd app",
      "node hello.js",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Serving the app with Nginx'",
      "sudo nano /etc/nginx/sites-available/app.example.com.conf",
    ]
  }

  post-processor "shell-local" {
    inline = [
      "echo 'AMI created successfully'",
    ]
  }
}