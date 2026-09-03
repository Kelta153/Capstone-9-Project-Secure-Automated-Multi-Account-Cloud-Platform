# --- Upgrade existing buckets from AES256 to our CMK --------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "findings_log_cmk" {
  bucket = aws_s3_bucket.findings_log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.capstone_cmk.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_logs_cmk" {
  bucket = aws_s3_bucket.config_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.capstone_cmk.arn
    }
    bucket_key_enabled = true
  }
}

# The evaluator Lambda writes to findings_log — an IAM account principal,
# so (unlike Config) it's already covered by the key's root statement, but
# still needs its own IAM policy grant to actually call these KMS actions.
data "aws_iam_policy_document" "evaluator_lambda_kms" {
  statement {
    sid       = "UseCMKForFindingsLog"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt"]
    resources = [aws_kms_key.capstone_cmk.arn]
  }
}

resource "aws_iam_role_policy" "evaluator_lambda_kms" {
  name   = "${var.project_prefix}-evaluator-lambda-kms"
  role   = aws_iam_role.evaluator_lambda.id
  policy = data.aws_iam_policy_document.evaluator_lambda_kms.json
}

# --- Application secret, encrypted with the CMK --------------------------

resource "aws_secretsmanager_secret" "app_db_credentials" {
  name       = "${var.project_prefix}/app/db-credentials"
  kms_key_id = aws_kms_key.capstone_cmk.arn

  tags = {
    Project = var.project_prefix
  }
}

resource "aws_secretsmanager_secret_version" "app_db_credentials" {
  secret_id = aws_secretsmanager_secret.app_db_credentials.id
  secret_string = jsonencode({
    username = "appuser"
    password = "placeholder-demo-value-not-real"
  })
}

data "aws_iam_policy_document" "app_instance_secrets" {
  statement {
    sid       = "ReadDbCredentials"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.app_db_credentials.arn]
  }

  statement {
    sid       = "DecryptWithCMK"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.capstone_cmk.arn]
  }
}

resource "aws_iam_role_policy" "app_instance_secrets" {
  name   = "${var.project_prefix}-app-instance-secrets"
  role   = aws_iam_role.app_instance.id
  policy = data.aws_iam_policy_document.app_instance_secrets.json
}