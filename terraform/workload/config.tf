### --- Delivery bucket ------------------------------------------------

resource "aws_s3_bucket" "config_logs" {
  bucket = "${var.project_prefix}-config-logs-${data.aws_caller_identity.workload.account_id}"

  tags = {
    Project = var.project_prefix
    Purpose = "aws-config-delivery"
  }
}

resource "aws_s3_bucket_public_access_block" "config_logs" {
  bucket                  = aws_s3_bucket.config_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


data "aws_iam_policy_document" "config_bucket_policy" {
  statement {
    sid    = "AWSConfigBucketPermissionsCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.config_logs.arn]
  }

  statement {
    sid    = "AWSConfigBucketDelivery"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.config_logs.arn}/AWSLogs/${data.aws_caller_identity.workload.account_id}/Config/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "config_logs" {
  bucket = aws_s3_bucket.config_logs.id
  policy = data.aws_iam_policy_document.config_bucket_policy.json
}

### --- Recorder ---------------------------------------------------------

data "aws_iam_policy_document" "config_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config_recorder" {
  name               = "${var.project_prefix}-config-recorder"
  assume_role_policy = data.aws_iam_policy_document.config_assume.json

  tags = {
    Project = var.project_prefix
  }
}

resource "aws_iam_role_policy_attachment" "config_recorder_managed" {
  role       = aws_iam_role.config_recorder.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "this" {
  name     = "${var.project_prefix}-recorder"
  role_arn = aws_iam_role.config_recorder.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "${var.project_prefix}-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config_logs.bucket

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}

### --- Rule: S3 buckets must have encryption enabled --------------------

resource "aws_config_config_rule" "s3_encryption" {
  name = "${var.project_prefix}-s3-bucket-server-side-encryption-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.this]
}

### --- Auto-remediation: turn encryption on when the rule finds a gap ---

data "aws_iam_policy_document" "ssm_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config_remediation" {
  name               = "${var.project_prefix}-config-remediation"
  assume_role_policy = data.aws_iam_policy_document.ssm_assume.json

  tags = {
    Project = var.project_prefix
  }
}

data "aws_iam_policy_document" "config_remediation_permissions" {
  statement {
    sid    = "FixBucketEncryption"
    effect = "Allow"
    actions = [
      "s3:PutEncryptionConfiguration",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketLocation",
    ]
    resources = ["*"]
  }

   statement {
    sid       = "UseCMK"
    effect    = "Allow"
    actions   = ["kms:DescribeKey"]
    resources = [aws_kms_key.capstone_cmk.arn]
  }
}

resource "aws_iam_role_policy" "config_remediation_permissions" {
  name   = "${var.project_prefix}-config-remediation-permissions"
  role   = aws_iam_role.config_remediation.id
  policy = data.aws_iam_policy_document.config_remediation_permissions.json
}

resource "aws_config_remediation_configuration" "s3_encryption" {
  config_rule_name = aws_config_config_rule.s3_encryption.name

  resource_type  = "AWS::S3::Bucket"
  target_type    = "SSM_DOCUMENT"
  target_id      = "AWS-EnableS3BucketEncryption"
  target_version = "1"

  parameter {
    name         = "AutomationAssumeRole"
    static_value = aws_iam_role.config_remediation.arn
  }

  parameter {
    name           = "BucketName"
    resource_value = "RESOURCE_ID"
  }

  parameter {
    name         = "SSEAlgorithm"
    static_value = "AES256"
  }


  automatic                  = true
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}