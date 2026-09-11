# assessment4- sagemeaker.tf for endpoints

# Local map defining the 3 team models and container images
locals {
  teams = {
    fraud = {
      team_name  = "fraud-detection"
      image_uri  = "683313688378.dkr.ecr.us-east-1.amazonaws.com/sagemaker-xgboost:1.5-1"
      model_path = "s3://${aws_s3_bucket.model_artifacts.bucket}/fraud/model.tar.gz"
    }
    recommendations = {
      team_name  = "recommendations"
      image_uri  = "382416733822.dkr.ecr.us-east-1.amazonaws.com/factorization-machines:1"
      model_path = "s3://${aws_s3_bucket.model_artifacts.bucket}/recommendations/model.tar.gz"
    }
    forecasting = {
      team_name  = "forecasting"
      # Standard SageMaker Linear Learner Image (us-east-1 example)
      image_uri  = "382416733822.dkr.ecr.us-east-1.amazonaws.com/linear-learner:1"
      model_path = "s3://${aws_s3_bucket.model_artifacts.bucket}/forecasting/model.tar.gz"
    }
 }
}

# 1. Create SageMaker Models for all 3 teams
resource "aws_sagemaker_model" "team_models" {
  for_each           = local.teams
  name               = "${var.stuart_assessment4}-${each.value.team_name}-model"
  execution_role_arn = aws_iam_role.sagemaker_execution_role.arn

  primary_container {
    image          = each.value.image_uri
    model_data_url = each.value.model_path
  }

  tags = {
    Name = "${var.stuart_assessment4}-${each.value.team_name}-model"
    Team = each.value.team_name
  }
}

# 2. Create Endpoint Configurations for all 3 teams
resource "aws_sagemaker_endpoint_configuration" "team_configs" {
  for_each = local.teams
  name     = "${var.stuart_assessment4}-${each.value.team_name}-config"

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.team_models[each.key].name
    initial_instance_count = 1
    instance_type          = "ml.m5.large"
  }

  tags = {
    Name = "${var.stuart_assessment4}-${each.value.team_name}-config"
    Team = each.value.team_name
  }
}

# 3. Provision 3 Live Real-Time SageMaker Endpoints
# resource "aws_sagemaker_endpoint" "team_endpoints" {
#   for_each             = local.teams
#   name                 = "${var.stuart_assessment4}-${each.value.team_name}-endpoint"
#   endpoint_config_name = aws_sagemaker_endpoint_configuration.team_configs[each.key].name

#   tags = {
#     Name = "${var.stuart_assessment4}-${each.value.team_name}-endpoint"
#     Team = each.value.team_name
#   }
# }