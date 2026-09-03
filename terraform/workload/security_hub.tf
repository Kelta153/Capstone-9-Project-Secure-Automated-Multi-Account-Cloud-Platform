resource "aws_securityhub_account" "this" {
  enable_default_standards = false # we enable FSBP explicitly below, deliberately, for the report's reasoning
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
  timeouts {
    create = "10m"
  }
  depends_on = [aws_securityhub_account.this]
}

# Security Hub natively aggregates GuardDuty findings and AWS Config
# compliance results once both services are enabled in the same
# account/region — no extra wiring needed for that half of "Integrate
# GuardDuty, Config, Inspector". Inspector needs an explicit enabler.
resource "aws_inspector2_enabler" "this" {
  account_ids    = [data.aws_caller_identity.workload.account_id]
  resource_types = ["EC2", "ECR"]
}

# --- Route Security Hub High/Critical findings to the same SNS topic ---

resource "aws_cloudwatch_event_rule" "securityhub_high_severity" {
  name        = "${var.project_prefix}-securityhub-high-severity"
  description = "Routes High/Critical Security Hub findings to the security alerts SNS topic"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "securityhub_to_sns" {
  rule = aws_cloudwatch_event_rule.securityhub_high_severity.name
  arn  = aws_sns_topic.security_alerts.arn
}

# EventBridge -> SNS (unlike EventBridge -> Step Functions) uses SNS's own
# resource policy rather than an assumed IAM role, so the topic needs an
# explicit statement permitting the events service to publish, scoped to
# this specific rule via SourceArn.
data "aws_iam_policy_document" "security_alerts_topic_policy" {
  statement {
    sid    = "AllowEventBridgePublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.security_alerts.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.securityhub_high_severity.arn]
    }
  }
}

resource "aws_sns_topic_policy" "security_alerts" {
  arn    = aws_sns_topic.security_alerts.arn
  policy = data.aws_iam_policy_document.security_alerts_topic_policy.json
}