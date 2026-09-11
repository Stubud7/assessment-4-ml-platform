# assessment4 vpc.terraform 


data "aws_vpc" "existing" {
  id = var.vpc_id
}


data "aws_subnet" "existing_public" {
  vpc_id = data.aws_vpc.existing.id

  # Filter by tag or availability zone
  filter {
    name   = "tag:Name"
    values = [var.subnet_name_tag]
  }
}

# 3. Fetch existing Security Group inside existing VPC
data "aws_security_group" "existing_sg" {
  vpc_id = data.aws_vpc.existing.id

  filter {
    name   = "group-name"
    values = ["stuart-assessment3-backend-sg"]
  }
}
  