# assessment4 s3.terraform 

# 1. FRONTEND STATIC WEBSITE BUCKET
resource "aws_s3_bucket" "frontend" {
  bucket        = var.frontend_bucket_name
  force_destroy = true

  tags = {
    Name = var.frontend_bucket_name
  }
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_public_access" {
  bucket = aws_s3_bucket.frontend.id
  # Force Terraform to wait until the S3 bucket is fully created in AWS
  depends_on = [aws_s3_bucket.frontend]

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_public_read" {
  bucket     = aws_s3_bucket.frontend.id
  depends_on = [aws_s3_bucket_public_access_block.frontend_public_access]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
}

# 2. SAGEMAKER / ML MODEL ARTIFACTS BUCKET
resource "aws_s3_bucket" "model_artifacts" {
  bucket        = var.model_artifacts_bucket_name
  force_destroy = true

  tags = {
    Name = var.model_artifacts_bucket_name
  }
}

# Keep ML artifacts private
resource "aws_s3_bucket_public_access_block" "model_artifacts" {
  bucket = aws_s3_bucket.model_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 1. Create dummy model file for container ping health checks
resource "local_file" "dummy_model" {
  filename = "${path.module}/dummy_model/model_algo-1"
  content  = "{\"status\": \"healthy\"}"
}

# 2. Compress dummy file into model.tar.gz
data "archive_file" "model_tarball" {
  type        = "tar.gz"
  source_file = local_file.dummy_model.filename
  output_path = "${path.module}/model.tar.gz"
}

# 3. Upload model.tar.gz to each team prefix in S3 automatically
resource "aws_s3_object" "model_artifacts" {
  for_each = toset(["fraud", "recommendations", "forecasting"])

  bucket = aws_s3_bucket.model_artifacts.id
  key    = "${each.value}/model.tar.gz"
  source = data.archive_file.model_tarball.output_path
  etag   = data.archive_file.model_tarball.output_md5
}