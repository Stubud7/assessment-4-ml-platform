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
  bucket     = aws_s3_bucket.frontend.id
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

# Upload per-team tarballs to S3
resource "aws_s3_object" "model_artifacts" {
  for_each = var.teams

  bucket = aws_s3_bucket.model_artifacts.id
  key    = "${each.key}/model.tar.gz"
  source = data.archive_file.model_tarball[each.key].output_path
  etag   = data.archive_file.model_tarball[each.key].output_md5
}

resource "aws_s3_bucket_public_access_block" "model_artifacts" {
  bucket = aws_s3_bucket.model_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. GENERATE DUMMY MODEL ARTIFACTS & ARCHIVES
resource "local_file" "dummy_xgboost" {
  filename = "${path.module}/dummy_models/fraud/xgboost-model"
  content  = "dummy xgboost binary model payload"
}

resource "local_file" "dummy_recommendations" {
  filename = "${path.module}/dummy_models/recommendations/model.algo"
  content  = "dummy factorization machine payload"
}

resource "local_file" "dummy_forecasting" {
  filename = "${path.module}/dummy_models/forecasting/model.algo"
  content  = "dummy linear learner payload"
}

data "archive_file" "model_tarball" {
  for_each    = var.teams
  type        = "tar.gz"
  output_path = "${path.module}/${each.key}_model.tar.gz"
  source_dir  = "${path.module}/dummy_models/${each.key}"

  depends_on = [
    local_file.dummy_xgboost,
    local_file.dummy_recommendations,
    local_file.dummy_forecasting
  ]
}