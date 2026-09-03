data "aws_caller_identity" "current" {}

locals {
  # Account ID suffix keeps the bucket name globally unique without
  # hardcoding anything account-specific into the config itself.
  state_bucket_name = "${var.project_prefix}-tfstate-${data.aws_caller_identity.current.account_id}"
  lock_table_name    = "${var.project_prefix}-tf-locks"
}

resource "aws_s3_bucket" "tf_state" {
  bucket = local.state_bucket_name

  # Deliberate: state buckets should never be casually destroyable via
  # `terraform destroy` on this stack — that would take every other
  # stack's state down with it.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project = var.project_prefix
    Purpose = "terraform-remote-state"
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = local.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Project = var.project_prefix
    Purpose = "terraform-state-locking"
  }
}