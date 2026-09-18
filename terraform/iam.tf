# assessment4 iam.tf

# ==============================================================================
# 1. EC2 / EKS INSTANCE ROLE & POLICIES
# ==============================================================================

resource "aws_iam_role" "ec2_role" {
  name = "${var.stuart_assessment4}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

# Attach S3 Access to EC2
resource "aws_iam_role_policy_attachment" "ec2_s3_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Attach ECR Read/Pull Access to EC2
resource "aws_iam_role_policy_attachment" "ec2_ecr_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# EC2 Instance Profile (Attaches the IAM role to the EC2 server)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.stuart_assessment4}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Optional: Keep DynamoDB Access only if your microservice requires it
resource "aws_iam_role_policy_attachment" "ec2_dynamodb" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}


# ==============================================================================
# 2. SAGEMAKER EXECUTION ROLE & POLICIES
# ==============================================================================

resource "aws_iam_role" "sagemaker_execution_role" {
  name = "${var.stuart_assessment4}-sagemaker-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "sagemaker.amazonaws.com" }
      }
    ]
  })
}

# Managed Policy: Full SageMaker operations
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Managed Policy: S3 Access for fetching model tarballs
resource "aws_iam_role_policy_attachment" "sagemaker_s3_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Managed Policy: Container Registry Read Access for pulling algorithm images
resource "aws_iam_role_policy_attachment" "sagemaker_ecr_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Dynamic S3 Inline Policy for model artifacts bucket
data "aws_iam_policy_document" "sagemaker_s3_policy" {
  statement {
    sid    = "AllowSageMakerS3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.model_artifacts.arn,
      "${aws_s3_bucket.model_artifacts.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "sagemaker_s3_inline_policy" {
  name   = "sagemaker-s3-artifacts-policy"
  role   = aws_iam_role.sagemaker_execution_role.id
  policy = data.aws_iam_policy_document.sagemaker_s3_policy.json
}