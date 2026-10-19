terraform {
  required_version = ">= 1.6"

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

# A single provider-level tagging baseline avoids per-resource omissions.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project         = var.project_name
      Environment     = var.environment
      ManagedBy       = "Terraform"
      ComplianceScope = "NIST-800-53"
    }
  }
}

# Unique names make this module reusable across accounts and deployments.
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  primary_name = "${var.project_name}-${var.environment}-data-${random_id.suffix.hex}"
  log_name     = "${var.project_name}-${var.environment}-logs-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "primary" {
  bucket        = local.primary_name
  force_destroy = var.allow_force_destroy
}

resource "aws_s3_bucket" "log" {
  bucket        = local.log_name
  force_destroy = var.allow_force_destroy
}

# Shared baseline: every bucket added to this map gets encryption and public-access protection.
# A bucket omitted from the map will NOT receive those for_each configurations.
locals {
  buckets = {
    primary = aws_s3_bucket.primary.id
    log     = aws_s3_bucket.log.id
  }
}

# SC-28: AES-256 default server-side encryption (SSE-S3) on both buckets.
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  for_each = local.buckets
  bucket   = each.value

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CM-6: Keep earlier object versions in the primary bucket.
resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

# AC-3: All four Block Public Access protections on both buckets.
resource "aws_s3_bucket_public_access_block" "public_access" {
  for_each = local.buckets
  bucket   = each.value

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# AU-3/AU-6: Source account is discovered, never hardcoded.
data "aws_caller_identity" "current" {}

# Least-privilege policy for the S3 log delivery service (no bucket ACL required).
data "aws_iam_policy_document" "logging" {
  statement {
    sid     = "AllowS3ServerAccessLogs"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.log.arn}/logs/*"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.primary.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "logging" {
  bucket = aws_s3_bucket.log.id
  policy = data.aws_iam_policy_document.logging.json
}

# BucketOwnerEnforced explicitly disables S3 ACLs on the log destination.
resource "aws_s3_bucket_ownership_controls" "logging" {
  bucket = aws_s3_bucket.log.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Logging must be configured only after permissions and ownership settings exist.
resource "aws_s3_bucket_logging" "primary" {
  bucket        = aws_s3_bucket.primary.id
  target_bucket = aws_s3_bucket.log.id
  target_prefix = "logs/"

  depends_on = [
    aws_s3_bucket_policy.logging,
    aws_s3_bucket_ownership_controls.logging
  ]
}
