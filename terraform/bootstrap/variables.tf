variable "aws_region" {
  description = "AWS region for the state bucket and lock table"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI SSO profile to use — this stack always runs against the management account"
  type        = string
  default     = "mgmt"
}

variable "project_prefix" {
  description = "Naming prefix applied to all resources in this capstone"
  type        = string
  default     = "capstone-9"
}