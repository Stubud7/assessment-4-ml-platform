# assessment4 ec2.terraform 

# Fetch latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_key_pair" "existing" { 
  key_name = "stuart2-key" 
  }
  





# Backend EC2 Server Instance
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnet.existing_public.id
  vpc_security_group_ids = [data.aws_security_group.existing_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name = data.aws_key_pair.existing.key_name

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user_data.log 2>&1
    set -x

    sudo dnf update -y
    sudo dnf install -y git docker docker-compose-plugin
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ec2-user

    cd /home/ec2-user
    git clone https://github.com/stubud7/assessment-4-ml-platform.git app
    cd app
    
    # Use sudo here so cloud-init has permission to interact with the Docker socket
    sudo docker compose up -d --build
EOF

  tags = {
    Name = "${var.stuart_assessment4}-backend-server"
  }
}
