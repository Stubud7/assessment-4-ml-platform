# assessment4-variables.tf


variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "stuart_assessment4" {
  description = "Project name"
  type        = string
  default     = "stuart-assessment4"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "instance_type" {
  description = "EC2 instance size for the backend server"
  type        = string
  default     = "t3.micro" # Free-tier eligible / low cost
}

variable "vpc_id" {
  description = "The ID of the pre-existing VPC"
  type        = string
  default     = "vpc-08c01c4b0cf8d2da8"
}

variable "subnet_name_tag" {
  description = "Name tag filter for the target public subnet"
  type        = string
  default     = "stuart-assessment3-public-subnet" # Updated for Assessment 4
}

# --- S3 Buckets ---
variable "frontend_bucket_name" {
  description = "S3 bucket name for hosting static frontend assets"
  type        = string
  default     = "stuart-assessment4-frontend-s3"
}

variable "model_artifacts_bucket_name" {
  description = "S3 bucket name for ML model artifacts and data"
  type        = string
  default     = "stuart-assessment4-ml-artifacts"
}

# --- SageMaker Infrastructure ---
variable "sagemaker_instance_type" {
  description = "Instance type for SageMaker endpoint"
  type        = string
  default     = "ml.m5.large"
}

variable "sagemaker_model_name" {
  description = "Name identifier for the deployed SageMaker model"
  type        = string
  default     = "assessment4-ml-model"
}

# --- EKS / K8s & Security ---
variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
  default     = "k8s-training-cluster"
}


variable "project_name" {
  type    = string
  default = "ml-platform"
}


variable "teams" {
  description = "Map of team configurations for SageMaker endpoints"
  type = map(object({
    team_name = string
  }))
  default = {
    "fraud" = {
      team_name = "team-fraud-detection"
    }
    "recommendations" = {
      team_name = "team-recommendations"
    }
    "forecasting" = {
      team_name = "team-forecasting"
    }
  }
} 

variable "algorithm_image" {
  description = "Docker image URI for the SageMaker built-in algorithm container"
  type        = string
  # Default Scikit-Learn / XGBoost built-in algorithm container for us-east-1
  default     = "683313688378.dkr.ecr.us-east-1.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3"
}