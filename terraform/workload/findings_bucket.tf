resource "aws_s3_bucket" "findings_log" {
  bucket = "${var.project_prefix}-findings-log-${data.aws_caller_identity.workload.account_id}"

  tags = {
    Project = var.project_prefix
    Purpose = "guardduty-finding-log"
  }
}

resource "aws_s3_bucket_public_access_block" "findings_log" {
  bucket                  = aws_s3_bucket.findings_log.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

