packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.3"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "ami_prefix" {
  type    = string
  default = "packer-ubuntu"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "ubuntu" {
  access_key = "mmc"
  secret_key = "mmc"

  # source_ami      = "ami-0e2c8caa4b6378d8c"
  ami_name        = "${var.ami_prefix}-${local.timestamp}"
  ami_description = "AMI with Nginx and Node.js installed on Ubuntu"
  instance_type   = "t2.micro"
  region          = "us-east-1"

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
    "source.azure-arm.ubuntu",
  ]

  provisioner "shell" {
    inline = [
      "echo 'Updating system...'",
      "sudo apt update",
      "sudo apt upgrade -y",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Installing Nginx and Node.js...'",
      "sudo apt install -y nginx unzip curl",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
      "curl -fsSL https://fnm.vercel.app/install | bash",
      "source ~/.bashrc",
      "fnm use --install-if-missing 22",
      "node -v",
      "npm -v",
      "echo 'Installing PM2 process manager...'",
      "sudo npm install -g pm2@latest",
    ]
  }

  provisioner "file" {
    source      = "./hello.js"
    destination = "/home/ubuntu/hello.js"
  }

  provisioner "shell" {
    inline = [
      "echo 'Running Node.js app with PM2...'",
      "mkdir -p /home/ubuntu/app",
      "mv /home/ubuntu/hello.js /home/ubuntu/app/hello.js",
      "cd /home/ubuntu/app",
      "pm2 start hello.js",
      "pm2 startup systemd",
    ]
  }

  provisioner "file" {
    source      = "./nginx.conf"
    destination = "/etc/nginx/nginx.conf"
  }

  provisioner "shell" {
    inline = [
      "echo 'Configuring Nginx'",
      "sudo nginx -t",
      "sudo systemctl restart nginx",
    ]
  }
}
