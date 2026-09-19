# assessment4- sagemeaker.tf for endpoints


# 

# ==============================================================================
# 2. LOCALS & TEAM DEFINITIONS
# ==============================================================================
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
      image_uri  = "382416733822.dkr.ecr.us-east-1.amazonaws.com/linear-learner:1"
      model_path = "s3://${aws_s3_bucket.model_artifacts.bucket}/forecasting/model.tar.gz"
    }
  }
}

 

# ==============================================================================
# 1. Update aws_sagemaker_model
resource "aws_sagemaker_model" "team_models" {
  for_each           = local.teams
  name               = "${each.value.team_name}-model"
  execution_role_arn = aws_iam_role.sagemaker_execution_role.arn

  primary_container {
    image          = each.value.image_uri
    model_data_url = each.value.model_path
  }


  tags = {
    Name = "stuart-assessment4-${each.key}-model"
    Team = each.value.team_name
  }

  # HARD DEPENDENCY: Ensure S3 objects and IAM policies exist BEFORE model creation
  depends_on = [
    aws_s3_object.model_artifacts,
    aws_iam_role_policy_attachment.sagemaker_s3_access,
    aws_iam_role_policy.sagemaker_s3_inline_policy
  ]
}


# 5. Create Endpoint Configurations for all 3 teams
resource "aws_sagemaker_endpoint_configuration" "team_configs" {
  for_each = local.teams
  name     = "${each.value.team_name}-config"

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

# 6. Provision 3 Live Real-Time SageMaker Endpoints / Update aws_sagemaker_endpoint
resource "aws_sagemaker_endpoint" "team_endpoints" {
  for_each             = local.teams
  name                 = "${each.value.team_name}-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.team_configs[each.key].name

  # FORCE TERRAFORM TO WAIT FOR MODEL & CONFIG CREATION
  depends_on = [
    aws_sagemaker_model.team_models,
    aws_sagemaker_endpoint_configuration.team_configs
  ]
}