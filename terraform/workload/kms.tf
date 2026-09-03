data "aws_iam_policy_document" "cmk_policy" {
  # Standard "Enable IAM User Permissions" statement — without this, no
  # IAM policy in the account could grant access to the key at all, since
  # the key's own resource policy is the first gate.
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.workload.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # AWS Config is a service principal, not an account principal, so it
  # needs its own explicit grant to use this key for the Config delivery
  # bucket's SSE-KMS encryption — the root statement above doesn't cover it.
  statement {
    sid    = "AllowConfigServiceUseOfKey"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "capstone_cmk" {
  description             = "${var.project_prefix} customer-managed key for S3/logs/secrets encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.cmk_policy.json

  tags = {
    Project = var.project_prefix
  }
}

resource "aws_kms_alias" "capstone_cmk" {
  name          = "alias/${var.project_prefix}-cmk"
  target_key_id = aws_kms_key.capstone_cmk.key_id
}