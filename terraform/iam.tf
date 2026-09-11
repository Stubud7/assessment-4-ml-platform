# assessment4 iam.tf

# EC2 Role & Policy
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


# 2. SAGEMAKER EXECUTION ROLE & POLICIES

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

# Attach Managed SageMaker Policy (Gives S3 & ECR access needed by SageMaker)
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Attach Direct S3 Full Access to SageMaker Role
resource "aws_iam_role_policy_attachment" "sagemaker_s3_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Confirm that ec2 dynamodb iam role is required
resource "aws_iam_role_policy_attachment" "ec2_dynamodb" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# SageMaker S3 Access Policy Document
data "aws_iam_policy_document" "sagemaker_s3_policy" {
  statement {
    sid    = "AllowSageMakerS3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::stuart-assessment4-ml-artifacts",
      "arn:aws:s3:::stuart-assessment4-ml-artifacts/*"
    ]
  }
}

# Attach Policy to SageMaker Role
resource "aws_iam_role_policy" "sagemaker_s3_inline_policy" {
  name   = "sagemaker-s3-artifacts-policy"
  role   = aws_iam_role.sagemaker_execution_role.id  
  policy = data.aws_iam_policy_document.sagemaker_s3_policy.json
}