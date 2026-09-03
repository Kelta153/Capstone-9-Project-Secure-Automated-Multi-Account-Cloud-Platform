resource "aws_cloudwatch_event_rule" "guardduty_high_severity" {
  name        = "${var.project_prefix}-guardduty-high-severity"
  description = "Routes High-severity GuardDuty findings to the incident response state machine"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })
}

data "aws_iam_policy_document" "eventbridge_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eventbridge_to_sfn" {
  name               = "${var.project_prefix}-eventbridge-to-sfn"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume.json

  tags = {
    Project = var.project_prefix
  }
}

data "aws_iam_policy_document" "eventbridge_to_sfn_permissions" {
  statement {
    sid       = "StartStateMachine"
    effect    = "Allow"
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.incident_response.arn]
  }
}

resource "aws_iam_role_policy" "eventbridge_to_sfn_permissions" {
  name   = "${var.project_prefix}-eventbridge-to-sfn-permissions"
  role   = aws_iam_role.eventbridge_to_sfn.id
  policy = data.aws_iam_policy_document.eventbridge_to_sfn_permissions.json
}

resource "aws_cloudwatch_event_target" "sfn" {
  rule     = aws_cloudwatch_event_rule.guardduty_high_severity.name
  arn      = aws_sfn_state_machine.incident_response.arn
  role_arn = aws_iam_role.eventbridge_to_sfn.arn
}