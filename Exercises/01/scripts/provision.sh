#!/bin/bash
#
# === Packer Provisioning Script: Node.js + Nginx ===
#
# This script is intended for use with Packer on an Ubuntu 24.04 LTS base image.
# It provisions a server by:
#   1. Installing Nginx as a reverse proxy.
#   2. Installing fnm (Fast Node Manager) for Node.js version management.
#   3. Installing Node.js v24.
#   4. Configuring a systemd service to run the Node.js application.
#
# Assumed files (to be uploaded by Packer to /tmp):
#   - /tmp/hello.js
#   - /tmp/node_nginx.conf
#

# --- Script Configuration ---

# Exit immediately if any command fails (returns a non-zero status).
set -e

# --- System Preparation ---

echo "[Provisioner] Updating package lists and upgrading system..."
sudo apt update -y
sudo apt upgrade -y

echo "[Provisioner] Installing base dependencies..."
# - curl, unzip, ca-certificates: Standard tools for downloading/managing files.
# - build-essential: Required by fnm to compile Node.js from source if needed.
sudo apt install -y curl unzip ca-certificates build-essential

# --- Node.js Installation (via fnm) ---

echo "[Provisioner] Installing Node.js v24 via fnm..."

# Run the fnm installer script.
curl -o- https://fnm.vercel.app/install | bash

# The installer only modifies .bashrc, which isn't sourced in this script.
# We must manually export fnm's variables into the current session's
# environment to make the 'fnm' command available.
export FNM_DIR="$HOME/.local/share/fnm"
export PATH="$FNM_DIR:$PATH"

# Similarly, we must explicitly tell 'fnm env' to use 'bash' syntax.
eval "$(fnm env --shell bash)"

# Now the 'fnm' command is available in this session.
fnm install 24
fnm default 24 # Set v24 as the default for future interactive login sessions
fnm use 24     # Use v24 for the remainder of this script's session

# Verify installation and print versions
echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"

# --- Nginx Installation ---

echo "[Provisioner] Installing Nginx..."
sudo apt install -y nginx

# --- Application Setup ---

echo "[Provisioner] Copying Node.js application..."
sudo mkdir -p /var/www/nodeapp
sudo cp /tmp/hello.js /var/www/nodeapp/hello.js

# Set ownership to the 'ubuntu' user. The systemd service will run as this
# user and needs access to the fnm-installed Node.js binaries.
sudo chown -R ubuntu:ubuntu /var/www/nodeapp

# --- Systemd Service Setup ---

echo "[Provisioner] Creating systemd service for the Node.js app..."

# Find the absolute path to the fnm-installed Node.js executable.
# This is required for the systemd service file, as the 'root' user
# running systemd does not have the 'ubuntu' user's fnm shims in its PATH.
NODE_PATH=$(which node)
if [ -z "$NODE_PATH" ]; then
    echo "FATAL: Could not find 'node' executable in PATH. Exiting."
    exit 1
fi
echo "[Provisioner] Node.js executable found at: $NODE_PATH"

# Create the systemd service file using a "here document" (cat <<EOF).
cat <<EOF | sudo tee /etc/systemd/system/nodeapp.service
[Unit]
Description=Node.js Application (hello.js)
After=network.target

[Service]
# Use the absolute path to the Node.js executable
ExecStart=$NODE_PATH /var/www/nodeapp/hello.js
Restart=always

# Run the service as the 'ubuntu' user, who owns the fnm installation
User=ubuntu
Group=ubuntu

# Set environment variables for the application
Environment=PORT=3000

# Best practice: Set the working directory
WorkingDirectory=/var/www/nodeapp

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable the service to start on boot, and start it now
echo "[Provisioner] Enabling and starting nodeapp service..."
sudo systemctl daemon-reload
sudo systemctl enable nodeapp.service
sudo systemctl start nodeapp.service

# --- Nginx Reverse Proxy Setup ---

echo "[Provisioner] Configuring Nginx as a reverse proxy..."

# Copy the Nginx config file (provided by Packer)
sudo cp /tmp/node_nginx.conf /etc/nginx/sites-available/node.conf

# Enable the new site by creating a symbolic link
sudo ln -sf /etc/nginx/sites-available/node.conf /etc/nginx/sites-enabled/node.conf

# Disable the default Nginx welcome page
sudo rm -f /etc/nginx/sites-enabled/default

# Test the Nginx configuration for syntax errors
echo "[Provisioner] Testing Nginx configuration..."
sudo nginx -t

# Restart Nginx to apply all changes
sudo systemctl restart nginx

echo "[Provisioner] Provisioning completed successfully! 🚀"