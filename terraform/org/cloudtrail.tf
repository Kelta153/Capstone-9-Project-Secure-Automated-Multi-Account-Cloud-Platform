locals {
  trail_bucket_name = "${var.project_prefix}-org-trail-logs-${data.aws_caller_identity.current.account_id}"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "trail_logs" {
  bucket = local.trail_bucket_name

  tags = {
    Project = var.project_prefix
    Purpose = "org-cloudtrail-logs"
  }
}

resource "aws_s3_bucket_public_access_block" "trail_logs" {
  bucket                  = aws_s3_bucket.trail_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# NOTE: encryption is AES256 (SSE-S3) for now. In the encryption pillar
# we upgrade this to SSE-KMS using the capstone's customer-managed key,
# once that key exists — CloudTrail needs a specific key policy grant to
# write with a CMK, so it's sequenced there rather than here.
resource "aws_s3_bucket_server_side_encryption_configuration" "trail_logs" {
  bucket = aws_s3_bucket.trail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "trail_bucket_policy" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail_logs.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = [# Member-account log delivery path (org trail fan-out)
      "${aws_s3_bucket.trail_logs.arn}/AWSLogs/${data.aws_organizations_organization.this.id}/*",
      # Management account's own log delivery path (no org-id segment)
      "${aws_s3_bucket.trail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail_logs" {
  bucket = aws_s3_bucket.trail_logs.id
  policy = data.aws_iam_policy_document.trail_bucket_policy.json
}

resource "aws_cloudtrail" "org_trail" {
  name                          = "${var.project_prefix}-org-trail"
  s3_bucket_name                = aws_s3_bucket.trail_logs.id
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.trail_logs]

  tags = {
    Project = var.project_prefix
  }
}