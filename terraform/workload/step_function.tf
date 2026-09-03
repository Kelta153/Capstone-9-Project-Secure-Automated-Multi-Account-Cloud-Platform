data "aws_iam_policy_document" "step_functions_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "step_functions" {
  name               = "${var.project_prefix}-incident-response-sfn"
  assume_role_policy = data.aws_iam_policy_document.step_functions_assume.json

  tags = {
    Project = var.project_prefix
  }
}

data "aws_iam_policy_document" "step_functions_permissions" {
  statement {
    sid       = "InvokeEvaluatorLambda"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.evaluator.arn]
  }

  statement {
    sid       = "PublishAlerts"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.security_alerts.arn]
  }
}

resource "aws_iam_role_policy" "step_functions_permissions" {
  name   = "${var.project_prefix}-sfn-permissions"
  role   = aws_iam_role.step_functions.id
  policy = data.aws_iam_policy_document.step_functions_permissions.json
}

resource "aws_sfn_state_machine" "incident_response" {
  name     = "${var.project_prefix}-incident-response"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "GuardDuty finding response: validate -> log -> isolate -> notify"
    StartAt = "ValidateFinding"
    States = {
      ValidateFinding = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.evaluator.arn
          Payload = {
            "action"    = "validate"
            "finding.$" = "$.detail"
          }
        }
        ResultSelector = {
          "valid.$"    = "$.Payload.valid"
          "severity.$" = "$.Payload.severity"
          "finding.$"  = "$.Payload.finding"
        }
        ResultPath = "$.validation"
        Next       = "IsHighSeverity"
      }

      IsHighSeverity = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.validation.valid"
            BooleanEquals = true
            Next          = "LogFinding"
          }
        ]
        Default = "IgnoreLowSeverity"
      }

      IgnoreLowSeverity = {
        Type = "Pass"
        End  = true
      }

      LogFinding = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.evaluator.arn
          Payload = {
            "action"    = "log"
            "finding.$" = "$.validation.finding"
          }
        }
        ResultSelector = {
          "logged.$" = "$.Payload.logged"
          "s3_key.$" = "$.Payload.s3_key"
        }
        ResultPath = "$.logResult"
        Next       = "IsolateInstance"
      }

      IsolateInstance = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.evaluator.arn
          Payload = {
            "action"    = "isolate"
            "finding.$" = "$.validation.finding"
          }
        }
        ResultSelector = {
          "isolated.$"    = "$.Payload.isolated"
          "instance_id.$" = "$.Payload.instance_id"
        }
        ResultPath = "$.isolateResult"
        Next       = "NotifySecurityTeam"
      }

      NotifySecurityTeam = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn    = aws_sns_topic.security_alerts.arn
          Subject     = "Security Alert - GuardDuty High Severity Finding"
          "Message.$" = "States.Format('GuardDuty finding type: {} | severity: {} | instance isolated: {}', $.validation.finding.type, $.validation.severity, $.isolateResult.isolated)"
        }
        End = true
      }
    }
  })

  tags = {
    Project = var.project_prefix
  }
}