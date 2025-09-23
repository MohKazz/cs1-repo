# --- data to help build a unique bucket name ---
data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

locals {
  s3_bucket_name = lower(replace("${var.name}-test-${data.aws_caller_identity.this.account_id}-${data.aws_region.this.name}", "_", "-"))
}

# --- the bucket itself ---
resource "aws_s3_bucket" "test" {
  bucket        = local.s3_bucket_name
  force_destroy = true

  tags = merge(var.tags, {
    Name    = local.s3_bucket_name
    purpose = "test"
  })
}

# versioning on (good habit)
resource "aws_s3_bucket_versioning" "test" {
  bucket = aws_s3_bucket.test.id
  versioning_configuration { status = "Enabled" }
}

# default encryption (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "test" {
  bucket = aws_s3_bucket.test.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

# block all public access
resource "aws_s3_bucket_public_access_block" "test" {
  bucket                  = aws_s3_bucket.test.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


output "test_bucket_name" { value = aws_s3_bucket.test.bucket }
output "test_bucket_arn"  { value = aws_s3_bucket.test.arn }
