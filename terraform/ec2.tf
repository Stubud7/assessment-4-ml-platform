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
  key_name               = data.aws_key_pair.existing.key_name

  user_data                   = file("${path.module}/scripts/user_data.sh")
  user_data_replace_on_change = true

  tags = {
    Name = "stuart-assessment4-backend-server"
  }
}
