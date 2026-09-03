data "aws_iam_policy_document" "permission_boundary" {
  # A permission boundary must positively allow what's permitted (it's a
  # ceiling, not a supplement) — so the pattern is: allow everything by
  # default, then explicitly deny the specific destructive actions we
  # never want possible, no matter what identity policy is attached.
  statement {
    sid       = "AllowAllByDefault"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }

  statement {
    sid    = "DenyDestructiveS3Actions"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:PutBucketAcl",
      "s3:PutBucketPolicy",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "permission_boundary" {
  name        = "${var.project_prefix}-s3-destructive-boundary"
  description = "Permission boundary: caps any attached identity policy, blocking destructive S3 actions"
  policy      = data.aws_iam_policy_document.permission_boundary.json
}