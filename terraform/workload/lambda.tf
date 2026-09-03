data "archive_file" "evaluator_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/evaluator"
  output_path = "${path.module}/../../lambda/evaluator.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "evaluator_lambda" {
  name               = "${var.project_prefix}-evaluator-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = {
    Project = var.project_prefix
  }
}

data "aws_iam_policy_document" "evaluator_lambda_permissions" {
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.workload.account_id}:*"]
  }

  statement {
    sid       = "WriteFindings"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.findings_log.arn}/*"]
  }

  statement {
    sid       = "IsolateInstances"
    effect    = "Allow"
    actions   = ["ec2:CreateTags", "ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "evaluator_lambda_permissions" {
  name   = "${var.project_prefix}-evaluator-lambda-permissions"
  role   = aws_iam_role.evaluator_lambda.id
  policy = data.aws_iam_policy_document.evaluator_lambda_permissions.json
}

resource "aws_lambda_function" "evaluator" {
  function_name    = "${var.project_prefix}-finding-evaluator"
  role             = aws_iam_role.evaluator_lambda.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.evaluator_zip.output_path
  source_code_hash = data.archive_file.evaluator_zip.output_base64sha256

  environment {
    variables = {
      FINDINGS_BUCKET    = aws_s3_bucket.findings_log.bucket
      SEVERITY_THRESHOLD = "7"
    }
  }

  tags = {
    Project = var.project_prefix
  }
}