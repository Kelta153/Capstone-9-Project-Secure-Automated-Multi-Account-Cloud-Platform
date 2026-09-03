variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  description = "This stack always runs against the workload account"
  type        = string
  default     = "workload"
}

variable "project_prefix" {
  type    = string
  default = "capstone-9"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the CI/CD role, as org/repo"
  type        = string
  default     = "Kelta153/Capstone-9-Project-Secure-Automated-Multi-Account-Cloud-Platform"
}

variable "github_branch" {
  description = "Only this branch may assume the CI/CD role via OIDC"
  type        = string
  default     = "main"
}

variable "security_alert_email" {
  description = "Email address to receive security alerts via SNS"
  type        = string
}