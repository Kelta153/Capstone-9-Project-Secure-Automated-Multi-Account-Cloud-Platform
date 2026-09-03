data "aws_iam_policy_document" "deny_destructive_actions" {
  statement {
    sid       = "DenyEC2Termination"
    effect    = "Deny"
    actions   = ["ec2:TerminateInstances"]
    resources = ["*"]
  }

  statement {
    sid       = "DenyCloudTrailStop"
    effect    = "Deny"
    actions   = ["cloudtrail:StopLogging"]
    resources = ["*"]
  }
}

resource "aws_organizations_policy" "deny_destructive_actions" {
  name        = "${var.project_prefix}-deny-destructive-actions"
  description = "Denies EC2 termination and CloudTrail stop-logging, regardless of local IAM permissions"
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.deny_destructive_actions.json
}

resource "aws_organizations_policy_attachment" "deny_to_production" {
  policy_id = aws_organizations_policy.deny_destructive_actions.id
  target_id = aws_organizations_organizational_unit.production.id
}