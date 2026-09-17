terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  backend "s3" {
    bucket       = "stuart-assessment4-state-s3"
    key          = "assessment4/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Look up the existing EKS cluster
data "aws_eks_cluster" "existing" {
  name = var.cluster_name
}

# Look up authentication credentials for the existing EKS cluster
data "aws_eks_cluster_auth" "existing" {
  name = var.cluster_name
}
provider "kubernetes" {
  host                   = data.aws_eks_cluster.existing.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.existing.token
}


output "region" {
  value = var.aws_region
}

output "project_name" {
  value = var.project_name
}

# SageMaker Team Endpoints Summary
output "sagemaker_team_endpoints" {
  description = "Mapping of team names to their respective SageMaker endpoint names and ARNs"
  value = {
    for team_key, endpoint in aws_sagemaker_endpoint.team_endpoints : team_key => {
      team_name     = local.teams[team_key].team_name
      endpoint_name = endpoint.name
      endpoint_arn  = endpoint.arn
    }
  }
}

# EC2 Backend Instance Public IP (for calling the FastAPI services)
output "backend_public_ip" {
  description = "Public IP address of the EC2 backend server running FastAPI services"
  value       = aws_instance.backend.public_ip
}
