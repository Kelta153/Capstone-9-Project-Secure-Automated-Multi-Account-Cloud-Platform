resource "aws_guardduty_detector" "this" {
  enable = true

  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = {
    Project = var.project_prefix
  }
}