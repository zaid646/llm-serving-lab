# S3 bucket for model artifacts with versioning, encryption, and public access block.

resource "aws_s3_bucket" "model_artifacts" {
  # checkov:skip=CKV_AWS_144:Cross-region replication not required for dev model-artifact bucket
  # checkov:skip=CKV_AWS_18:Access logging not configured for dev bucket; no logging target bucket defined
  # checkov:skip=CKV2_AWS_61:Lifecycle rules not required for dev model-artifact bucket
  # checkov:skip=CKV2_AWS_62:Event notifications not required for dev model-artifact bucket
  # checkov:skip=CKV_AWS_145:SSE-AES256 used; KMS encryption not configured for dev simplicity
  bucket = var.bucket_name
  tags   = var.tags

  versioning {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = var.sse_algorithm
        kms_master_key_id = var.kms_key_id
      }
    }
  }
}

resource "aws_s3_bucket_versioning" "model_artifacts" {
  bucket = aws_s3_bucket.model_artifacts.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_public_access_block" "model_artifacts" {
  # checkov:skip=CKV2_AWS_6:Public access block explicitly configured for dev simplicity; bucket access controlled by IAM policy
  bucket = aws_s3_bucket.model_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
