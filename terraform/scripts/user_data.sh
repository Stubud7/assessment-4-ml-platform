#!/bin/bash
exec > /var/log/user_data.log 2>&1
set -ex

# Update repositories and install git and docker
dnf update -y
dnf install -y git docker

# Enable and start Docker service
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install Docker Compose CLI plugin for Amazon Linux 2023
DOCKER_CONFIG="/usr/local/lib/docker"
mkdir -p "$DOCKER_CONFIG/cli-plugins"
curl -SL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64 -o "$DOCKER_CONFIG/cli-plugins/docker-compose"
chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"

# Clone project repository and build stack
cd /home/ec2-user
git clone https://github.com/stubud7/assessment-4-ml-platform.git app
cd app

docker compose up -d --build
