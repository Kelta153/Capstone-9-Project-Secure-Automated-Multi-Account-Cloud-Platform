resource "aws_sns_topic" "security_alerts" {
  name = "${var.project_prefix}-security-alerts"

  tags = {
    Project = var.project_prefix
  }
}

resource "aws_sns_topic_subscription" "security_team_email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}